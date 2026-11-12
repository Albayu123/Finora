import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/transaction_model.dart';

class FirestoreBackupException implements Exception {
  const FirestoreBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Layanan cadangan satu arah ke Cloud Firestore untuk catatan lokal.
class FirestoreService {
  FirestoreService({http.Client? client, this._forceRestMode})
    : _client = client ?? http.Client();

  final http.Client _client;
  final bool? _forceRestMode;

  bool get _useRestFallback {
    if (_forceRestMode != null) return _forceRestMode;
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Mencadangkan satu transaksi dengan ID dokumen identik dengan UUID lokal.
  Future<void> backupTransaction({
    required String uid,
    required TransactionModel transaction,
    String? idToken,
  }) async {
    if (!_useRestFallback) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toFirestoreMap());
      return;
    }

    if (idToken == null || idToken.isEmpty) {
      throw const FirestoreBackupException(
        'Sesi login diperlukan untuk menyinkronkan ke Firestore.',
      );
    }

    final projectId = DefaultFirebaseOptions.web.projectId;
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/'
      'databases/(default)/documents/users/$uid/transactions/${transaction.id}',
    );

    final body = jsonEncode({
      'fields': {
        'id': {'stringValue': transaction.id},
        'title': {'stringValue': transaction.title},
        'amount': {'doubleValue': transaction.amount},
        'type': {'stringValue': transaction.type.value},
        'category': {'stringValue': transaction.category},
        'note': {'stringValue': transaction.note},
        'created_at': {'stringValue': transaction.createdAt.toIso8601String()},
        'is_synced': {'booleanValue': true},
      },
    });

    final response = await _client
        .patch(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw FirestoreBackupException(
          'Akses Firestore ditolak (HTTP ${response.statusCode}). '
          'Periksa Firestore Security Rules dan pastikan sesi akun masih aktif.',
        );
      }
      throw FirestoreBackupException(
        'Firestore menolak sinkronisasi (HTTP ${response.statusCode}). '
        'Pastikan Cloud Firestore sudah diaktifkan di Firebase Console.',
      );
    }
  }
}
