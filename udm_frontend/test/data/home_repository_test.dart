import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/data/repositories/home_repository.dart';

import '../support/fakes.dart';

void main() {
  late FakeUdmApi api;
  late LocalCache cache;
  late HomeRepository repository;

  setUp(() async {
    api = FakeUdmApi()..homePayload = sampleHome();
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache(await SharedPreferences.getInstance());
    repository = HomeRepository(api, cache);
  });

  test('a successful load is written to the device cache', () async {
    final payload = await repository.load();

    expect(payload.fromCache, isFalse);
    expect(payload.cachedAt, isNotNull);

    final stored = cache.readJson(HomeRepository.cacheKey);
    expect(stored, isNotNull);
    expect(stored!['greeting'], 'Good morning, Grace');
  });

  test('an offline read falls back to the last downloaded payload', () async {
    await repository.load();
    api.failure = const Failure(FailureKind.offline, 'No connection');

    final payload = await repository.load();

    expect(payload.fromCache, isTrue);
    expect(payload.devotion?.title, 'A Heart That Listens');
    expect(api.homeCalls, 2);
  });

  test('with nothing cached the failure reaches the caller', () async {
    api
      ..homePayload = null
      ..failure = const Failure(FailureKind.serverUnavailable, 'The service is down');

    expect(repository.load(), throwsA(isA<Failure>()));
  });

  test('non-JSON in the cache key is dropped, not thrown', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(HomeRepository.cacheKey, 'this is not json');

    expect(cache.readJson(HomeRepository.cacheKey), isNull);
    expect(prefs.getString(HomeRepository.cacheKey), isNull);
  });
}
