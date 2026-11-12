import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finora_app/models/transaction_model.dart';
import 'package:finora_app/services/auth_service.dart';
import 'package:finora_app/services/currency_api_service.dart';
import 'package:finora_app/services/database_helper.dart';
import 'package:finora_app/services/firestore_service.dart';
import 'package:finora_app/viewmodels/auth_viewmodel.dart';
import 'package:finora_app/viewmodels/transaction_viewmodel.dart';

class _FakeAuthService extends AuthService {
  AuthUser? user;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<String?> getIdToken() async => user != null ? 'fake-token' : null;
}

class _FakeFirestoreService extends FirestoreService {
  bool shouldFail = false;
  final List<String> backedUpIds = [];

  @override
  Future<void> backupTransaction({
    required String uid,
    required TransactionModel transaction,
    String? idToken,
  }) async {
    if (shouldFail) {
      throw const FirestoreBackupException('Simulasi gagal koneksi Firestore');
    }
    backedUpIds.add(transaction.id);
  }
}

void main() {
  sqfliteFfiInit();

  late DatabaseHelper dbHelper;
  late _FakeAuthService authService;
  late _FakeFirestoreService firestoreService;
  late CurrencyApiService currencyService;
  late TransactionViewModel viewModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    dbHelper = DatabaseHelper(
      factoryOverride: databaseFactoryFfi,
      dbPathOverride: inMemoryDatabasePath,
    );
    authService = _FakeAuthService();
    firestoreService = _FakeFirestoreService();
    currencyService = CurrencyApiService(
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

    viewModel = TransactionViewModel(
      dbHelper: dbHelper,
      firestoreService: firestoreService,
      currencyService: currencyService,
      authService: authService,
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  test(
    'menghitung saldo, pemasukan, pengeluaran, filter, dan konversi USD',
    () async {
      await viewModel.initialize();

      await viewModel.addTransaction(
        title: 'Gaji Part-time',
        amount: 1600000,
        type: TransactionType.income,
        category: 'Gaji',
      );
      await viewModel.addTransaction(
        title: 'Beli Buku',
        amount: 160000,
        type: TransactionType.expense,
        category: 'Pendidikan',
      );

      expect(viewModel.totalIncome, 1600000);
      expect(viewModel.totalExpense, 160000);
      expect(viewModel.totalBalance, 1440000);
      expect(viewModel.unsyncedCount, 2);
      expect(viewModel.totalBalanceInUsd, closeTo(90.0, 0.001));

      viewModel.setFilterType(TransactionFilterType.expense);
      expect(viewModel.filteredTransactions.length, 1);
      expect(viewModel.filteredTransactions.first.title, 'Beli Buku');

      viewModel.setFilterType(TransactionFilterType.all);
      viewModel.setSearchQuery('gaji');
      expect(viewModel.filteredTransactions.length, 1);
      expect(viewModel.filteredTransactions.first.title, 'Gaji Part-time');
    },
  );

  test(
    'syncPendingTransactions meminta login jika belum masuk dan menyinkronkan jika sudah masuk',
    () async {
      await viewModel.addTransaction(
        title: 'Kopi',
        amount: 25000,
        type: TransactionType.expense,
        category: 'Makan & Minum',
      );

      await viewModel.syncPendingTransactions();
      expect(viewModel.syncHasError, isTrue);
      expect(viewModel.unsyncedCount, 1);

      authService.user = const AuthUser(
        uid: 'user-1',
        email: 'mhs@kampus.ac.id',
      );
      await viewModel.syncPendingTransactions();

      expect(viewModel.syncHasError, isFalse);
      expect(viewModel.unsyncedCount, 0);
      expect(firestoreService.backedUpIds.length, 1);
    },
  );

  test(
    'sync gagal tetap mempertahankan data lokal dan is_synced tetap false',
    () async {
      authService.user = const AuthUser(
        uid: 'user-1',
        email: 'mhs@kampus.ac.id',
      );
      firestoreService.shouldFail = true;

      await viewModel.addTransaction(
        title: 'Print Tugas',
        amount: 12000,
        type: TransactionType.expense,
        category: 'Pendidikan',
      );

      await viewModel.syncPendingTransactions();
      expect(viewModel.syncHasError, isTrue);
      expect(viewModel.unsyncedCount, 1);
      expect(viewModel.transactions.length, 1);
    },
  );

  test(
    'sesi login REST di AuthViewModel terbaca oleh TransactionViewModel saat berbagi AuthService',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final sharedAuthService = AuthService(
        forceRestMode: true,
        preferences: prefs,
        client: MockClient((request) async {
          if (request.url.path.contains('accounts:signInWithPassword')) {
            return http.Response(
              jsonEncode({
                'localId': 'uid-linux-1',
                'email': 'alief@kampus.ac.id',
                'idToken': 'token-awal',
                'refreshToken': 'refresh-1',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'id_token': 'token-segar',
              'refresh_token': 'refresh-2',
            }),
            200,
          );
        }),
      );

      final authVm = AuthViewModel(authService: sharedAuthService);
      final sharedTxVm = TransactionViewModel(
        dbHelper: dbHelper,
        firestoreService: firestoreService,
        currencyService: currencyService,
        authService: sharedAuthService,
      );
      await sharedTxVm.initialize();

      final loggedIn = await authVm.signIn(
        email: 'alief@kampus.ac.id',
        password: 'password123',
      );
      expect(loggedIn, isTrue);

      await sharedTxVm.addTransaction(
        title: 'Belanja Kipas',
        amount: 130000,
        type: TransactionType.expense,
        category: 'Belanja',
      );
      await sharedTxVm.syncPendingTransactions();

      expect(sharedTxVm.syncHasError, isFalse);
      expect(sharedTxVm.unsyncedCount, 0);
      expect(firestoreService.backedUpIds.length, 1);
    },
  );
}
