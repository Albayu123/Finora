import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction_model.dart';
import '../services/auth_service.dart';
import '../services/currency_api_service.dart';
import '../services/database_helper.dart';
import '../services/firestore_service.dart';

enum TransactionFilterType { all, income, expense }

/// ViewModel utama untuk transaksi lokal SQLite, konversi kurs, dan backup Firestore.
class TransactionViewModel extends ChangeNotifier {
  TransactionViewModel({
    DatabaseHelper? dbHelper,
    FirestoreService? firestoreService,
    CurrencyApiService? currencyService,
    AuthService? authService,
    Uuid? uuid,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance,
       _firestoreService = firestoreService ?? FirestoreService(),
       _currencyService = currencyService ?? CurrencyApiService(),
       _authService = authService ?? AuthService(),
       _uuid = uuid ?? const Uuid();

  final DatabaseHelper _dbHelper;
  final FirestoreService _firestoreService;
  final CurrencyApiService _currencyService;
  final AuthService _authService;
  final Uuid _uuid;

  List<TransactionModel> _transactions = [];
  TransactionFilterType _filterType = TransactionFilterType.all;
  String _searchQuery = '';

  bool _isLoadingTransactions = false;
  String? _transactionsError;

  bool _isSyncing = false;
  String? _syncMessage;
  bool _syncHasError = false;

  bool _isLoadingRate = false;
  ExchangeRateResult? _exchangeRate;
  String? _rateError;

  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  TransactionFilterType get filterType => _filterType;
  String get searchQuery => _searchQuery;

  bool get isLoadingTransactions => _isLoadingTransactions;
  String? get transactionsError => _transactionsError;

  bool get isSyncing => _isSyncing;
  String? get syncMessage => _syncMessage;
  bool get syncHasError => _syncHasError;

  bool get isLoadingRate => _isLoadingRate;
  ExchangeRateResult? get exchangeRate => _exchangeRate;
  String? get rateError => _rateError;

  bool get hasActiveFilters =>
      _filterType != TransactionFilterType.all ||
      _searchQuery.trim().isNotEmpty;

  List<TransactionModel> get filteredTransactions {
    final query = _searchQuery.trim().toLowerCase();
    return _transactions.where((tx) {
      final matchesType = switch (_filterType) {
        TransactionFilterType.all => true,
        TransactionFilterType.income => tx.type == TransactionType.income,
        TransactionFilterType.expense => tx.type == TransactionType.expense,
      };
      if (!matchesType) return false;
      if (query.isEmpty) return true;
      return tx.title.toLowerCase().contains(query) ||
          tx.category.toLowerCase().contains(query) ||
          tx.note.toLowerCase().contains(query);
    }).toList();
  }

  double get totalIncome => _transactions
      .where((tx) => tx.type == TransactionType.income)
      .fold(0, (sum, tx) => sum + tx.amount);

  double get totalExpense => _transactions
      .where((tx) => tx.type == TransactionType.expense)
      .fold(0, (sum, tx) => sum + tx.amount);

  double get totalBalance => totalIncome - totalExpense;

  int get unsyncedCount => _transactions.where((tx) => !tx.isSynced).length;

  double? get totalBalanceInUsd {
    final rate = _exchangeRate?.usdToIdrRate;
    if (rate == null || rate <= 0) return null;
    return _currencyService.idrToUsd(totalBalance, rate);
  }

  double convertIdrToUsd(double idrAmount) {
    final rate = _exchangeRate?.usdToIdrRate ?? 0;
    return _currencyService.idrToUsd(idrAmount, rate);
  }

  double convertUsdToIdr(double usdAmount) {
    final rate = _exchangeRate?.usdToIdrRate ?? 0;
    return _currencyService.usdToIdr(usdAmount, rate);
  }

  Future<void> initialize() async {
    await fetchTransactions();
    final cached = await _currencyService.getCachedRate();
    if (cached != null) {
      _exchangeRate = cached;
      notifyListeners();
    }
    await fetchExchangeRate();
  }

  Future<void> fetchTransactions() async {
    _isLoadingTransactions = true;
    _transactionsError = null;
    notifyListeners();

    try {
      _transactions = await _dbHelper.getTransactions();
    } catch (e) {
      debugPrint('Gagal memuat transaksi SQLite: $e');
      _transactionsError = 'Gagal membaca data transaksi lokal.';
    } finally {
      _isLoadingTransactions = false;
      notifyListeners();
    }
  }

  Future<bool> addTransaction({
    required String title,
    required double amount,
    required TransactionType type,
    required String category,
    String note = '',
    DateTime? createdAt,
  }) async {
    final tx = TransactionModel(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount,
      type: type,
      category: category,
      note: note.trim(),
      createdAt: createdAt ?? DateTime.now(),
      isSynced: false,
    );

    try {
      await _dbHelper.insertTransaction(tx);
      _transactions = await _dbHelper.getTransactions();
      _transactionsError = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Gagal menambah transaksi: $e');
      _transactionsError = 'Gagal menyimpan transaksi ke penyimpanan lokal.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTransaction(TransactionModel transaction) async {
    // Setiap perubahan lokal menandai is_synced=false agar ikut tercetak saat sync berikutnya.
    final pendingTx = transaction.copyWith(isSynced: false);
    try {
      await _dbHelper.updateTransaction(pendingTx);
      _transactions = await _dbHelper.getTransactions();
      _transactionsError = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Gagal memperbarui transaksi: $e');
      _transactionsError = 'Gagal memperbarui transaksi lokal.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(String id) async {
    try {
      await _dbHelper.deleteTransaction(id);
      _transactions = await _dbHelper.getTransactions();
      _transactionsError = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Gagal menghapus transaksi: $e');
      _transactionsError = 'Gagal menghapus transaksi lokal.';
      notifyListeners();
      return false;
    }
  }

  Future<void> syncPendingTransactions() async {
    if (_isSyncing) return;

    final user = _authService.currentUser;
    if (user == null) {
      _syncHasError = true;
      _syncMessage =
          'Masuk akun terlebih dahulu untuk menyinkronkan ke Firestore.';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _syncHasError = false;
    _syncMessage = 'Menyinkronkan catatan ke Firestore...';
    notifyListeners();

    try {
      final pending = await _dbHelper.getUnsyncedTransactions();
      if (pending.isEmpty) {
        _syncHasError = false;
        _syncMessage = 'Semua catatan sudah tersinkron dengan Firestore.';
        return;
      }

      final idToken = await _authService.getIdToken();
      var syncedCount = 0;

      for (final tx in pending) {
        await _firestoreService.backupTransaction(
          uid: user.uid,
          transaction: tx,
          idToken: idToken,
        );
        await _dbHelper.markAsSynced(tx.id);
        syncedCount++;
      }

      _transactions = await _dbHelper.getTransactions();
      _syncHasError = false;
      _syncMessage = '$syncedCount catatan berhasil dicadangkan ke Firestore.';
    } on FirestoreBackupException catch (e) {
      _syncHasError = true;
      _syncMessage = e.message;
    } catch (e) {
      debugPrint('Gagal sinkronisasi Firestore: $e');
      _syncHasError = true;
      _syncMessage =
          'Sinkronisasi gagal. Catatan tetap tersimpan aman secara lokal.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> fetchExchangeRate() async {
    _isLoadingRate = true;
    _rateError = null;
    notifyListeners();

    try {
      final result = await _currencyService.fetchUsdToIdrRate();
      _exchangeRate = result;
      _rateError = result.warningMessage;
    } on CurrencyApiException catch (e) {
      _rateError = e.message;
    } catch (e) {
      debugPrint('Gagal mengambil kurs: $e');
      _rateError = 'Gagal mengambil kurs USD/IDR.';
    } finally {
      _isLoadingRate = false;
      notifyListeners();
    }
  }

  void setFilterType(TransactionFilterType filter) {
    if (_filterType == filter) return;
    _filterType = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _filterType = TransactionFilterType.all;
    _searchQuery = '';
    notifyListeners();
  }

  void clearSyncMessage() {
    if (_syncMessage != null) {
      _syncMessage = null;
      _syncHasError = false;
      notifyListeners();
    }
  }
}
