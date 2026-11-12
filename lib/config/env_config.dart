import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pembaca konfigurasi lokal dari file asset `.env`.
class EnvConfig {
  EnvConfig._();

  static const String _envAssetPath = '.env';
  static Map<String, String> _values = const {};

  static String get exchangeRateApiKey => get('EXCHANGE_RATE_API_KEY');

  static String get(String key) => _values[key]?.trim() ?? '';

  /// Memuat isi `.env` yang terdaftar pada `pubspec.yaml` assets.
  static Future<void> load({AssetBundle? bundle}) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(_envAssetPath);
      _values = parse(raw);
    } catch (e) {
      debugPrint(
        'File .env tidak dapat dimuat ($e); memakai fallback default.',
      );
      _values = const {};
    }
  }

  /// Mem-parsing teks format `.env` (`KEY=VALUE`, komentar `#`, kutipan).
  @visibleForTesting
  static Map<String, String> parse(String content) {
    final parsed = <String, String>{};
    for (final rawLine in content.split('\n')) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('export ')) {
        line = line.substring(7).trim();
      }

      final separatorIndex = line.indexOf('=');
      if (separatorIndex <= 0) continue;

      final key = line.substring(0, separatorIndex).trim();
      var value = line.substring(separatorIndex + 1).trim();

      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      parsed[key] = value;
    }
    return Map.unmodifiable(parsed);
  }

  @visibleForTesting
  static void setValuesForTesting(Map<String, String> values) {
    _values = Map.unmodifiable(values);
  }

  @visibleForTesting
  static void resetForTesting() {
    _values = const {};
  }
}
