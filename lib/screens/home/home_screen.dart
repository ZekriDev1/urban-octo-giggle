import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/profile_screen.dart';
import '../payments/payment_screen.dart';

/// Uber-style Home Screen (modern, minimal, functional)
///
/// Notes:
/// - Uses the app's `AppColors.primaryPink` and system font (inherited from app theme).
/// - This file uses `google_maps_flutter` for native Google Maps (Android/iOS).
/// - You must configure the Google Maps API key in platform files:
///   * Android: android/app/src/main/AndroidManifest.xml -> <application>
///       <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_API_KEY"/>
///   * iOS: ios/Runner/AppDelegate.swift -> GMSServices.provideAPIKey("YOUR_API_KEY")
///
/// Prototyping key provided (DO NOT ship with this key):
/// AIzaSyAOVYRIgupAurZup5y1PRh8Ismb1A3lLao
/// Restrict it on Google Cloud to your app package/sha or HTTP referrers before shipping.

class UberHomeScreen extends StatefulWidget {
  const UberHomeScreen({super.key});

  @override
  State<UberHomeScreen> createState() => _UberHomeScreenState();
}

class _UberHomeScreenState extends State<UberHomeScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentLatLng;
  String _currentAddress = 'Detecting location...';
  String _paymentMethod = 'cash';
  String _cardLast4 = '';
  bool _isRequesting = false;
  Timer? _driverTimer;

  // Ride options
  final List<Map<String, String>> _rideTypes = [
    {'key': 'economy', 'name': 'Economy', 'eta': '3 min', 'price': '\$6'},
    {'key': 'standard', 'name': 'Standard', 'eta': '4 min', 'price': '\$8'},
    {'key': 'premium', 'name': 'Premium', 'eta': '6 min', 'price': '\$15'},
    {'key': 'xl', 'name': 'XL', 'eta': '5 min', 'price': '\$12'},
  ];
  String _selectedRide = 'economy';

  // Map markers for nearby drivers (demo)
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _resolveCurrentLocation();
    _loadPaymentInfo();
    // Demo nearby drivers (in a real app these would be fetched from your backend)
  }

  @override
  void dispose() {
    _driverTimer?.cancel();
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
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
        _currentAddress =
            'Pickup: ${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
      });

      // Add a pulsing-like circle (static radius here; you can animate later)
      _markers.add(
        Marker(
          markerId: const MarkerId('you'),
          position: _currentLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      );

      // Nearby drivers sample
      final nearby = [
        LatLng(pos.latitude + 0.002, pos.longitude + 0.003),
        LatLng(pos.latitude - 0.0025, pos.longitude - 0.002),
      ];
      var idx = 1;
      for (final d in nearby) {
        _markers.add(
          Marker(
            markerId: MarkerId('driver_$idx'),
            position: d,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: 'Driver $idx',
              snippet: 'ETA: ${2 + idx} min',
            ),
            onTap: () {
              _showDriverBottomSheet(idx);
            },
          ),
        );
        idx++;
      }

      // Move camera to user
      if (_currentLatLng != null) {
        final controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLatLng!, 14.0),
        );
      }
    } catch (e) {
      setState(() {
        _currentAddress = 'Location unavailable';
      });
    }
  }

  void _showDriverBottomSheet(int id) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Driver $id',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'ETA: 3 min • Toyota Prius • Plate: ABC-123',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Select Driver'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onTapPickup() async {
    // In the real app this should open the full-screen search with recents + saved addresses
    // For prototyping we show a simple page push.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DestinationSearchPlaceholder()),
    );
  }

  void _onRequestRide() {
    // Simple request flow: check payment, then simulate assigning a driver and moving it towards user.
    if (_currentLatLng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Current location unknown')));
      return;
    }

    if (_paymentMethod == 'card' && _cardLast4.isEmpty) {
      // Ask user to add card
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No card found. Please add a card.')),
      );
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PaymentScreen()))
          .then((_) => _loadPaymentInfo());
      return;
    }

    // Simulate request
    setState(() => _isRequesting = true);
    final fare = _rideTypes.firstWhere(
      (r) => r['key'] == _selectedRide,
    )['price'];
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Ride requested • $fare')));

    // Find a driver marker id (demo: pick first driver)
    final driverMarker = _markers.firstWhere(
      (m) => m.markerId.value.startsWith('driver_'),
      orElse: () => Marker(
        markerId: const MarkerId('driver_none'),
        position: LatLng(
          _currentLatLng!.latitude + 0.003,
          _currentLatLng!.longitude + 0.003,
        ),
      ),
    );
    if (driverMarker.markerId.value == 'driver_none') {
      setState(() => _isRequesting = false);
      return;
    }

    // Show bottom sheet tracking
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return RideProgressSheet(
          onCancel: () {
            _driverTimer?.cancel();
            setState(() => _isRequesting = false);
            Navigator.of(ctx).pop();
          },
        );
      },
    );

    // Start moving the driver marker toward the user
    _driverTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final id = driverMarker.markerId;
      final current = _markers.firstWhere((m) => m.markerId == id).position;
      final target = _currentLatLng!;
      final latStep = (target.latitude - current.latitude) * 0.3;
      final lngStep = (target.longitude - current.longitude) * 0.3;
      final newPos = LatLng(
        current.latitude + latStep,
        current.longitude + lngStep,
      );

      // replace marker
      _markers.removeWhere((m) => m.markerId == id);
      _markers.add(
        Marker(
          markerId: id,
          position: newPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
      setState(() {});

      // If close enough, stop
      final distance =
          ((newPos.latitude - target.latitude).abs() +
          (newPos.longitude - target.longitude).abs());
      if (distance < 0.0002) {
        _driverTimer?.cancel();
        setState(() => _isRequesting = false);
        // Close bottom sheet and show arrived message
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Driver has arrived')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Google Map full-bleed
            Positioned.fill(
              child: _currentLatLng == null
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentLatLng!,
                        zoom: 14.0,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      markers: _markers,
                      onMapCreated: (GoogleMapController controller) {
                        if (!_controller.isCompleted) {
                          _controller.complete(controller);
                        }
                      },
                      mapToolbarEnabled: false,
                      // You can set mapStyle here to match aesthetic (muted colors)
                    ),
            ),

            // Top bar: hamburger | title | avatar with online dot
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  // Hamburger
                  Material(
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.menu, color: AppColors.primaryPink),
                    ),
                  ),
                  const Spacer(),
                  Text('Where to?', style: titleStyle),
                  const Spacer(),
                  // Avatar with online dot
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          color: AppColors.primaryPink,
                          size: 20,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Floating pickup/search card (slightly above center)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.18,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: _onTapPickup,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.blueAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter destination',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentAddress,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.blue,
                          ),
                          onPressed: _onTapPickup,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Quick ride options row floating above bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 120,
              child: SizedBox(
                height: 110,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _rideTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final ride = _rideTypes[index];
                    final selected = ride['key'] == _selectedRide;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRide = ride['key']!),
                      child: Container(
                        width: 160,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryPink.withOpacity(0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                            ),
                          ],
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryPink
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.directions_car,
                                      color: selected
                                          ? AppColors.primaryPink
                                          : Colors.black54,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ride['name']!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? AppColors.primaryPink
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  ride['price']!,
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.primaryPink
                                        : Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              ride['eta']!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Bottom CTA + summary
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pickup • ${_currentAddress.split(',').first} — Payment: Card ••••1234',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPink,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _onRequestRide,
                          child: Text(
                            'Request Ride',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DestinationSearchPlaceholder extends StatelessWidget {
  const DestinationSearchPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search destination')),
      body: Center(
        child: Text(
          'Full-screen search goes here',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Simple bottom sheet shown during ride progress. Calls [onCancel] when user cancels.
class RideProgressSheet extends StatelessWidget {
  final VoidCallback onCancel;
  const RideProgressSheet({required this.onCancel, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Driver on the way',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('3 min', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Toyota Prius • Plate: ABC-123',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Cancel ride'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                  ),
                  child: const Text('Contact driver'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
