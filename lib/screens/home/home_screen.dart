// Complete redesign of the Home Screen: premium modern layout with animations,
// ride options, payment toggle and glassmorphism request button.
//
// Integrates with existing project pieces (AppColors, PaymentScreen).
// Uses google_maps_flutter and geolocator for core map and location logic.
// Note: Make sure required packages are in pubspec.yaml:
//   google_maps_flutter, geolocator, shared_preferences
//
// This file aims to keep the existing behavior while dramatically improving the UI.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../payments/payment_screen.dart';
import '../profile/profile_screen.dart';

class PremiumHomeScreen extends StatefulWidget {
  const PremiumHomeScreen({super.key});

  @override
  State<PremiumHomeScreen> createState() => _PremiumHomeScreenState();
}

class _PremiumHomeScreenState extends State<PremiumHomeScreen>
    with SingleTickerProviderStateMixin {
  // Map controller
  final Completer<GoogleMapController> _mapController = Completer();

  // Location & selections
  LatLng? _currentLatLng;
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  String _pickupAddress = 'Detecting location...';
  String _destinationAddress = 'Where to?';
  bool _usingAutoPickup = true;

  // UI state
  bool _showRideOptions = false;
  bool _isRequesting = false;
  String _paymentMethod = 'cash';
  String _cardLast4 = '';
  String _selectedRideKey = 'normal';

  // Animation controllers
  late final AnimationController _controller;
  late final Animation<double> _pinJumpAnimation;
  late final Animation<double> _optionListAnim;

  // Demo drivers
  final Set<Marker> _markers = {};

  // Ride definitions
  final List<RideType> _rideTypes = [
    RideType(
      key: 'normal',
      name: 'Normal',
      capacity: 'Up to 4',
      baseMultiplier: 1.0,
      etaMinutes: 3,
    ),
    RideType(
      key: 'comfort',
      name: 'Comfort',
      capacity: 'Spacious',
      baseMultiplier: 1.4,
      etaMinutes: 4,
    ),
    RideType(
      key: 'moto',
      name: 'Moto',
      capacity: '1 passenger',
      baseMultiplier: 0.55,
      etaMinutes: 2,
    ),
    RideType(
      key: 'xl',
      name: 'XL Car',
      capacity: 'Large',
      baseMultiplier: 1.9,
      etaMinutes: 5,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Smooth UI animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pinJumpAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _optionListAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
    );

    _loadPaymentInfo();
    _resolveCurrentLocation().then((_) {
      // small delay and show options
      Future.delayed(const Duration(milliseconds: 400), () {
        setState(() => _showRideOptions = true);
        _controller.forward();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _paymentMethod = prefs.getString('payment_method') ?? 'cash';
    _cardLast4 = prefs.getString('card_last4') ?? '';
    setState(() {});
  }

  Future<void> _resolveCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _currentLatLng = LatLng(pos.latitude, pos.longitude);
      _pickupLatLng = _currentLatLng;

      _pickupAddress =
          'Pickup: ${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';

      _addDemoDrivers(pos.latitude, pos.longitude);

      if (_mapController.isCompleted) {
        final controller = await _mapController.future;
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLatLng!, 14),
        );
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _pickupAddress = 'Location unavailable';
      });
    }
  }

  void _addDemoDrivers(double lat, double lng) {
    _markers.clear();
    final nearby = [
      LatLng(lat + 0.003, lng - 0.002),
      LatLng(lat - 0.002, lng + 0.003),
      LatLng(lat + 0.0022, lng + 0.0027),
    ];

    var idx = 1;
    for (final loc in nearby) {
      _markers.add(
        Marker(
          markerId: MarkerId('driver_$idx'),
          position: loc,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: 'Driver $idx',
            snippet: 'ETA: ${2 + idx} min',
          ),
          onTap: () {
            _showDriverDetails(idx);
          },
        ),
      );
      idx++;
    }
  }

  void _showDriverDetails(int idx) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Driver $idx',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Toyota • ETA: ${2 + idx} min • Plate: XYZ-${100 + idx}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPink,
                      ),
                      child: const Text('Select Driver'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Called when user taps the confirm pickup floating button
  Future<void> _confirmPickupAtCenter() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    final center = await controller.getLatLng(
      ScreenCoordinate(
        x: (MediaQuery.of(context).size.width / 2).round(),
        y: (MediaQuery.of(context).size.height * 0.35).round(),
      ),
    );

    setState(() {
      _usingAutoPickup = false;
      _pickupLatLng = center;
      _pickupAddress =
          'Pickup: ${center.latitude.toStringAsFixed(3)}, ${center.longitude.toStringAsFixed(3)}';
    });
  }

  // Simple distance calc (Haversine) to compute estimated fare
  double _distanceKm(LatLng a, LatLng b) {
    const R = 6371; // km
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final hav =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
    return R * c;
  }

  double _deg2rad(double deg) => deg * math.pi / 180.0;

  String _calculateFare(RideType ride) {
    if (_pickupLatLng == null || _destinationLatLng == null) {
      return '--';
    }
    final distKm = _distanceKm(_pickupLatLng!, _destinationLatLng!);
    // Base fare model: base + distance * per_km * multiplier
    const base = 2.0;
    const perKm = 1.2;
    final raw = (base + distKm * perKm) * ride.baseMultiplier;
    return '\$${raw.toStringAsFixed(2)}';
  }

  void _onTapDestination() async {
    // For the prototype, open a modal that returns a dummy coordinate
    final result = await showModalBottomSheet<_PlaceSelection>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DestinationEntryModal(),
    );

    if (result != null) {
      setState(() {
        _destinationLatLng = result.latLng;
        _destinationAddress = result.address;
        _showRideOptions = true;
        _controller.forward();
      });

      // Move camera to show both pickup and destination
      if (_pickupLatLng != null && _mapController.isCompleted) {
        final controller = await _mapController.future;
        final bounds = LatLngBounds(
          southwest: LatLng(
            math.min(_pickupLatLng!.latitude, _destinationLatLng!.latitude),
            math.min(_pickupLatLng!.longitude, _destinationLatLng!.longitude),
          ),
          northeast: LatLng(
            math.max(_pickupLatLng!.latitude, _destinationLatLng!.latitude),
            math.max(_pickupLatLng!.longitude, _destinationLatLng!.longitude),
          ),
        );
        final camUpdate = CameraUpdate.newLatLngBounds(bounds, 80);
        controller.animateCamera(camUpdate);
      }
    }
  }

  void _togglePaymentMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _paymentMethod = method;
    });
    await prefs.setString('payment_method', method);
  }

  void _requestRide() {
    if (_pickupLatLng == null || _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup and destination')),
      );
      return;
    }

    if (_paymentMethod == 'card' && _cardLast4.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No card on file')));
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PaymentScreen()))
          .then((_) => _loadPaymentInfo());
      return;
    }

    setState(() {
      _isRequesting = true;
    });

    // Simulate a request delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isRequesting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ride requested • ${_rideTypes.firstWhere((r) => r.key == _selectedRideKey).name} • ${_paymentMethod == 'cash' ? 'Cash' : 'Card'}',
          ),
        ),
      );
    });
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 18,
      left: 16,
      right: 16,
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.95),
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                // open drawer or menu
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.menu, color: AppColors.primaryPink),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _onTapDestination,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _destinationAddress,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pickupAddress,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                        icon: Icon(Icons.person, color: AppColors.primaryPink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerPin(BuildContext context) {
    return Center(
      child: IgnorePointer(
        ignoring: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated "3D" pin
            Transform.translate(
              offset: Offset(0, -16 * _pinJumpAnimation.value),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6AA6), AppColors.primaryPink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPink.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // subtle shine with rotation
                    Positioned(
                      left: 8,
                      top: 10,
                      child: Container(
                        width: 18,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        transform: Matrix4.rotationZ(-0.35),
                      ),
                    ),
                    const Icon(Icons.place, color: Colors.white, size: 28),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // small shadow
            Container(
              width: 34,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fake "3D" car widget using gradients, transforms, and shadows.
  Widget _car3DIcon({required Color color, double size = 44}) {
    return SizedBox(
      width: size,
      height: size * 0.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // reflection layer
          Positioned(
            top: 0,
            child: Transform(
              transform: Matrix4.rotationX(0.3)..scale(1.05),
              alignment: Alignment.center,
              child: Container(
                width: size * 0.9,
                height: size * 0.45,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.25),
                      color.withOpacity(0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // main body
          Positioned(
            bottom: 0,
            child: Container(
              width: size,
              height: size * 0.45,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.95), color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideOptions() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 160,
      child: SizedBox(
        height: 140,
        child: FadeTransition(
          opacity: _optionListAnim,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: _rideTypes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final ride = _rideTypes[index];
              final selected = ride.key == _selectedRideKey;
              final fare = _calculateFare(ride);

              return GestureDetector(
                onTap: () => setState(() {
                  _selectedRideKey = ride.key;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  width: 260,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(selected ? 0.98 : 0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryPink
                          : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(selected ? 0.12 : 0.06),
                        blurRadius: selected ? 18 : 10,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 3D car
                      _car3DIcon(color: AppColors.primaryPink, size: 64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ride.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ride.capacity,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  ride.etaMinutes != null
                                      ? '${ride.etaMinutes} min'
                                      : '—',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                Text(
                                  fare,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryPink,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.payment, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                // Smooth toggle style - custom segmented control
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                          left: _paymentMethod == 'cash'
                              ? 0
                              : (MediaQuery.of(context).size.width * 0.45),
                          top: 4,
                          bottom: 4,
                          right: _paymentMethod == 'cash'
                              ? (MediaQuery.of(context).size.width * 0.45)
                              : 0,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPink.withOpacity(
                                    0.18,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _togglePaymentMethod('cash'),
                                child: Center(
                                  child: Text(
                                    'Cash 💵',
                                    style: TextStyle(
                                      color: _paymentMethod == 'cash'
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => _togglePaymentMethod('card'),
                                child: Center(
                                  child: Text(
                                    'Card 💳',
                                    style: TextStyle(
                                      color: _paymentMethod == 'card'
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _paymentMethod == 'card' ? '•••• $_cardLast4' : 'Cash',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA() {
    final ride = _rideTypes.firstWhere((r) => r.key == _selectedRideKey);
    final estimatedFare = _calculateFare(ride);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // summary card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${ride.name} • ${ride.capacity} • ${ride.etaMinutes} min • $estimatedFare',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                // Glassmorphism request button
                GestureDetector(
                  onTap: _isRequesting ? null : _requestRide,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: 48,
                    width: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: _isRequesting
                            ? [
                                AppColors.primaryPink.withOpacity(0.6),
                                AppColors.primaryPinkLight.withOpacity(0.6),
                              ]
                            : [
                                AppColors.primaryPink,
                                AppColors.primaryPinkLight,
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPink.withOpacity(
                            _isRequesting ? 0.25 : 0.35,
                          ),
                          blurRadius: _isRequesting ? 16 : 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Center(
                          child: _isRequesting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Requesting...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Request Ride',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildPaymentToggle(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraPosition(
      target: _currentLatLng ?? const LatLng(0, 0),
      zoom: 14,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Map
            Positioned.fill(
              child: _currentLatLng == null
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      initialCameraPosition: initialCamera,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      markers: _markers.union(
                        _pickupLatLng != null && !_usingAutoPickup
                            ? {
                                Marker(
                                  markerId: const MarkerId('pickup_marker'),
                                  position: _pickupLatLng!,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueRose,
                                  ),
                                  infoWindow: const InfoWindow(title: 'Pickup'),
                                  draggable: true,
                                  onDragEnd: (pos) {
                                    setState(() {
                                      _pickupLatLng = pos;
                                      _pickupAddress =
                                          'Pickup: ${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
                                    });
                                  },
                                ),
                              }
                            : {},
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        if (!_mapController.isCompleted) {
                          _mapController.complete(controller);
                        }
                      },
                    ),
            ),

            // Top UI
            _buildTopBar(),

            // Center pin (indicates map center for manual pickup)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.28,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 120,
                child: AnimatedBuilder(
                  animation: _pinJumpAnimation,
                  builder: (_, __) {
                    return Column(
                      children: [
                        Transform.translate(
                          offset: Offset(0, -20 * _pinJumpAnimation.value),
                        ),
                        _centerPin(context),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Confirm pickup floating action
            Positioned(
              right: 18,
              top: MediaQuery.of(context).size.height * 0.28 + 4,
              child: Column(
                children: [
                  FloatingActionButton(
                    backgroundColor: AppColors.primaryPink,
                    onPressed: () async {
                      await _confirmPickupAtCenter();
                      _controller.reset();
                      _controller.forward();
                    },
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    backgroundColor: Colors.white,
                    mini: true,
                    onPressed: () async {
                      // recenter to current location
                      if (_currentLatLng != null &&
                          _mapController.isCompleted) {
                        final controller = await _mapController.future;
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_currentLatLng!, 15),
                        );
                        setState(() {
                          _usingAutoPickup = true;
                          _pickupLatLng = _currentLatLng;
                          _pickupAddress =
                              'Pickup: ${_currentLatLng!.latitude.toStringAsFixed(3)}, ${_currentLatLng!.longitude.toStringAsFixed(3)}';
                        });
                      }
                    },
                    child: Icon(
                      Icons.my_location,
                      color: AppColors.primaryPink,
                    ),
                  ),
                ],
              ),
            ),

            // Ride options animated row
            if (_showRideOptions) _buildRideOptions(),

            // Bottom CTA / payment
            _buildBottomCTA(),
          ],
        ),
      ),
    );
  }
}

// Helper models & widgets

class RideType {
  final String key;
  final String name;
  final String capacity;
  final double baseMultiplier;
  final int? etaMinutes;

  const RideType({
    required this.key,
    required this.name,
    required this.capacity,
    required this.baseMultiplier,
    this.etaMinutes,
  });
}

class _PlaceSelection {
  final LatLng? latLng;
  final String address;
  const _PlaceSelection(this.latLng, this.address);
}

// A simple destination entry modal that returns only the user-entered address.
// This removes all demo suggestions and hardcoded LatLng values so production code
// can perform real geocoding (server-side or via a proper geocoding plugin/service).
class DestinationEntryModal extends StatefulWidget {
  @override
  State<DestinationEntryModal> createState() => _DestinationEntryModalState();
}

class _DestinationEntryModalState extends State<DestinationEntryModal> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Enter destination address or place name',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      final address = _controller.text.trim();
                      if (address.isEmpty) return;
                      // Return only the address. latLng is left null so your app can
                      // perform proper geocoding in production (or call a service).
                      Navigator.of(context).pop(_PlaceSelection(null, address));
                    },
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (v) {
                  final addr = v.trim();
                  if (addr.isEmpty) return;
                  Navigator.of(context).pop(_PlaceSelection(null, addr));
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    const Text(
                      'Tip',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter an address or place name. Your app should perform geocoding to obtain coordinates in production.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    // Kept intentionally empty of demo/test entries
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
