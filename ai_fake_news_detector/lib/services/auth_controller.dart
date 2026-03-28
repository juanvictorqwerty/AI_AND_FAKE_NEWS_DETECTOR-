import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  
  final Rx<Map<String, dynamic>?> currentUser = Rx<Map<String, dynamic>?>(null);
  final RxString token = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;
  final RxBool isAnonymous = false.obs;

  bool get isLoggedIn => token.value.isNotEmpty;

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _isAnonymousKey = 'is_anonymous';
  static const String _lastTokenExtendKey = 'last_token_extend_date';

  @override
  void onInit() {
    super.onInit();
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);
      final savedUser = prefs.getString(_userKey);
      final savedIsAnonymous = prefs.getBool(_isAnonymousKey);

      if (savedToken != null && savedToken.isNotEmpty) {
        token.value = savedToken;
        // Restore anonymous status (default to false if not set)
        isAnonymous.value = savedIsAnonymous ?? false;
        // Restore user data if available
        if (savedUser != null) {
          currentUser.value = jsonDecode(savedUser);
        }
      }
    } catch (e) {
      debugPrint('Error loading token: $e');
    } finally {
      isInitialized.value = true;
    }
  }

  Future<void> _saveToken(String newToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newToken);
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }

  Future<void> _saveIsAnonymous(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isAnonymousKey, value);
    } catch (e) {
      debugPrint('Error saving isAnonymous: $e');
    }
  }

  Future<void> _clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove(_isAnonymousKey);
    } catch (e) {
      debugPrint('Error clearing token: $e');
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    isLoading.value = true;
    try {
      final result = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );
      
      if (result['success'] == true) {
        token.value = result['token'];
        currentUser.value = result['user'];
        isAnonymous.value = false; // Regular signup = not anonymous
        await _saveToken(result['token']);
        await _saveUser(result['user']);
        await _saveIsAnonymous(false);
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Signup failed');
        return false;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    isLoading.value = true;
    try {
      final result = await _authService.signIn(
        email: email,
        password: password,
      );
      
      if (result['success'] == true) {
        token.value = result['token'];
        currentUser.value = result['user'];
        isAnonymous.value = false; // Regular sign in = not anonymous
        await _saveToken(result['token']);
        await _saveUser(result['user']);
        await _saveIsAnonymous(false);
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Login failed');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> anonymousSignUp({String? name}) async {
    isLoading.value = true;
    try {
      final result = await _authService.anonymousSignUp(name: name);

      if (result['success'] == true) {
        token.value = result['token'];
        currentUser.value = result['user'];
        isAnonymous.value = true; // Mark as anonymous
        await _saveToken(result['token']);
        await _saveUser(result['user']);
        await _saveIsAnonymous(true);
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Anonymous signup failed');
        return false;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    // Call server to revoke token if user is logged in
    if (token.value.isNotEmpty) {
      try {
        await _authService.logout(token: token.value);
      } catch (e) {
        // Ignore errors during logout - still clear local storage
        debugPrint('Server logout error: $e');
      }
    }
    token.value = '';
    currentUser.value = null;
    await _clearToken();
  }

  // Check if current user is anonymous (stored in prefs, updated when completing profile)
  bool get isAnonymousUser => isAnonymous.value;

  // Get user name
  String get userName => currentUser.value?['name']?.toString() ?? 'User';

  // Get user email
  String get userEmail => currentUser.value?['email']?.toString() ?? '';

  // Complete profile for anonymous user (convert to registered user)
  Future<bool> completeProfile({
    required String email,
    required String password,
    required String name,
  }) async {
    if (token.value.isEmpty) {
      Get.snackbar('Error', 'Not logged in');
      return false;
    }

    isLoading.value = true;
    try {
      final result = await _authService.completeProfile(
        token: token.value,
        email: email,
        password: password,
        name: name,
      );

      if (result['success'] == true) {
        // completeProfile doesn't return a new token (same user, token stays valid)
        currentUser.value = result['user'];
        isAnonymous.value = false; // No longer anonymous after completing profile
        await _saveUser(result['user']);
        await _saveIsAnonymous(false);
        Get.snackbar('Success', 'Account created successfully!');
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Failed to create account');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Edit user profile
  Future<bool> editProfile({String? name, String? email, String? password}) async {
    if (token.value.isEmpty) {
      Get.snackbar('Error', 'Not logged in');
      return false;
    }

    isLoading.value = true;
    try {
      final result = await _authService.editProfile(
        token: token.value,
        name: name,
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        currentUser.value = result['user'];
        await _saveUser(result['user']);
        Get.snackbar('Success', 'Profile updated successfully!');
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Failed to update profile');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch current user profile from server
  Future<void> fetchProfile() async {
    if (token.value.isEmpty) return;

    try {
      final result = await _authService.getProfile(token: token.value);
      if (result['success'] == true) {
        currentUser.value = result['user'];
        await _saveUser(result['user']);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  // Change password
  Future<bool> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    if (token.value.isEmpty) {
      Get.snackbar('Error', 'Not logged in');
      return false;
    }

    isLoading.value = true;
    try {
      final result = await _authService.changePassword(
        token: token.value,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (result['success'] == true) {
        Get.snackbar('Success', result['message'] ?? 'Password changed successfully!');
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Failed to change password');
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Connection failed: ${e.toString()}');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Save user data to preferences
  Future<void> _saveUser(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (e) {
      debugPrint('Error saving user: $e');
    }
  }

  // Check if token should be extended (once per day)
  // Returns true if token was extended, false if already extended today
  Future<bool> prolongTokenIfNeeded() async {
    if (token.value.isEmpty) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastExtendDateStr = prefs.getString(_lastTokenExtendKey);
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastExtendDateStr != null) {
        final lastExtendDate = DateTime.parse(lastExtendDateStr);
        final lastExtendDay = DateTime(lastExtendDate.year, lastExtendDate.month, lastExtendDate.day);
        
        // Already extended today
        if (lastExtendDay.isAtSameMomentAs(today)) {
          return false;
        }
      }

      // Extend token for 7 more days
      final result = await _authService.extendToken(token: token.value);
      
      if (result['success'] == true) {
        // Update token if new one is provided
        if (result['token'] != null) {
          token.value = result['token'];
          await _saveToken(result['token']);
        }
        
        // Save today's date as last extend date
        await prefs.setString(_lastTokenExtendKey, today.toIso8601String());
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error extending token: $e');
      return false;
    }
  }
}
