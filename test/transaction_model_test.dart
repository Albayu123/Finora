import 'package:flutter_test/flutter_test.dart';

import 'package:finora_app/models/transaction_model.dart';

void main() {
  group('TransactionModel', () {
    test('serialisasi toMap dan fromMap mempertahankan seluruh field', () {
      final createdAt = DateTime(2026, 11, 12, 10, 30);
      final model = TransactionModel(
        id: 'uuid-1234',
        title: 'Makan siang',
        amount: 35000,
        type: TransactionType.expense,
        category: 'Makan & Minum',
        note: 'Kantin kampus',
        createdAt: createdAt,
        isSynced: false,
      );

      final map = model.toMap();
      expect(map['id'], 'uuid-1234');
      expect(map['is_synced'], 0);
      expect(map['created_at'], createdAt.toIso8601String());
      expect(map['type'], 'expense');

      final restored = TransactionModel.fromMap(map);
      expect(restored.id, model.id);
      expect(restored.title, model.title);
      expect(restored.amount, model.amount);
      expect(restored.type, TransactionType.expense);
      expect(restored.category, model.category);
      expect(restored.note, model.note);
      expect(restored.createdAt, createdAt);
      expect(restored.isSynced, isFalse);
    });

    test('toFirestoreMap menandai is_synced true dan mempertahankan id', () {
      final model = TransactionModel(
        id: 'uuid-5678',
        title: 'Uang saku',
        amount: 500000,
        type: TransactionType.income,
        category: 'Uang Saku',
        createdAt: DateTime(2026, 11, 12, 8, 0),
        isSynced: false,
      );

      final firestoreMap = model.toFirestoreMap();
      expect(firestoreMap['id'], 'uuid-5678');
      expect(firestoreMap['type'], 'income');
      expect(firestoreMap['is_synced'], isTrue);
    });
  });
}
