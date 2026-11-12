/// Jenis transaksi keuangan yang dicatat oleh pengguna.
enum TransactionType {
  income('income', 'Pemasukan'),
  expense('expense', 'Pengeluaran');

  const TransactionType(this.value, this.label);

  final String value;
  final String label;

  static TransactionType fromValue(String raw) {
    return TransactionType.values.firstWhere(
      (item) => item.value == raw,
      orElse: () => TransactionType.expense,
    );
  }
}

/// Kategori bawaan transaksi berdasarkan jenis arus kas.
class TransactionCategories {
  static const List<String> income = [
    'Gaji',
    'Uang Saku',
    'Bonus',
    'Freelance',
    'Lainnya',
  ];

  static const List<String> expense = [
    'Makan & Minum',
    'Transportasi',
    'Belanja',
    'Tagihan',
    'Pendidikan',
    'Hiburan',
    'Kesehatan',
    'Lainnya',
  ];

  static List<String> forType(TransactionType type) {
    return type == TransactionType.income ? income : expense;
  }
}

/// Model transaksi keuangan lokal dan cadangan Firestore.
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    this.note = '',
    required this.createdAt,
    this.isSynced = false,
  });

  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final String note;
  final DateTime createdAt;
  final bool isSynced;

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    String? note,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Konversi ke map kolom SQLite (`snake_case`).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.value,
      'category': category,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Pemetaan data dari baris SQLite maupun dokumen JSON.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final rawSynced = map['is_synced'];
    final synced = rawSynced is bool ? rawSynced : (rawSynced as num?) == 1;
    final rawDate = map['created_at'] as String?;

    return TransactionModel(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      amount: ((map['amount'] ?? 0) as num).toDouble(),
      type: TransactionType.fromValue((map['type'] ?? 'expense') as String),
      category: (map['category'] ?? 'Lainnya') as String,
      note: (map['note'] ?? '') as String,
      createdAt: rawDate != null
          ? DateTime.tryParse(rawDate) ?? DateTime.now()
          : DateTime.now(),
      isSynced: synced,
    );
  }

  /// Payload untuk dokumen cadangan di Cloud Firestore.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.value,
      'category': category,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'is_synced': true,
    };
  }
}
