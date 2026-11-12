import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/data/repositories/media_repository.dart';

import '../support/fakes.dart';

/// What the Learn tab keeps on the device, and what it refuses to: the
/// ministry's shelves and recordings are cached so a student out of data can
/// still read them, while a note and a place in a recording live only on the
/// server, because whoever holds the phone is not necessarily whoever wrote it.
void main() {
  late FakeUdmApi api;
  late LocalCache cache;
  late int serverVersion;

  MediaRepository build({String Function()? languageCode}) {
    serverVersion = 31;
    return MediaRepository(
      api,
      cache,
      languageCode: languageCode,
      contentVersion: () => serverVersion,
    );
  }

  setUp(() async {
    api = FakeUdmApi()
      ..mediaShelves = sampleMediaShelves()
      ..mediaShelfRow = sampleMediaShelves().first
      ..mediaItemRow = sampleRecording();
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache(await SharedPreferences.getInstance());
  });

  test('the shelves are saved with the version they were taken under', () async {
    final shelves = await build().shelves();

    expect(shelves, hasLength(2));
    expect(shelves.first.title, 'SOMA');
    expect(shelves.first.contentVersion, 31);
    expect(shelves.first.fromCache, isFalse);
    expect(shelves.first.cachedAt, isNotNull);

    final stored = cache.readJson(MediaRepository.shelvesKey);
    expect(stored, isNotNull);
    final rows = (stored!['shelves'] as List).cast<Map<String, dynamic>>();
    expect(rows, hasLength(2));
    expect(rows.first['title'], 'SOMA');
    expect(rows.first['content_version'], 31);
  });

  test('a payload that dates its own copy is saved with that number', () async {
    // The version the app knows can already be newer than rows on their way,
    // so the number the server sent beside the content wins.
    api.mediaShelves = [
      sampleMediaShelves().first.withCacheStamp(DateTime.utc(2026, 11, 11), version: 44),
    ];

    final shelves = await build().shelves();

    expect(shelves.single.contentVersion, 44);
    final stored = cache.readJson(MediaRepository.shelvesKey)!['shelves'] as List;
    expect((stored.cast<Map<String, dynamic>>()).single['content_version'], 44);
  });

  test('an offline read returns the saved shelves, still stamped', () async {
    final repository = build();
    await repository.shelves();

    serverVersion = 35;
    api
      ..mediaFailure = const Failure(FailureKind.offline, 'No connection')
      ..mediaShelves = const [];

    final shelves = await repository.shelves();

    expect(shelves.first.fromCache, isTrue);
    // The stamp of the copy on the device, not the version the server is on
    // now: that difference is what makes the next online load refetch.
    expect(shelves.first.contentVersion, 31);
    expect(shelves.last.title, 'Podcast');
  });

  test('with nothing saved the failure reaches the caller', () async {
    api.mediaFailure = const Failure(FailureKind.serverUnavailable, 'The service is down');

    await expectLater(build().shelves(), throwsA(isA<Failure>()));
  });

  test('a shelf is saved under its own id', () async {
    final repository = build();

    final fresh = await repository.shelf('c1');
    expect(fresh.items, hasLength(1));
    expect(fresh.contentVersion, 31);
    expect(cache.readJson('${MediaRepository.shelfKey}.c1'), isNotNull);
    expect(cache.readJson('${MediaRepository.shelfKey}.c2'), isNull);

    final stored = repository.cachedShelf('c1');
    expect(stored?.fromCache, isTrue);
    expect(stored?.items.single.title, 'True faith sides with God | Hebrews 11:29-31');
    expect(repository.cachedShelf('c2'), isNull);
  });

  test('a shelf offline comes back from its own saved copy', () async {
    final repository = build();
    await repository.shelf('c1');

    api.mediaFailure = const Failure(FailureKind.offline, 'No connection');

    final stored = await repository.shelf('c1');
    expect(stored.fromCache, isTrue);
    expect(stored.title, 'SOMA');
  });

  test('a recording is saved as the public copy only', () async {
    api.mediaItemRow = sampleRecording(
      note: 'Faith sides before it understands why.',
      resumeAt: 180,
      watched: true,
    );

    final fresh = await build().item('m1');
    expect(fresh.note, 'Faith sides before it understands why.');
    expect(fresh.resumeAt, 180);

    final stored = cache.readJson('${MediaRepository.itemKey}.m1')!;
    expect(stored.containsKey('note'), isFalse);
    expect(stored.containsKey('watch'), isFalse);
    expect(stored.containsKey('watched'), isFalse);

    // The next student to open the app out of data reads the ministry's
    // write-up, and nothing about the student before them.
    final cached = build().cachedItem('m1');
    expect(cached?.title, fresh.title);
    expect(cached?.body, fresh.body);
    expect(cached?.fromCache, isTrue);
    expect(cached?.note, isEmpty);
    expect(cached?.resumeAt, isNull);
    expect(cached?.watched, isFalse);
  });

  test('a note goes to the server and the answer comes straight back', () async {
    final repository = build();

    final saved = await repository.saveNote('m1', 'He listened before he understood.');

    expect(api.mediaNotes.single.id, 'm1');
    expect(api.mediaNotes.single.text, 'He listened before he understood.');
    expect(saved.text, 'He listened before he understood.');
    expect(saved.updatedAt, DateTime.utc(2026, 11, 12, 15));
    expect(cache.readJson('${MediaRepository.itemKey}.m1'), isNull);
  });

  test('blanking the field asks the server to delete the note', () async {
    final saved = await build().saveNote('m1', '');

    expect(api.mediaNotes.single.text, '');
    expect(saved.text, isEmpty);
    // Nothing to date: the row is gone.
    expect(saved.updatedAt, isNull);
  });

  test('a private write is not papered over with the cache', () async {
    // An offline student cannot leave a note: there is no local place for one,
    // and inventing a saved state would tell them something untrue.
    await build().item('m1');
    api.mediaFailure = const Failure(FailureKind.offline, 'No connection');
    final repository = build();

    await expectLater(
      repository.saveNote('m1', 'Anything at all'),
      throwsA(isA<Failure>()),
    );
    await expectLater(
      repository.saveWatch('m1', positionSeconds: 60, completed: false),
      throwsA(isA<Failure>()),
    );
    expect(api.mediaNotes, isEmpty);
    expect(api.mediaWatches, isEmpty);
  });

  test('a place in a recording is stored as the server states it', () async {
    final saved = await build().saveWatch(
      'm1',
      positionSeconds: 420,
      completed: false,
    );

    expect(api.mediaWatches.single.positionSeconds, 420);
    expect(saved.positionSeconds, 420);
    expect(saved.completed, isFalse);
  });

  test('the French shelves are saved separately from the English ones', () async {
    await build(languageCode: () => 'fr').shelves();

    expect(cache.readJson('${MediaRepository.shelvesKey}.fr'), isNotNull);
    expect(cache.readJson(MediaRepository.shelvesKey), isNull);
    expect(build().cachedShelves(), isNull);
  });

  test('cached shelves come back labelled as this device copy', () async {
    final repository = build();
    await repository.shelves();

    final shelves = repository.cachedShelves();

    expect(shelves, isNotNull);
    expect(shelves!.first.title, 'SOMA');
    expect(shelves.first.fromCache, isTrue);
    expect(shelves.last.itemCount, 1);
  });
}
