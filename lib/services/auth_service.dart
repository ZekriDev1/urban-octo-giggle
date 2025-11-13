import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle authentication state and session persistence
class AuthService {
  static final AuthService _instance = AuthService._internal();
  final _supabase = Supabase.instance.client;

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  /// Check if user is already logged in (session exists)
  Future<bool> isUserLoggedIn() async {
    try {
      final session = _supabase.auth.currentSession;
      return session != null;
    } catch (e) {
      print('Error checking login state: $e');
      return false;
    }
  }

  /// Get current user if logged in
  User? getCurrentUser() {
    try {
      return _supabase.auth.currentUser;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  /// Sign out and clear session
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}
