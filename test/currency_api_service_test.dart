import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finora_app/config/env_config.dart';
import 'package:finora_app/services/currency_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvConfig.resetForTesting();
  });

  test(
    'fetchUsdToIdrRate mem-parsing kurs IDR dan menyimpannya ke cache',
    () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/v6/test-key/latest/USD'));
        return http.Response(
          jsonEncode({
            'result': 'success',
            'base_code': 'USD',
            'conversion_rates': {'USD': 1, 'IDR': 16250.5},
          }),
          200,
        );
      });

      final prefs = await SharedPreferences.getInstance();
      final service = CurrencyApiService(
        client: mockClient,
        preferences: prefs,
        apiKeyOverride: 'test-key',
      );

      final result = await service.fetchUsdToIdrRate();
      expect(result.usdToIdrRate, 16250.5);
      expect(result.isFromCache, isFalse);

      final cached = await service.getCachedRate();
      expect(cached, isNotNull);
      expect(cached!.usdToIdrRate, 16250.5);
      expect(cached.isFromCache, isTrue);
    },
  );

  test('fetchUsdToIdrRate fallback ke cache saat jaringan gagal', () async {
    SharedPreferences.setMockInitialValues({
      'cached_usd_to_idr_rate': 16000.0,
      'cached_usd_to_idr_updated_at': DateTime(
        2026,
        11,
        10,
        12,
        0,
      ).toIso8601String(),
    });
    final prefs = await SharedPreferences.getInstance();

    final failingClient = MockClient((_) async => throw Exception('Offline'));
    final service = CurrencyApiService(
      client: failingClient,
      preferences: prefs,
      apiKeyOverride: 'test-key',
    );

    final result = await service.fetchUsdToIdrRate();
    expect(result.usdToIdrRate, 16000.0);
    expect(result.isFromCache, isTrue);
    expect(result.warningMessage, isNotNull);
  });

  test(
    'fetchUsdToIdrRate melempar CurrencyApiException jika key kosong dan tanpa cache',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final service = CurrencyApiService(
        client: MockClient((_) async => http.Response('{}', 200)),
        preferences: prefs,
        apiKeyOverride: '',
      );

      expect(
        () => service.fetchUsdToIdrRate(),
        throwsA(isA<CurrencyApiException>()),
      );
    },
  );

  test(
    'EnvConfig mem-parsing file .env dan CurrencyApiService memakainya otomatis',
    () async {
      final parsed = EnvConfig.parse('''
# Komentar konfigurasi
EXCHANGE_RATE_API_KEY="env-secret-123"
export EXTRA_KEY='ignored'
''');
      expect(parsed['EXCHANGE_RATE_API_KEY'], 'env-secret-123');
      expect(parsed['EXTRA_KEY'], 'ignored');

      EnvConfig.setValuesForTesting(parsed);
      final prefs = await SharedPreferences.getInstance();
      final service = CurrencyApiService(
        preferences: prefs,
        client: MockClient((request) async {
          expect(request.url.path, contains('/v6/env-secret-123/latest/USD'));
          return http.Response(
            jsonEncode({
              'result': 'success',
              'base_code': 'USD',
              'conversion_rates': {'USD': 1, 'IDR': 16500.0},
            }),
            200,
          );
        }),
      );

      final result = await service.fetchUsdToIdrRate();
      expect(result.usdToIdrRate, 16500.0);
    },
  );
}
