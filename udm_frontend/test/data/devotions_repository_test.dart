import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/data/repositories/devotions_repository.dart';

import '../support/fakes.dart';

void main() {
  late FakeUdmApi api;
  late LocalCache cache;
  late int serverVersion;

  DevotionsRepository build({String Function()? languageCode}) {
    serverVersion = 12;
    return DevotionsRepository(
      api,
      cache,
      languageCode: languageCode,
      contentVersion: () => serverVersion,
    );
  }

  setUp(() async {
    api = FakeUdmApi()..seriesRows = sampleSeriesGrid();
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache(await SharedPreferences.getInstance());
  });

  test('a fetched grid is saved with the version it was taken under', () async {
    final rows = await build().grid();

    expect(rows, hasLength(2));
    expect(rows.first.contentVersion, 12);
    expect(rows.first.fromCache, isFalse);
    expect(rows.first.cachedAt, isNotNull);

    final stored = cache.readJson(DevotionsRepository.gridKey);
    expect(stored, isNotNull);
    expect((stored!['series'] as List).cast<Map<String, dynamic>>().first['content_version'], 12);
  });

  test('a payload that dates its own copy is saved with that number', () async {
    // The locally known version can already be newer than rows that are on
    // their way, so the number the server sent with the content wins.
    api.seriesRows = [
      sampleSeriesGrid().first.withCacheStamp(DateTime.utc(2026, 11, 10), version: 23),
    ];

    final rows = await build().grid();

    expect(rows.single.contentVersion, 23);
    expect(cache.readJson(DevotionsRepository.gridKey), isNotNull);
    expect(
      (cache.readJson(DevotionsRepository.gridKey)!['series'] as List)
          .cast<Map<String, dynamic>>()
          .single['content_version'],
      23,
    );
  });

  test('an offline read returns the saved copy, still stamped', () async {
    final repository = build();
    await repository.grid();

    serverVersion = 15;
    api
      ..failure = const Failure(FailureKind.offline, 'No connection')
      ..seriesRows = const [];

    final rows = await repository.grid();

    expect(rows.first.fromCache, isTrue);
    // The stamp of the copy on the device, not of the version the server is on
    // now: that difference is what makes the next online load refetch.
    expect(rows.first.contentVersion, 12);
  });

  test('with nothing saved the failure reaches the caller', () async {
    api.failure = const Failure(FailureKind.serverUnavailable, 'The service is down');

    await expectLater(build().grid(), throwsA(isA<Failure>()));
  });

  test('a series detail is cached per series', () async {
    api.seriesDetail = sampleSeriesDetail();
    final repository = build();

    final fresh = await repository.series('s1');
    expect(fresh.days, hasLength(3));
    expect(fresh.contentVersion, 12);
    expect(cache.readJson('${DevotionsRepository.seriesKey}.s1'), isNotNull);
    expect(cache.readJson('${DevotionsRepository.seriesKey}.s2'), isNull);

    final stored = repository.cachedSeries('s1');
    expect(stored?.fromCache, isTrue);
    expect(stored?.days, hasLength(3));
    expect(repository.cachedSeries('s2'), isNull);
  });

  test('the French copy is saved separately from the English copy', () async {
    await DevotionsRepository(
      api,
      cache,
      languageCode: () => 'fr',
      contentVersion: () => 4,
    ).grid();

    expect(cache.readJson('${DevotionsRepository.gridKey}.fr'), isNotNull);
    expect(cache.readJson(DevotionsRepository.gridKey), isNull);

    final rows = DevotionsRepository(api, cache).cachedGrid();
    expect(rows, isNull);
  });

  test('cached rows come back labelled as this device copy', () async {
    final repository = build();
    await repository.grid();

    final rows = repository.cachedGrid();

    expect(rows, isNotNull);
    expect(rows!.first.title, 'The Book of James');
    expect(rows.first.fromCache, isTrue);
    expect(rows.first.days, isEmpty);
  });
}
