import 'package:intl/intl.dart';

import '../models/transaction_model.dart';

/// Utilitas pemformatan Rupiah, USD, dan tanggal berbahasa Indonesia.
class FinoraFormatters {
  static final NumberFormat _idrNumberFormat = NumberFormat.decimalPattern(
    'id_ID',
  );
  static final NumberFormat _usdNumberFormat = NumberFormat(
    '#,##0.00',
    'en_US',
  );

  static const List<String> _monthShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static String formatIdr(
    double amount, {
    bool showSign = false,
    TransactionType? type,
  }) {
    final absRounded = amount.abs().round();
    final formatted = _idrNumberFormat.format(absRounded);

    if (type != null) {
      final prefix = type == TransactionType.income ? '+' : '-';
      return '${prefix}Rp $formatted';
    }
    if (showSign && amount > 0) {
      return '+Rp $formatted';
    }
    if (amount < 0) {
      return '-Rp $formatted';
    }
    return 'Rp $formatted';
  }

  static String formatUsd(double amount) {
    final prefix = amount < 0 ? '-' : '';
    return '$prefix\$${_usdNumberFormat.format(amount.abs())}';
  }

  static String formatDateHeader(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(target).inDays;

    if (diffDays == 0) return 'Hari ini';
    if (diffDays == 1) return 'Kemarin';
    return '${date.day} ${_monthShort[date.month - 1]} ${date.year}';
  }

  static String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatDateTimeShort(DateTime date) {
    return '${date.day} ${_monthShort[date.month - 1]} ${date.year}, ${formatTime(date)}';
  }
}
