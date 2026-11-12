import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finora_app/main.dart';
import 'package:finora_app/models/transaction_model.dart';
import 'package:finora_app/services/auth_service.dart';
import 'package:finora_app/services/currency_api_service.dart';
import 'package:finora_app/services/database_helper.dart';
import 'package:finora_app/services/firestore_service.dart';
import 'package:finora_app/viewmodels/auth_viewmodel.dart';
import 'package:finora_app/viewmodels/theme_viewmodel.dart';
import 'package:finora_app/viewmodels/transaction_viewmodel.dart';

class _InMemoryDatabaseHelper extends DatabaseHelper {
  final List<TransactionModel> _items = [];

  @override
  Future<void> insertTransaction(TransactionModel transaction) async {
    _items.removeWhere((item) => item.id == transaction.id);
    _items.add(transaction);
  }

  @override
  Future<List<TransactionModel>> getTransactions() async {
    final sorted = [..._items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<List<TransactionModel>> getUnsyncedTransactions() async {
    return _items.where((item) => !item.isSynced).toList();
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {
    final index = _items.indexWhere((item) => item.id == transaction.id);
    if (index != -1) {
      _items[index] = transaction;
    }
  }

  @override
  Future<void> markAsSynced(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(isSynced: true);
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _items.removeWhere((item) => item.id == id);
  }
}

class _TestAuthService extends AuthService {
  @override
  AuthUser? get currentUser => null;
}

class _TestFirestoreService extends FirestoreService {
  @override
  Future<void> backupTransaction({
    required String uid,
    required TransactionModel transaction,
    String? idToken,
  }) async {}
}

void main() {
  Future<FinoraApp> createTestApp(DatabaseHelper dbHelper) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final themeVm = ThemeViewModel(preferences: prefs);
    final authService = _TestAuthService();
    final authVm = AuthViewModel(authService: authService);
    final currencyService = CurrencyApiService(
      preferences: prefs,
      apiKeyOverride: 'test-key',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'result': 'success',
            'conversion_rates': {'IDR': 16000.0},
          }),
          200,
        ),
      ),
    );
    final txVm = TransactionViewModel(
      dbHelper: dbHelper,
      firestoreService: _TestFirestoreService(),
      currencyService: currencyService,
      authService: authService,
    );
    await txVm.initialize();

    return FinoraApp(
      themeViewModel: themeVm,
      authViewModel: authVm,
      transactionViewModel: txVm,
    );
  }

  testWidgets(
    'Empty state, validasi form, tambah transaksi, edit, dialog akun, dan toggle tema',
    (tester) async {
      final dbHelper = _InMemoryDatabaseHelper();

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final app = await createTestApp(dbHelper);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Belum ada transaksi tercatat'), findsOneWidget);

      await tester.tap(find.byTooltip('Ganti ke mode gelap'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ganti ke mode terang'), findsOneWidget);

      await tester.tap(find.text('Masuk Akun'));
      await tester.pumpAndSettle();
      expect(find.text('Masuk ke Akun Finora'), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Catat Transaksi').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();
      expect(find.text('Nominal harus lebih dari Rp 0.'), findsOneWidget);
      expect(find.text('Judul transaksi wajib diisi.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal (Rupiah)'),
        '45000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Judul Transaksi'),
        'Makan Malam',
      );
      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();

      expect(find.text('Makan Malam'), findsOneWidget);
      expect(find.text('1 catatan ditampilkan'), findsOneWidget);
      expect(find.text('-Rp 45.000'), findsWidgets);

      await tester.tap(find.text('Makan Malam'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah Transaksi'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Layout responsif tanpa overflow pada layar ponsel dan tablet', (
    tester,
  ) async {
    final dbHelper = _InMemoryDatabaseHelper();

    for (final size in [const Size(390, 844), const Size(800, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      final app = await createTestApp(dbHelper);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
  });
}
