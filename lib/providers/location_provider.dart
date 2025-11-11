import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

/// Provider for location state management
class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  LocationModel? _currentLocation;
  LocationModel? _selectedDestination;
  bool _isLoading = false;
  String? _errorMessage;
  
  Position? get currentPosition => _currentPosition;
  LocationModel? get currentLocation => _currentLocation;
  LocationModel? get selectedDestination => _selectedDestination;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  /// Initialize location service and get current position
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _updateCurrentPosition();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Update current position
  Future<void> _updateCurrentPosition() async {
    try {
      _currentPosition = await LocationService.getCurrentPosition();
      final address = await LocationService.getAddressFromCoordinates(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );
      
      _currentLocation = LocationModel(
        address: address,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _currentPosition = null;
      _currentLocation = null;
    }
    notifyListeners();
  }
  
  /// Set selected destination
  void setDestination(LocationModel destination) {
    _selectedDestination = destination;
    notifyListeners();
  }
  
  /// Clear selected destination
  void clearDestination() {
    _selectedDestination = null;
    notifyListeners();
  }
  
  /// Search for location by address
  Future<LocationModel?> searchLocation(String address) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final location = await LocationService.getCoordinatesFromAddress(address);
      _errorMessage = null;
      return location;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Refresh current location
  Future<void> refreshLocation() async {
    await _updateCurrentPosition();
  }
  
  /// Calculate distance to destination
  double? calculateDistanceToDestination() {
    if (_currentLocation == null || _selectedDestination == null) {
      return null;
    }
    
    return LocationService.calculateDistance(
      startLatitude: _currentLocation!.latitude,
      startLongitude: _currentLocation!.longitude,
      endLatitude: _selectedDestination!.latitude,
      endLongitude: _selectedDestination!.longitude,
    );
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

