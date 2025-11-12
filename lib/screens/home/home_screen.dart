import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import 'destination_search_screen.dart';
import '../auth/login_screen.dart';

/// Home screen with map, location, and ride booking
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Map controller for programmatic control
  final MapController _mapController = MapController();

  // Current user location
  LatLng? _currentLocation;
  String _currentAddress = 'Getting location...';

  // Selected destination
  LatLng? _destinationLocation;
  String? _destinationAddress;

  // Route points for drawing polyline
  List<LatLng> _routePoints = [];

  // Bottom sheet visibility
  bool _isBottomSheetVisible = false;

  // Loading states
  bool _isLoadingLocation = true;
  bool _isRequestingRide = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  /// Get current user location
  Future<void> _getCurrentLocation() async {
    try {
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentAddress = 'Location services disabled';
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentAddress = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentAddress = 'Location permission permanently denied';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address = placemarks.isNotEmpty
          ? '${placemarks[0].street}, ${placemarks[0].locality}'
          : '${position.latitude}, ${position.longitude}';

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentAddress = address;
        _isLoadingLocation = false;
      });

      // Center map on user location
      _mapController.move(_currentLocation!, 13.0);
    } catch (e) {
      setState(() {
        _currentAddress = 'Error getting location: $e';
        _isLoadingLocation = false;
      });
    }
  }

  /// Refresh current location
  Future<void> _refreshLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    await _getCurrentLocation();
  }

  /// Select destination from search
  Future<void> _selectDestination() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const DestinationSearchScreen()),
    );

    if (result != null && _currentLocation != null) {
      setState(() {
        _destinationLocation = LatLng(
          result['latitude'] as double,
          result['longitude'] as double,
        );
        _destinationAddress = result['address'] as String;
        _isBottomSheetVisible = true;
      });

      // Draw route
      _drawRoute();
    }
  }

  /// Draw route between current location and destination
  void _drawRoute() {
    if (_currentLocation != null && _destinationLocation != null) {
      setState(() {
        _routePoints = [_currentLocation!, _destinationLocation!];
      });

      // Fit map to show both points
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100)),
      );
    }
  }

  /// Calculate distance between two points
  double _calculateDistance() {
    if (_currentLocation == null || _destinationLocation == null) {
      return 0.0;
    }
    final distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      _currentLocation!,
      _destinationLocation!,
    );
  }

  /// Request a ride
  Future<void> _requestRide() async {
    if (_currentLocation == null || _destinationLocation == null) {
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to request a ride'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isRequestingRide = true;
    });

    try {
      final distance = _calculateDistance();
      final estimatedDuration = (distance * 2)
          .round(); // Rough estimate: 2 min per km
      final fare = (distance * 2.5).toStringAsFixed(
        2,
      ); // Rough estimate: $2.5 per km

      // Save ride to Supabase (if you have a rides table)
      // await _supabase.from('rides').insert({
      //   'user_id': user.id,
      //   'pickup_latitude': _currentLocation!.latitude,
      //   'pickup_longitude': _currentLocation!.longitude,
      //   'pickup_address': _currentAddress,
      //   'destination_latitude': _destinationLocation!.latitude,
      //   'destination_longitude': _destinationLocation!.longitude,
      //   'destination_address': _destinationAddress,
      //   'distance': distance,
      //   'fare': double.parse(fare),
      //   'estimated_duration': estimatedDuration,
      //   'status': 'pending',
      // });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride requested! Estimated fare: \$$fare'),
            backgroundColor: AppColors.success,
          ),
        );

        // Clear destination after request
        setState(() {
          _destinationLocation = null;
          _destinationAddress = null;
          _routePoints.clear();
          _isBottomSheetVisible = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting ride: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingRide = false;
        });
      }
    }
  }

  /// Clear destination and route
  void _clearDestination() {
    setState(() {
      _destinationLocation = null;
      _destinationAddress = null;
      _routePoints.clear();
      _isBottomSheetVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map view
          if (_currentLocation != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation!,
                initialZoom: AppConstants.defaultZoom ?? 13.0,
                minZoom: AppConstants.minZoom ?? 1.0,
                maxZoom: AppConstants.minZoom ?? 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // OpenStreetMap tile layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.zekri.deplacetoi',
                ),
                // Route polyline
                if (_routePoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4,
                        color: AppColors.primaryPink,
                      ),
                    ],
                  ),
                // Markers layer
                MarkerLayer(
                  markers: [
                    // Current location marker
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    // Destination marker
                    if (_destinationLocation != null)
                      Marker(
                        point: _destinationLocation!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.place,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoadingLocation)
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryPink,
                      ),
                    )
                  else
                    Column(
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: AppColors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentAddress,
                          style: TextStyle(color: AppColors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _refreshLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPink,
                            foregroundColor: AppColors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          // Top search bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _selectDestination,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: AppColors.primaryPink),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _destinationAddress ?? 'Where to?',
                              style: TextStyle(
                                fontSize: 16,
                                color: _destinationAddress != null
                                    ? AppColors.black
                                    : AppColors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Floating action buttons
          Positioned(
            bottom: _isBottomSheetVisible ? 280 : 120,
            right: 16,
            child: Column(
              children: [
                // Recenter on location button
                FloatingActionButton(
                  heroTag: 'location',
                  onPressed: _refreshLocation,
                  backgroundColor: AppColors.white,
                  child: Icon(Icons.my_location, color: AppColors.primaryPink),
                ),
                const SizedBox(height: 12),
                // Menu button
                FloatingActionButton(
                  heroTag: 'menu',
                  onPressed: () {
                    // Show menu or profile
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: Icon(
                                Icons.person,
                                color: AppColors.primaryPink,
                              ),
                              title: const Text('Profile'),
                              onTap: () {
                                Navigator.pop(context);
                                // Navigate to profile
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.history,
                                color: AppColors.primaryPink,
                              ),
                              title: const Text('Ride History'),
                              onTap: () {
                                Navigator.pop(context);
                                // Navigate to ride history
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.logout,
                                color: AppColors.error,
                              ),
                              title: const Text('Logout'),
                              onTap: () async {
                                Navigator.pop(context);
                                await _supabase.auth.signOut();
                                if (mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  backgroundColor: AppColors.white,
                  child: Icon(Icons.menu, color: AppColors.primaryPink),
                ),
              ],
            ),
          ),
          // Bottom sheet for ride details
          if (_isBottomSheetVisible && _destinationLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pickup location
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryPink,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _currentAddress,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Destination
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _destinationAddress ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _clearDestination,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Ride details
                          Row(
                            children: [
                              _buildDetailItem(
                                Icons.straighten,
                                '${_calculateDistance().toStringAsFixed(1)} km',
                              ),
                              const SizedBox(width: 20),
                              _buildDetailItem(
                                Icons.access_time,
                                '${(_calculateDistance() * 2).round()} min',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Fare estimate
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPink.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Estimated Fare',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '\$${(_calculateDistance() * 2.5).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryPink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Request ride button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isRequestingRide
                                  ? null
                                  : _requestRide,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPink,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isRequestingRide
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Request Ride',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryPink),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: AppColors.darkGrey),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
