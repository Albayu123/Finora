// File generated for Finora Firebase project (finora-app-a0531).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Konfigurasi [FirebaseOptions] untuk inisialisasi Firebase Finora.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk Android. '
          'Jalankan flutterfire configure bila menargetkan Android.',
        );
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk iOS. '
          'Jalankan flutterfire configure bila menargetkan iOS.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Plugin C++ FlutterFire tidak mendukung Linux secara native; '
          'Finora memakai REST fallback pada Linux.',
        );
      default:
        throw UnsupportedError(
          'Platform tidak didukung oleh DefaultFirebaseOptions.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBwwMTXxKBKL3zWTgi4FHP0kvv7Ds4e5KE',
    appId: '1:59699087805:web:0ffc7fc88c173d0b6bead4',
    messagingSenderId: '59699087805',
    projectId: 'finora-app-a0531',
    authDomain: 'finora-app-a0531.firebaseapp.com',
    storageBucket: 'finora-app-a0531.firebasestorage.app',
    measurementId: 'G-6JPD0S1EHS',
  );
}
