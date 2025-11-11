import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';

/// Provider for authentication state management
class AuthProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  
  /// Initialize auth provider and check for existing session
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final user = SupabaseService.getCurrentUser();
      if (user != null) {
        await _loadUserProfile(user.id);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    String? name,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
      
      if (response.user != null) {
        await _loadUserProfile(response.user!.id);
        await _saveSession(response.session);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await SupabaseService.signIn(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        await _loadUserProfile(response.user!.id);
        await _saveSession(response.session);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await SupabaseService.signOut();
      await StorageService.clearSession();
      _currentUser = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Update user profile
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? profilePictureUrl,
    double? latitude,
    double? longitude,
  }) async {
    if (_currentUser == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      await SupabaseService.updateUserProfile(
        userId: _currentUser!.id,
        name: name,
        phone: phone,
        profilePictureUrl: profilePictureUrl,
        latitude: latitude,
        longitude: longitude,
      );
      
      await _loadUserProfile(_currentUser!.id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load user profile from database
  Future<void> _loadUserProfile(String userId) async {
    try {
      final userProfile = await SupabaseService.getUserProfile(userId);
      if (userProfile != null) {
        _currentUser = userProfile;
      } else {
        // If profile doesn't exist, create basic one from auth user
        final authUser = SupabaseService.getCurrentUser();
        if (authUser != null) {
          _currentUser = UserModel(
            id: authUser.id,
            email: authUser.email ?? '',
            name: authUser.userMetadata?['name'] as String?,
            phone: authUser.userMetadata?['phone'] as String?,
          );
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }
  
  /// Save session to local storage
  Future<void> _saveSession(Session? session) async {
    if (session != null) {
      await StorageService.saveSession(session.accessToken);
    }
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

