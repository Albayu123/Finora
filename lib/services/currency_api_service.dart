import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env_config.dart';

/// Hasil pengambilan kurs USD ke IDR beserta metadata cache.
class ExchangeRateResult {
  const ExchangeRateResult({
    required this.usdToIdrRate,
    required this.updatedAt,
    required this.isFromCache,
    this.warningMessage,
  });

  final double usdToIdrRate;
  final DateTime updatedAt;
  final bool isFromCache;
  final String? warningMessage;
}

class CurrencyApiException implements Exception {
  const CurrencyApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Klien ExchangeRate-API v6 dengan cache lokal untuk fallback offline.
class CurrencyApiService {
  CurrencyApiService({
    http.Client? client,
    this._preferences,
    this._apiKeyOverride,
  }) : _client = client ?? http.Client();

  static const String _envApiKey = String.fromEnvironment(
    'EXCHANGE_RATE_API_KEY',
  );
  static const String _cacheRateKey = 'cached_usd_to_idr_rate';
  static const String _cacheDateKey = 'cached_usd_to_idr_updated_at';

  final http.Client _client;
  final SharedPreferences? _preferences;
  final String? _apiKeyOverride;

  String get _apiKey {
    if (_apiKeyOverride != null) {
      return _apiKeyOverride.trim();
    }
    final envFileKey = EnvConfig.exchangeRateApiKey;
    if (envFileKey.isNotEmpty) {
      return envFileKey;
    }
    return _envApiKey.trim();
  }

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  /// Membaca kurs tersimpan terakhir dari penyimpanan lokal bila ada.
  Future<ExchangeRateResult?> getCachedRate() async {
    final prefs = await _prefs;
    final rate = prefs.getDouble(_cacheRateKey);
    final rawDate = prefs.getString(_cacheDateKey);
    if (rate == null || rate <= 0 || rawDate == null) {
      return null;
    }
    final parsedDate = DateTime.tryParse(rawDate);
    if (parsedDate == null) {
      return null;
    }
    return ExchangeRateResult(
      usdToIdrRate: rate,
      updatedAt: parsedDate,
      isFromCache: true,
    );
  }

  /// Mengambil kurs terbaru USD -> IDR; fallback ke cache bila offline atau gagal.
  Future<ExchangeRateResult> fetchUsdToIdrRate() async {
    final cached = await getCachedRate();
    if (_apiKey.isEmpty) {
      if (cached != null) {
        return ExchangeRateResult(
          usdToIdrRate: cached.usdToIdrRate,
          updatedAt: cached.updatedAt,
          isFromCache: true,
          warningMessage:
              'EXCHANGE_RATE_API_KEY belum disetel. Menampilkan kurs tersimpan terakhir.',
        );
      }
      throw const CurrencyApiException(
        'API key ExchangeRate-API belum diisi pada file .env atau --dart-define.',
      );
    }

    final uri = Uri.parse(
      'https://v6.exchangerate-api.com/v6/$_apiKey/latest/USD',
    );

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return _fallbackOrThrow(
          cached,
          'Gagal mengambil kurs (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _fallbackOrThrow(cached, 'Format respons kurs tidak valid.');
      }

      if (decoded['result'] != 'success') {
        final errorType = decoded['error-type']?.toString() ?? 'unknown';
        return _fallbackOrThrow(
          cached,
          'Layanan kurs menolak permintaan ($errorType).',
        );
      }

      final rates = decoded['conversion_rates'];
      if (rates is! Map<String, dynamic> || rates['IDR'] is! num) {
        return _fallbackOrThrow(
          cached,
          'Data kurs IDR tidak ditemukan pada respons API.',
        );
      }

      final idrRate = (rates['IDR'] as num).toDouble();
      if (idrRate <= 0) {
        return _fallbackOrThrow(cached, 'Nilai kurs IDR tidak valid.');
      }

      final now = DateTime.now();
      final prefs = await _prefs;
      await prefs.setDouble(_cacheRateKey, idrRate);
      await prefs.setString(_cacheDateKey, now.toIso8601String());

      return ExchangeRateResult(
        usdToIdrRate: idrRate,
        updatedAt: now,
        isFromCache: false,
      );
    } on CurrencyApiException {
      rethrow;
    } catch (_) {
      return _fallbackOrThrow(
        cached,
        'Tidak dapat terhubung ke server ExchangeRate-API.',
      );
    }
  }

  ExchangeRateResult _fallbackOrThrow(
    ExchangeRateResult? cached,
    String reason,
  ) {
    if (cached != null) {
      return ExchangeRateResult(
        usdToIdrRate: cached.usdToIdrRate,
        updatedAt: cached.updatedAt,
        isFromCache: true,
        warningMessage: '$reason Menampilkan kurs tersimpan terakhir.',
      );
    }
    throw CurrencyApiException(reason);
  }

  double idrToUsd(double idrAmount, double usdToIdrRate) {
    if (usdToIdrRate <= 0) return 0;
    return idrAmount / usdToIdrRate;
  }

  double usdToIdr(double usdAmount, double usdToIdrRate) {
    if (usdToIdrRate <= 0) return 0;
    return usdAmount * usdToIdrRate;
  }
}
