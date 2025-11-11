import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../models/location_model.dart';
import '../../models/ride_model.dart';
import '../../widgets/ride_bottom_sheet.dart';
import '../../widgets/map_markers.dart';
import 'destination_search_screen.dart';

/// Home screen with OpenStreetMap and ride booking functionality
/// Uses flutter_map for free, API-key-free map integration
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Map controller for programmatic map control (zoom, pan, etc.)
  final MapController _mapController = MapController();
  
  // Current map center position
  LatLng? _currentMapCenter;
  
  // Current zoom level
  double _currentZoom = AppConstants.defaultZoom;
  
  // Selected destination location
  LocationModel? _selectedDestination;
  
  // Route points for drawing polyline between origin and destination
  List<LatLng> _routePoints = [];
  
  // Bottom sheet visibility state
  bool _isBottomSheetVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  /// Initialize location and center map on user's current position
  Future<void> _initializeLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.initialize();
    
    if (locationProvider.currentLocation != null) {
      final location = locationProvider.currentLocation!;
      _currentMapCenter = LatLng(location.latitude, location.longitude);
      
      // Center map on user location
      _mapController.move(_currentMapCenter!, _currentZoom);
      
      setState(() {});
    }
  }

  /// Update map camera to center on a specific location
  void _updateMapCamera(LocationModel location) {
    final newCenter = LatLng(location.latitude, location.longitude);
    _currentMapCenter = newCenter;
    
    // Animate map to new position
    _mapController.move(newCenter, _currentZoom);
    
    setState(() {});
  }

  /// Draw a route line between pickup and destination
  /// Currently draws a straight line - can be upgraded to use routing service
  /// (e.g., OSRM, GraphHopper) for turn-by-turn directions
  void _drawRoute(LocationModel pickup, LocationModel destination) {
    setState(() {
      _routePoints = [
        LatLng(pickup.latitude, pickup.longitude),
        LatLng(destination.latitude, destination.longitude),
      ];
    });
    
    // Fit map to show both points
    _fitMapToRoute();
  }

  /// Fit map bounds to show both pickup and destination points
  void _fitMapToRoute() {
    if (_routePoints.length >= 2) {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(100),
        ),
      );
    }
  }

  /// Handle destination selection from search screen
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
        _drawRoute(locationProvider.currentLocation!, result);
      }
    }
  }

  /// Request a ride and save to Supabase
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

      // Clear selection and route
      setState(() {
        _selectedDestination = null;
        _isBottomSheetVisible = false;
        _routePoints.clear();
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

  /// Refresh user location and recenter map
  Future<void> _refreshLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.refreshLocation();

    if (locationProvider.currentLocation != null) {
      _updateMapCamera(locationProvider.currentLocation!);
    }
  }

  /// Handle map tap - can be extended to add markers on tap
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // Future enhancement: Allow users to tap map to set destination
    // For now, this is a placeholder for future functionality
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
              // OpenStreetMap using flutter_map
              if (currentLocation != null && _currentMapCenter != null)
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentMapCenter!,
                    initialZoom: _currentZoom,
                    minZoom: AppConstants.minZoom,
                    maxZoom: AppConstants.maxZoom,
                    onTap: _onMapTap,
                    onPositionChanged: (MapPosition position, bool hasGesture) {
                      // Update current zoom level and center when user interacts with map
                      if (hasGesture) {
                        _currentZoom = position.zoom;
                        _currentMapCenter = position.center;
                      }
                    },
                    // Enable interaction: zoom, pan, rotation
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    // OpenStreetMap tile layer (free, no API key required)
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.zekri.deplacetoi',
                      // Alternative tile providers can be used here:
                      // - Mapbox (requires API key)
                      // - CartoDB
                      // - Stamen
                      // See: https://docs.fleaflet.dev/plugins/providers
                    ),
                    // Route polyline layer
                    if (_routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4,
                            color: AppColors.primaryPink,
                            // Future: Add pattern or gradient for route direction
                          ),
                        ],
                      ),
                    // Markers layer
                    MarkerLayer(
                      markers: [
                        // Current location marker
                        if (currentLocation != null)
                          Marker(
                            point: LatLng(
                              currentLocation.latitude,
                              currentLocation.longitude,
                            ),
                            width: 40,
                            height: 40,
                            child: const CurrentLocationMarker(
                              label: 'You',
                            ),
                          ),
                        // Destination marker
                        if (_selectedDestination != null)
                          Marker(
                            point: LatLng(
                              _selectedDestination!.latitude,
                              _selectedDestination!.longitude,
                            ),
                            width: 40,
                            height: 40,
                            child: const DestinationMarker(
                              label: 'Destination',
                            ),
                          ),
                        // Future: Add driver markers here when implementing driver tracking
                      ],
                    ),
                  ],
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
                    // Recenter on user location button
                    FloatingActionButton(
                      heroTag: 'refresh',
                      onPressed: _refreshLocation,
                      backgroundColor: AppColors.white,
                      child: Icon(Icons.my_location, color: AppColors.primaryPink),
                    ),
                    const SizedBox(height: 12),
                    // Menu button (for future features)
                    FloatingActionButton(
                      heroTag: 'menu',
                      onPressed: () {
                        // Future: Open menu drawer or settings
                      },
                      backgroundColor: AppColors.white,
                      child: Icon(Icons.menu, color: AppColors.primaryPink),
                    ),
                  ],
                ),
              ),
              // Bottom sheet for ride details
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
    _mapController.dispose();
    super.dispose();
  }
}
