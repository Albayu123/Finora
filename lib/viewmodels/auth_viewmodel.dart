import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

/// Mengelola status autentikasi sederhana untuk sinkronisasi Firestore.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  bool _isBusy = false;
  String? _errorMessage;

  AuthUser? get currentUser => _authService.currentUser;
  bool get isAuthenticated => currentUser != null;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  Future<void> restoreSession() async {
    await _authService.restoreSession();
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithEmail(
        email: email.trim(),
        password: password,
      );
      return true;
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan saat masuk. Coba lagi.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.registerWithEmail(
        email: email.trim(),
        password: password,
      );
      return true;
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Terjadi kesalahan saat mendaftar. Coba lagi.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signOut();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
