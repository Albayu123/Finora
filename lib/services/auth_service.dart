import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

/// Data ringkas pengguna terautentikasi untuk keperluan cadangan Firestore.
class AuthUser {
  const AuthUser({required this.uid, required this.email});

  final String uid;
  final String email;
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Layanan autentikasi sederhana lintas Web (FirebaseAuth) dan Linux (REST).
class AuthService {
  AuthService({http.Client? client, this._preferences, this._forceRestMode})
    : _client = client ?? http.Client();

  static const String _sessionKey = 'finora_linux_auth_session';

  final http.Client _client;
  final SharedPreferences? _preferences;
  final bool? _forceRestMode;

  AuthUser? _restUser;
  String? _restIdToken;
  String? _restRefreshToken;

  bool get _useRestFallback {
    if (_forceRestMode != null) return _forceRestMode;
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
  }

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  AuthUser? get currentUser {
    if (_useRestFallback) {
      return _restUser;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return AuthUser(uid: user.uid, email: user.email ?? '');
  }

  Future<void> restoreSession() async {
    if (!_useRestFallback) return;
    final prefs = await _prefs;
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final uid = decoded['uid'] as String?;
      final email = decoded['email'] as String?;
      final idToken = decoded['idToken'] as String?;
      final refreshToken = decoded['refreshToken'] as String?;
      if (uid != null && uid.isNotEmpty && idToken != null) {
        _restUser = AuthUser(uid: uid, email: email ?? '');
        _restIdToken = idToken;
        _restRefreshToken = refreshToken;
      }
    } catch (_) {
      await prefs.remove(_sessionKey);
    }
  }

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_useRestFallback) {
      try {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
        final user = credential.user;
        if (user == null) {
          throw const AuthServiceException('Gagal membaca data pengguna.');
        }
        return AuthUser(uid: user.uid, email: user.email ?? email);
      } on FirebaseAuthException catch (e) {
        throw AuthServiceException(_mapErrorMessage(e.code));
      }
    }

    return _authenticateRest(
      endpoint: 'accounts:signInWithPassword',
      email: email,
      password: password,
    );
  }

  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_useRestFallback) {
      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        final user = credential.user;
        if (user == null) {
          throw const AuthServiceException('Gagal membuat akun baru.');
        }
        return AuthUser(uid: user.uid, email: user.email ?? email);
      } on FirebaseAuthException catch (e) {
        throw AuthServiceException(_mapErrorMessage(e.code));
      }
    }

    return _authenticateRest(
      endpoint: 'accounts:signUp',
      email: email,
      password: password,
    );
  }

  Future<String?> getIdToken() async {
    if (!_useRestFallback) {
      return FirebaseAuth.instance.currentUser?.getIdToken();
    }
    if (_restRefreshToken != null && _restRefreshToken!.isNotEmpty) {
      await _refreshRestToken();
    }
    return _restIdToken;
  }

  Future<void> signOut() async {
    if (!_useRestFallback) {
      await FirebaseAuth.instance.signOut();
      return;
    }
    _restUser = null;
    _restIdToken = null;
    _restRefreshToken = null;
    final prefs = await _prefs;
    await prefs.remove(_sessionKey);
  }

  Future<AuthUser> _authenticateRest({
    required String endpoint,
    required String email,
    required String password,
  }) async {
    final apiKey = DefaultFirebaseOptions.web.apiKey;
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/$endpoint?key=$apiKey',
    );

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'returnSecureToken': true,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final errorCode =
            (decoded['error'] as Map<String, dynamic>?)?['message']
                ?.toString() ??
            'UNKNOWN';
        throw AuthServiceException(_mapErrorMessage(errorCode));
      }

      final uid = decoded['localId'] as String;
      final userEmail = (decoded['email'] as String?) ?? email;
      _restUser = AuthUser(uid: uid, email: userEmail);
      _restIdToken = decoded['idToken'] as String?;
      _restRefreshToken = decoded['refreshToken'] as String?;

      await _persistRestSession();
      return _restUser!;
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(
        'Tidak dapat terhubung ke layanan autentikasi. Cek koneksi internet Anda.',
      );
    }
  }

  Future<void> _refreshRestToken() async {
    final refreshToken = _restRefreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return;

    final apiKey = DefaultFirebaseOptions.web.apiKey;
    final uri = Uri.parse(
      'https://securetoken.googleapis.com/v1/token?key=$apiKey',
    );

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _restIdToken = decoded['id_token'] as String? ?? _restIdToken;
        _restRefreshToken =
            decoded['refresh_token'] as String? ?? _restRefreshToken;
        await _persistRestSession();
      }
    } catch (_) {
      // Biarkan token yang ada tetap dicoba ketika jaringan tidak stabil.
    }
  }

  Future<void> _persistRestSession() async {
    if (_restUser == null) return;
    final prefs = await _prefs;
    await prefs.setString(
      _sessionKey,
      jsonEncode({
        'uid': _restUser!.uid,
        'email': _restUser!.email,
        'idToken': _restIdToken,
        'refreshToken': _restRefreshToken,
      }),
    );
  }

  String _mapErrorMessage(String code) {
    final normalized = code.toLowerCase();
    if (normalized.contains('invalid_login_credentials') ||
        normalized.contains('invalid-credential') ||
        normalized.contains('wrong-password') ||
        normalized.contains('user-not-found') ||
        normalized.contains('email_not_found') ||
        normalized.contains('invalid_password')) {
      return 'Email atau kata sandi tidak sesuai.';
    }
    if (normalized.contains('email_exists') ||
        normalized.contains('email-already-in-use')) {
      return 'Email ini sudah terdaftar. Silakan masuk.';
    }
    if (normalized.contains('invalid_email') ||
        normalized.contains('invalid-email')) {
      return 'Format email tidak valid.';
    }
    if (normalized.contains('weak_password') ||
        normalized.contains('weak-password')) {
      return 'Kata sandi minimal 6 karakter.';
    }
    if (normalized.contains('operation_not_allowed') ||
        normalized.contains('operation-not-allowed')) {
      return 'Metode masuk Email/Kata Sandi belum diaktifkan di Firebase Console.';
    }
    if (normalized.contains('configuration_not_found') ||
        normalized.contains('configuration-not-found')) {
      return 'Firebase Authentication belum diaktifkan di Firebase Console.';
    }
    if (normalized.contains('too_many_attempts') ||
        normalized.contains('too-many-requests')) {
      return 'Terlalu banyak percobaan masuk. Coba beberapa saat lagi.';
    }
    return 'Autentikasi gagal ($code).';
  }
}
