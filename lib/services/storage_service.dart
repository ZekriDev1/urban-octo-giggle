import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';

/// Service for local storage operations
class StorageService {
  static SharedPreferences? _prefs;
  
  /// Initialize storage service
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Get SharedPreferences instance
  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call StorageService.initialize() first.');
    }
    return _prefs!;
  }
  
  // ============ Session Management ============
  
  /// Save user session
  static Future<void> saveSession(String sessionData) async {
    await prefs.setString('user_session', sessionData);
  }
  
  /// Get user session
  static String? getSession() {
    return prefs.getString('user_session');
  }
  
  /// Clear user session
  static Future<void> clearSession() async {
    await prefs.remove('user_session');
  }
  
  // ============ Recent Addresses ============
  
  /// Save recent addresses
  static Future<void> saveRecentAddresses(List<LocationModel> addresses) async {
    final jsonList = addresses.map((addr) => addr.toJson()).toList();
    await prefs.setString('recent_addresses', jsonEncode(jsonList));
  }
  
  /// Get recent addresses
  static List<LocationModel> getRecentAddresses() {
    final jsonString = prefs.getString('recent_addresses');
    if (jsonString == null) return [];
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => LocationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Add recent address
  static Future<void> addRecentAddress(LocationModel address) async {
    final addresses = getRecentAddresses();
    
    // Remove if already exists
    addresses.removeWhere((addr) => 
      addr.latitude == address.latitude && 
      addr.longitude == address.longitude
    );
    
    // Add to beginning
    addresses.insert(0, address.copyWith(
      lastUsed: DateTime.now(),
    ));
    
    // Keep only last 10
    if (addresses.length > 10) {
      addresses.removeRange(10, addresses.length);
    }
    
    await saveRecentAddresses(addresses);
  }
  
  // ============ Favorite Locations ============
  
  /// Save favorite locations
  static Future<void> saveFavoriteLocations(List<LocationModel> locations) async {
    final jsonList = locations.map((loc) => loc.toJson()).toList();
    await prefs.setString('favorite_locations', jsonEncode(jsonList));
  }
  
  /// Get favorite locations
  static List<LocationModel> getFavoriteLocations() {
    final jsonString = prefs.getString('favorite_locations');
    if (jsonString == null) return [];
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => LocationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Add favorite location
  static Future<void> addFavoriteLocation(LocationModel location) async {
    final locations = getFavoriteLocations();
    
    // Remove if already exists
    locations.removeWhere((loc) => 
      loc.latitude == location.latitude && 
      loc.longitude == location.longitude
    );
    
    // Add to beginning
    locations.insert(0, location.copyWith(isFavorite: true));
    
    await saveFavoriteLocations(locations);
  }
  
  /// Remove favorite location
  static Future<void> removeFavoriteLocation(LocationModel location) async {
    final locations = getFavoriteLocations();
    locations.removeWhere((loc) => 
      loc.latitude == location.latitude && 
      loc.longitude == location.longitude
    );
    await saveFavoriteLocations(locations);
  }
  
  /// Check if location is favorite
  static bool isFavorite(LocationModel location) {
    final favorites = getFavoriteLocations();
    return favorites.any((loc) => 
      loc.latitude == location.latitude && 
      loc.longitude == location.longitude
    );
  }
}

