import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finora_app/models/transaction_model.dart';
import 'package:finora_app/services/database_helper.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper dbHelper;

  setUp(() {
    dbHelper = DatabaseHelper(
      factoryOverride: databaseFactoryFfi,
      dbPathOverride: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  test(
    'CRUD SQLite lokal dan perubahan status is_synced berjalan benar',
    () async {
      final tx1 = TransactionModel(
        id: 'id-1',
        title: 'Sarapan',
        amount: 15000,
        type: TransactionType.expense,
        category: 'Makan & Minum',
        createdAt: DateTime(2026, 11, 12, 7, 0),
        isSynced: false,
      );
      final tx2 = TransactionModel(
        id: 'id-2',
        title: 'Beasiswa',
        amount: 1500000,
        type: TransactionType.income,
        category: 'Uang Saku',
        createdAt: DateTime(2026, 11, 12, 9, 0),
        isSynced: false,
      );

      await dbHelper.insertTransaction(tx1);
      await dbHelper.insertTransaction(tx2);

      final list = await dbHelper.getTransactions();
      expect(list.length, 2);
      expect(list.first.id, 'id-2');

      final unsyncedBefore = await dbHelper.getUnsyncedTransactions();
      expect(unsyncedBefore.length, 2);

      await dbHelper.markAsSynced('id-1');
      final unsyncedAfter = await dbHelper.getUnsyncedTransactions();
      expect(unsyncedAfter.length, 1);
      expect(unsyncedAfter.first.id, 'id-2');

      await dbHelper.updateTransaction(
        tx1.copyWith(amount: 20000, isSynced: false),
      );
      final updatedList = await dbHelper.getTransactions();
      expect(updatedList.last.amount, 20000);
      expect(updatedList.last.isSynced, isFalse);

      await dbHelper.deleteTransaction('id-1');
      final remaining = await dbHelper.getTransactions();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'id-2');
    },
  );
}
