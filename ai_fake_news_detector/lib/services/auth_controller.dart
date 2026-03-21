import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  
  final Rx<Map<String, dynamic>?> currentUser = Rx<Map<String, dynamic>?>(null);
  final RxString token = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;

  bool get isLoggedIn => token.value.isNotEmpty;

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

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
      
      if (savedToken != null && savedToken.isNotEmpty) {
        token.value = savedToken;
        // Note: In a real app, you'd also restore user data
        // For now, we'll just use the token
      }
    } catch (e) {
      print('Error loading token: $e');
    } finally {
      isInitialized.value = true;
    }
  }

  Future<void> _saveToken(String newToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newToken);
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  Future<void> _clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (e) {
      print('Error clearing token: $e');
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
        await _saveToken(result['token']);
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
        await _saveToken(result['token']);
        return true;
      } else {
        Get.snackbar('Error', result['message'] ?? 'Login failed');
        return false;
      }
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
        await _saveToken(result['token']);
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
    token.value = '';
    currentUser.value = null;
    await _clearToken();
  }
}
