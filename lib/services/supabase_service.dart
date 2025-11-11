import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';

/// Service for Supabase authentication and database operations
class SupabaseService {
  static SupabaseClient? _client;
  
  /// Initialize Supabase client
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }
  
  /// Get Supabase client instance
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call SupabaseService.initialize() first.');
    }
    return _client!;
  }
  
  // ============ Authentication Methods ============
  
  /// Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? name,
    String? phone,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
      },
    );
    
    // Create user profile in database
    if (response.user != null) {
      await _createUserProfile(response.user!.id, email, name, phone);
    }
    
    return response;
  }
  
  /// Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  /// Sign out current user
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  /// Get current user
  static User? getCurrentUser() {
    return client.auth.currentUser;
  }
  
  /// Get current session
  static Session? getCurrentSession() {
    return client.auth.currentSession;
  }
  
  /// Stream of auth state changes
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
  
  // ============ User Profile Methods ============
  
  /// Create user profile in database
  static Future<void> _createUserProfile(
    String userId,
    String email,
    String? name,
    String? phone,
  ) async {
    await client.from('users').insert({
      'id': userId,
      'email': email,
      'name': name,
      'phone': phone,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
  
  /// Get user profile
  static Future<UserModel?> getUserProfile(String userId) async {
    final response = await client
        .from('users')
        .select()
        .eq('id', userId)
        .single();
    
    if (response == null) return null;
    return UserModel.fromJson(response as Map<String, dynamic>);
  }
  
  /// Update user profile
  static Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? phone,
    String? profilePictureUrl,
    double? latitude,
    double? longitude,
  }) async {
    final updateData = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (name != null) updateData['name'] = name;
    if (phone != null) updateData['phone'] = phone;
    if (profilePictureUrl != null) updateData['profile_picture_url'] = profilePictureUrl;
    if (latitude != null) updateData['latitude'] = latitude;
    if (longitude != null) updateData['longitude'] = longitude;
    
    await client
        .from('users')
        .update(updateData)
        .eq('id', userId);
  }
  
  // ============ Ride Methods ============
  
  /// Create a new ride
  static Future<RideModel> createRide({
    required String userId,
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double destinationLatitude,
    required double destinationLongitude,
    required String destinationAddress,
    double? fare,
    int? estimatedDuration,
    double? distance,
  }) async {
    final rideData = {
      'user_id': userId,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'pickup_address': pickupAddress,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'destination_address': destinationAddress,
      'status': 'pending',
      'fare': fare,
      'estimated_duration': estimatedDuration,
      'distance': distance,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    final response = await client
        .from('rides')
        .insert(rideData)
        .select()
        .single();
    
    return RideModel.fromJson(response as Map<String, dynamic>);
  }
  
  /// Get user's ride history
  static Future<List<RideModel>> getRideHistory(String userId) async {
    final response = await client
        .from('rides')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => RideModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  /// Update ride status
  static Future<void> updateRideStatus({
    required String rideId,
    required String status,
    String? driverId,
  }) async {
    final updateData = {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (driverId != null) updateData['driver_id'] = driverId;
    
    await client
        .from('rides')
        .update(updateData)
        .eq('id', rideId);
  }
  
  /// Get active ride for user
  static Future<RideModel?> getActiveRide(String userId) async {
    final response = await client
        .from('rides')
        .select()
        .eq('user_id', userId)
        .in_('status', ['pending', 'accepted', 'in_progress'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    
    if (response == null) return null;
    return RideModel.fromJson(response as Map<String, dynamic>);
  }
}

