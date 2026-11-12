import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/data/repositories/resources_repository.dart';

import '../support/fakes.dart';

void main() {
  late FakeUdmApi api;
  late LocalCache cache;
  late int serverVersion;

  ResourcesRepository build({String Function()? languageCode}) {
    serverVersion = 12;
    return ResourcesRepository(
      api,
      cache,
      languageCode: languageCode,
      contentVersion: () => serverVersion,
    );
  }

  setUp(() async {
    api = FakeUdmApi()..resourceTopicRows = sampleResourceTopics();
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache(await SharedPreferences.getInstance());
  });

  test('the list is saved with the version it was taken under', () async {
    final rows = await build().topics();

    expect(rows, hasLength(3));
    expect(rows.first.contentVersion, 12);
    expect(rows.first.fromCache, isFalse);
    expect(cache.readJson(ResourcesRepository.topicsKey), isNotNull);
    expect(
      (cache.readJson(ResourcesRepository.topicsKey)!['topics'] as List)
          .cast<Map<String, dynamic>>()
          .first['content_version'],
      12,
    );
  });

  test('a guide that dates its own copy is saved with that number', () async {
    // The locally known version can already be newer than rows on their way,
    // so the number the server sent with the content wins.
    api.resourceTopicRows = [
      sampleResourceTopics().first.withCacheStamp(DateTime.utc(2026, 11, 10), version: 23),
    ];

    final rows = await build().topics();

    expect(rows.single.contentVersion, 23);
  });

  test('an offline read returns the saved list, still stamped', () async {
    final repository = build();
    await repository.topics();

    serverVersion = 15;
    api
      ..failure = const Failure(FailureKind.offline, 'No connection')
      ..resourceTopicRows = const [];

    final rows = await repository.topics();

    expect(rows.first.fromCache, isTrue);
    // The stamp of the copy on the device, not the version the server is on
    // now: that difference is what makes the next online load refetch.
    expect(rows.first.contentVersion, 12);
  });

  test('with nothing saved the failure reaches the caller', () async {
    api.failure = const Failure(FailureKind.serverUnavailable, 'The service is down');

    await expectLater(build().topics(), throwsA(isA<Failure>()));
  });

  test('a guide with its steps is cached per guide', () async {
    api.resourceTopicRow = sampleResourceTopic();
    final repository = build();

    final fresh = await repository.topic('r1');
    expect(fresh.steps, hasLength(4));
    expect(fresh.contentVersion, 9);
    expect(cache.readJson('${ResourcesRepository.topicKey}.r1'), isNotNull);
    expect(cache.readJson('${ResourcesRepository.topicKey}.r2'), isNull);

    final stored = repository.cachedTopic('r1');
    expect(stored?.fromCache, isTrue);
    expect(stored?.steps, hasLength(4));
    expect(repository.cachedTopic('r2'), isNull);
  });

  test('a guide read offline comes back as the saved copy', () async {
    api.resourceTopicRow = sampleResourceTopic();
    final repository = build();
    await repository.topic('r1');

    api
      ..failure = const Failure(FailureKind.offline, 'No connection')
      ..resourceTopicRow = null;

    final stored = await repository.topic('r1');

    expect(stored.fromCache, isTrue);
    expect(stored.title, 'Receive Christ');
    expect(stored.steps, hasLength(4));
  });

  test('the French copy is saved separately from the English copy', () async {
    await ResourcesRepository(api, cache, languageCode: () => 'fr', contentVersion: () => 4).topics();

    expect(cache.readJson('${ResourcesRepository.topicsKey}.fr'), isNotNull);
    expect(cache.readJson(ResourcesRepository.topicsKey), isNull);

    expect(ResourcesRepository(api, cache).cachedTopics(), isNull);
  });

  test('cached rows come back labelled as this device copy', () async {
    final repository = build();
    await repository.topics();

    final rows = repository.cachedTopics();

    expect(rows, isNotNull);
    expect(rows!.first.title, 'Receive Christ');
    expect(rows.first.fromCache, isTrue);
    // The list never carries the steps, so neither does its saved copy.
    expect(rows.first.steps, isEmpty);
  });
}
