import 'api_keys.dart';

/// Application-wide constants
class AppConstants {
  // Supabase configuration (imported from ApiKeys)
  static const String supabaseUrl = ApiKeys.supabaseUrl;
  static const String supabaseAnonKey = ApiKeys.supabaseAnonKey;
  
  // Splash screen duration
  static const Duration splashDuration = Duration(seconds: 4);
  
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  // Map configuration
  static const double defaultZoom = 15.0;
  static const double minZoom = 10.0;
  static const double maxZoom = 20.0;
  
  // Validation
  static const int minPasswordLength = 8;
  
  // Storage keys
  static const String userSessionKey = 'user_session';
  static const String recentAddressesKey = 'recent_addresses';
  static const String favoriteLocationsKey = 'favorite_locations';
}

