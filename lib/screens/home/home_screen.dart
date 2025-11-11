import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../models/location_model.dart';
import '../../models/ride_model.dart';
import '../../widgets/ride_bottom_sheet.dart';
import 'destination_search_screen.dart';

/// Home screen with map and ride booking functionality
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LocationModel? _selectedDestination;
  bool _isBottomSheetVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  Future<void> _initializeLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.initialize();
    
    if (locationProvider.currentLocation != null) {
      _updateMapCamera(locationProvider.currentLocation!);
      _addCurrentLocationMarker(locationProvider.currentLocation!);
    }
  }

  void _updateMapCamera(LocationModel location) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        AppConstants.defaultZoom,
      ),
    );
  }

  void _addCurrentLocationMarker(LocationModel location) {
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(location.latitude, location.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Your Location', snippet: location.address),
        ),
      );
    });
  }

  void _addDestinationMarker(LocationModel destination) {
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destination.latitude, destination.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Destination', snippet: destination.address),
        ),
      );
    });
  }

  void _drawRoute(LocationModel pickup, LocationModel destination) {
    // Simple straight line for demo - in production, use a routing service
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            LatLng(pickup.latitude, pickup.longitude),
            LatLng(destination.latitude, destination.longitude),
          ],
          color: AppColors.primaryPink,
          width: 4,
        ),
      );
    });
  }

  Future<void> _selectDestination() async {
    final result = await Navigator.of(context).push<LocationModel>(
      MaterialPageRoute(
        builder: (_) => const DestinationSearchScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedDestination = result;
        _isBottomSheetVisible = true;
      });

      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.setDestination(result);

      if (locationProvider.currentLocation != null) {
        _addDestinationMarker(result);
        _drawRoute(locationProvider.currentLocation!, result);
        _updateMapCamera(result);
      }
    }
  }

  Future<void> _requestRide() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (locationProvider.currentLocation == null || _selectedDestination == null) {
      return;
    }

    if (authProvider.currentUser == null) {
      return;
    }

    try {
      final distance = locationProvider.calculateDistanceToDestination();
      final estimatedDuration = distance != null ? (distance * 2).round() : null;
      final fare = distance != null ? (distance * 2.5).toStringAsFixed(2) : null;

      await SupabaseService.createRide(
        userId: authProvider.currentUser!.id,
        pickupLatitude: locationProvider.currentLocation!.latitude,
        pickupLongitude: locationProvider.currentLocation!.longitude,
        pickupAddress: locationProvider.currentLocation!.address,
        destinationLatitude: _selectedDestination!.latitude,
        destinationLongitude: _selectedDestination!.longitude,
        destinationAddress: _selectedDestination!.address,
        fare: fare != null ? double.parse(fare) : null,
        estimatedDuration: estimatedDuration,
        distance: distance,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride requested successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Clear selection
      setState(() {
        _selectedDestination = null;
        _isBottomSheetVisible = false;
        _markers.removeWhere((m) => m.markerId.value == 'destination');
        _polylines.clear();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _refreshLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.refreshLocation();

    if (locationProvider.currentLocation != null) {
      _updateMapCamera(locationProvider.currentLocation!);
      _markers.removeWhere((m) => m.markerId.value == 'current_location');
      _addCurrentLocationMarker(locationProvider.currentLocation!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<LocationProvider, AuthProvider>(
        builder: (context, locationProvider, authProvider, child) {
          final currentLocation = locationProvider.currentLocation;
          final distance = locationProvider.calculateDistanceToDestination();
          final estimatedDuration = distance != null ? (distance * 2).round() : null;
          final fare = distance != null ? (distance * 2.5) : null;

          return Stack(
            children: [
              // Map
              if (currentLocation != null)
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      currentLocation.latitude,
                      currentLocation.longitude,
                    ),
                    zoom: AppConstants.defaultZoom,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                )
              else
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPink),
                  ),
                ),
              // Top bar with search
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: AppColors.primaryPink),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedDestination?.address ?? 'Where to?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _selectedDestination != null
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
                bottom: 120,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: 'refresh',
                      onPressed: _refreshLocation,
                      backgroundColor: AppColors.white,
                      child: Icon(Icons.my_location, color: AppColors.primaryPink),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: 'menu',
                      onPressed: () {
                        // Menu action
                      },
                      backgroundColor: AppColors.white,
                      child: Icon(Icons.menu, color: AppColors.primaryPink),
                    ),
                  ],
                ),
              ),
              // Bottom sheet
              if (_isBottomSheetVisible && _selectedDestination != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: RideBottomSheet(
                    pickupLocation: currentLocation,
                    destination: _selectedDestination,
                    fare: fare,
                    estimatedDuration: estimatedDuration,
                    distance: distance,
                    onRequestRide: _requestRide,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

