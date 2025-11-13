// Step-by-step home screen: 1) Choose pickup → 2) Choose destination → 3) Calculate fare in DH → 4) Confirm & pay

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart' as geo;

import '../../core/constants/app_colors.dart';
import '../menu/main_menu.dart';

class PremiumHomeScreen extends StatefulWidget {
  const PremiumHomeScreen({super.key});

  @override
  State<PremiumHomeScreen> createState() => _PremiumHomeScreenState();
}

enum RideStep {
  pickupSelection,
  destinationSelection,
  fareCalculation,
  paymentConfirmation,
}

class _PremiumHomeScreenState extends State<PremiumHomeScreen> {
  // Map controller
  final Completer<GoogleMapController> _mapController = Completer();

  // Location & selections
  LatLng? _currentLatLng;
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  String _pickupAddress = 'Detecting location...';
  String _destinationAddress = '';

  // Current step in the flow
  RideStep _currentStep = RideStep.pickupSelection;

  // Fare calculation
  double _estimatedFare = 0.0;
  double _estimatedDistance = 0.0;

  // Payment info
  String _paymentMethod = 'cash';
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentInfo();
    _resolveCurrentLocation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPaymentInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _paymentMethod = prefs.getString('payment_method') ?? 'cash';
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

      // Get address for pickup
      try {
        final placemarks = await geo.placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          _pickupAddress = '${pm.street}, ${pm.locality}' == ', '
              ? 'Current Location'
              : '${pm.street}, ${pm.locality}';
        }
      } catch (e) {
        _pickupAddress = 'Current Location';
      }

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

  // Calculate fare in DH based on distance
  double _calculateFareInDH() {
    if (_pickupLatLng == null || _destinationLatLng == null) {
      return 0.0;
    }
    _estimatedDistance = _distanceKm(_pickupLatLng!, _destinationLatLng!);
    // DH: 15 DH base + 5 DH per km
    const baseFareDH = 15.0;
    const perKmDH = 5.0;
    return baseFareDH + (_estimatedDistance * perKmDH);
  }

  double _distanceKm(LatLng a, LatLng b) {
    const R = 6371;
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

  // Step 1: Confirm pickup location (from map center)
  void _confirmPickup() async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    final center = await controller.getLatLng(
      ScreenCoordinate(
        x: (MediaQuery.of(context).size.width / 2).round(),
        y: (MediaQuery.of(context).size.height * 0.35).round(),
      ),
    );

    setState(() {
      _pickupLatLng = center;
    });

    // Get address
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        center.latitude,
        center.longitude,
      );
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        setState(() {
          _pickupAddress = '${pm.street}, ${pm.locality}' == ', '
              ? 'Pickup Location'
              : '${pm.street}, ${pm.locality}';
          _currentStep = RideStep.destinationSelection;
        });
      }
    } catch (e) {
      setState(() {
        _pickupAddress = 'Pickup Location';
        _currentStep = RideStep.destinationSelection;
      });
    }
  }

  // Step 2: Select destination
  void _selectDestination() async {
    final result = await showModalBottomSheet<_PlaceSelection>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const DestinationEntryModal(),
    );

    if (result != null && result.address.isNotEmpty) {
      // Geocode the destination
      try {
        final locations = await geo.locationFromAddress(result.address);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          setState(() {
            _destinationLatLng = LatLng(loc.latitude, loc.longitude);
            _destinationAddress = result.address;
            _estimatedFare = _calculateFareInDH();
            _currentStep = RideStep.fareCalculation;
          });

          // Animate camera to show both points
          if (_mapController.isCompleted) {
            final controller = await _mapController.future;
            final bounds = LatLngBounds(
              southwest: LatLng(
                math.min(_pickupLatLng!.latitude, _destinationLatLng!.latitude),
                math.min(
                  _pickupLatLng!.longitude,
                  _destinationLatLng!.longitude,
                ),
              ),
              northeast: LatLng(
                math.max(_pickupLatLng!.latitude, _destinationLatLng!.latitude),
                math.max(
                  _pickupLatLng!.longitude,
                  _destinationLatLng!.longitude,
                ),
              ),
            );
            controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find: ${result.address}')),
        );
      }
    }
  }

  // Step 4: Confirm and complete ride request
  void _confirmRideAndPay() async {
    setState(() => _isConfirming = true);

    // Save payment method
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payment_method', _paymentMethod);

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _isConfirming = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ride Booked! ${_estimatedDistance.toStringAsFixed(1)} km • DH ${_estimatedFare.toStringAsFixed(0)} • Payment: ${_paymentMethod == 'cash' ? 'Cash' : 'Card'}',
        ),
      ),
    );

    // Reset to step 1
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _currentStep = RideStep.pickupSelection;
        _pickupLatLng = _currentLatLng;
        _destinationLatLng = null;
        _destinationAddress = '';
        _estimatedFare = 0.0;
      });
    }
  }

  void _togglePaymentMethod(String method) {
    setState(() => _paymentMethod = method);
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
                Scaffold.of(context).openDrawer();
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              child: Text(
                _currentStep == RideStep.pickupSelection
                    ? '📍 Select Pickup'
                    : _currentStep == RideStep.destinationSelection
                    ? '📍 Select Destination'
                    : _currentStep == RideStep.fareCalculation
                    ? '💰 Confirm Fare'
                    : '💳 Payment',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Positioned(
      top: 120,
      left: 16,
      right: 16,
      child: Row(
        children: [
          _stepDot(1, _currentStep.index >= 0),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep.index >= 1
                  ? AppColors.primaryPink
                  : Colors.grey.shade300,
            ),
          ),
          _stepDot(2, _currentStep.index >= 1),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep.index >= 2
                  ? AppColors.primaryPink
                  : Colors.grey.shade300,
            ),
          ),
          _stepDot(3, _currentStep.index >= 2),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep.index >= 3
                  ? AppColors.primaryPink
                  : Colors.grey.shade300,
            ),
          ),
          _stepDot(4, _currentStep.index >= 3),
        ],
      ),
    );
  }

  Widget _stepDot(int number, bool active) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.primaryPink : Colors.grey.shade300,
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: _buildContentForStep(),
    );
  }

  Widget _buildContentForStep() {
    switch (_currentStep) {
      case RideStep.pickupSelection:
        return _buildPickupSelection();
      case RideStep.destinationSelection:
        return _buildDestinationSelection();
      case RideStep.fareCalculation:
        return _buildFareCalculation();
      case RideStep.paymentConfirmation:
        return _buildPaymentConfirmation();
    }
  }

  Widget _buildPickupSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Adjust pin on map to set pickup location',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                _pickupAddress,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryPink,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _confirmPickup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm Pickup Location',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'From: $_pickupAddress',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _selectDestination,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Select Destination',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFareCalculation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Fare Estimate',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'DH ${_estimatedFare.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.primaryPink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_estimatedDistance.toStringAsFixed(1)} km',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'To: $_destinationAddress',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _currentStep = RideStep.destinationSelection;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Change'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentStep = RideStep.paymentConfirmation;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPink,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentConfirmation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Payment Method',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Cash option
              _paymentMethodTile(
                'cash',
                '💵 Cash',
                'Pay with cash upon arrival',
              ),
              const SizedBox(height: 12),
              // Card option
              _paymentMethodTile(
                'card',
                '💳 Card',
                'Pay with credit/debit card',
              ),
              const SizedBox(height: 16),
              // Confirm button
              ElevatedButton(
                onPressed: _isConfirming ? null : _confirmRideAndPay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isConfirming
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm & Request Ride',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentMethodTile(String method, String title, String subtitle) {
    final isSelected = _paymentMethod == method;
    return GestureDetector(
      onTap: () => _togglePaymentMethod(method),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPink.withOpacity(0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryPink : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primaryPink
                    : Colors.grey.shade400,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
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

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraPosition(
      target: _currentLatLng ?? const LatLng(0, 0),
      zoom: 14,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const MainMenu(),
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
                      markers: _getMarkers(),
                      onMapCreated: (GoogleMapController controller) {
                        if (!_mapController.isCompleted) {
                          _mapController.complete(controller);
                        }
                      },
                    ),
            ),

            // Top bar with step indicator
            _buildTopBar(),

            // Step indicator
            _buildStepIndicator(),

            // Center pin (for pickup selection)
            if (_currentStep == RideStep.pickupSelection)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.28,
                left: 0,
                right: 0,
                child: const IgnorePointer(
                  ignoring: true,
                  child: Center(
                    child: Icon(
                      Icons.location_on,
                      size: 56,
                      color: Color(0xFFFF1493),
                    ),
                  ),
                ),
              ),

            // Step-specific content at bottom
            _buildStepContent(),
          ],
        ),
      ),
    );
  }

  Set<Marker> _getMarkers() {
    final markers = <Marker>{};

    // Destination marker
    if (_destinationLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }

    // Pickup marker
    if (_pickupLatLng != null && _currentStep != RideStep.pickupSelection) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      );
    }

    return markers;
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
  const DestinationEntryModal({super.key});

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
