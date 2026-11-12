import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/models/media_collection.dart';
import 'package:udm_frontend/app/data/repositories/media_repository.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/media/learn_controller.dart';
import 'package:udm_frontend/app/modules/media/learn_view.dart';
import 'package:udm_frontend/app/modules/media/media_collection_binding.dart';
import 'package:udm_frontend/app/modules/media/media_collection_view.dart';

import '../support/fakes.dart';

/// The Learn tab as the pictures described it: the ministry's shelves on the
/// first screen, then the recordings on one shelf, in the order and under the
/// names the staff wrote in the console.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  /// The whole Learn feature behind one harness: the repository is registered
  /// under the real type, which is what every media screen and binding looks
  /// up, and `home` decides whether the test starts on the tab or on a shelf.
  Future<FakeMediaRepository> pumpMedia(
    WidgetTester tester, {
    required Widget home,
    void Function()? register,
    List<MediaCollection> rows = const [],
    List<MediaCollection>? cachedRows,
    MediaCollection? shelfRow,
    Failure? failure,
  }) async {
    final repository = FakeMediaRepository(
      shelfRows: rows,
      cachedShelfRows: cachedRows,
      shelfRow: shelfRow,
      failure: failure,
    );
    Get.put<MediaRepository>(repository, permanent: true);
    Get.put<ContentVersionController>(FakeContentVersionController(), permanent: true);
    register?.call();
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(
            name: AppRoutes.mediaCollection,
            page: () => const MediaCollectionView(),
            binding: MediaCollectionBinding(),
          ),
          GetPage(
            name: AppRoutes.mediaItem,
            page: () => const Center(child: Text('RECORDING SCREEN')),
          ),
        ],
        home: home,
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Future<FakeMediaRepository> pumpLearn(
    WidgetTester tester, {
    List<MediaCollection> rows = const [],
    List<MediaCollection>? cachedRows,
    MediaCollection? shelfRow,
    Failure? failure,
  }) {
    return pumpMedia(
      tester,
      home: const Scaffold(body: LearnView()),
      // The type is written out: GetX keys an instance by the type argument,
      // and this closure's void context would infer a different one.
      register: () {
        Get.put<LearnController>(LearnController(Get.find<MediaRepository>()));
      },
      rows: rows,
      cachedRows: cachedRows,
      shelfRow: shelfRow,
      failure: failure,
    );
  }

  /// Opens one shelf the way the tab does: a named route carrying its id, so
  /// the binding is the one that reads it.
  Future<FakeMediaRepository> pumpShelf(
    WidgetTester tester, {
    MediaCollection? row,
    Failure? failure,
  }) async {
    final repository = await pumpMedia(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Get.toNamed(
                AppRoutes.mediaCollection,
                arguments: {RouteArgs.mediaCollectionId: 'c1'},
              ),
              child: const Text('OPEN SHELF'),
            ),
          ),
        ),
      ),
      shelfRow: row,
      failure: failure,
    );
    await tester.tap(find.text('OPEN SHELF'));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('the tab shows the ministry\'s shelves with what each one holds', (tester) async {
    final repository = await pumpLearn(tester, rows: sampleMediaShelves());

    expect(find.text('WATCH AND LISTEN'), findsOneWidget);
    expect(find.text('SOMA'), findsOneWidget);
    expect(find.text('Study, Observe, Meditate, and Apply the Scriptures.'), findsOneWidget);
    expect(find.text('2 recordings'), findsOneWidget);
    expect(find.text('Podcast'), findsOneWidget);
    // One recording reads as one recording.
    expect(find.text('1 recording'), findsOneWidget);
    expect(find.text('Offline copy'), findsNothing);
    expect(repository.shelvesCalls, 1);
  });

  testWidgets('shelf art that will not load leaves the name, not a broken box', (tester) async {
    await pumpLearn(tester, rows: sampleMediaShelves());

    // SOMA has art on the ministry's host and Podcast has none at all; neither
    // row is allowed to show a hole.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('P'), findsOneWidget);
  });

  testWidgets('tapping a shelf really opens that shelf', (tester) async {
    await pumpLearn(
      tester,
      rows: sampleMediaShelves(),
      shelfRow: sampleMediaShelves().first,
    );

    await tester.tap(find.text('SOMA'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.mediaCollection);
    expect(find.byType(MediaCollectionView), findsOneWidget);
    expect(find.text('True faith sides with God | Hebrews 11:29-31'), findsOneWidget);
  });

  testWidgets('an empty library says so instead of showing a blank tab', (tester) async {
    await pumpLearn(tester);

    expect(find.text('No recordings published yet'), findsOneWidget);
    expect(
      find.text(
        'When the ministry team puts a teaching recording on a shelf it appears here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a saved library keeps the tab readable offline and says so', (tester) async {
    final saved = sampleMediaShelves()
        .map((shelf) => shelf.withCacheStamp(DateTime.utc(2026, 11, 9), version: 4))
        .map((shelf) => shelf.asCached())
        .toList();

    final repository = await pumpLearn(
      tester,
      cachedRows: saved,
      failure: const Failure(FailureKind.offline, 'No connection to the UDM service.'),
    );

    expect(find.text('SOMA'), findsOneWidget);
    expect(find.text('Offline copy'), findsOneWidget);
    expect(
      find.text('Saved on this device. Pull to refresh when you are online.'),
      findsOneWidget,
    );
    // The failure is not shown as an error over shelves that read fine.
    expect(find.text('We could not load this'), findsNothing);
    expect(repository.shelvesCalls, 1);
  });

  testWidgets('a first load that fails offers a working retry', (tester) async {
    final repository = await pumpLearn(
      tester,
      failure: const Failure(FailureKind.offline, 'No connection'),
    );

    expect(find.text('We could not load this'), findsOneWidget);

    repository
      ..failure = null
      ..shelfRows = sampleMediaShelves();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.shelvesCalls, 2);
    expect(find.text('SOMA'), findsOneWidget);
  });

  testWidgets('a ministry edit reloads the tab while it is open', (tester) async {
    final dated = sampleMediaShelves()
        .map((shelf) => shelf.withCacheStamp(DateTime.utc(2026, 11, 10), version: 4))
        .toList();
    final repository = await pumpLearn(tester, rows: dated);

    final versions = Get.find<ContentVersionController>() as FakeContentVersionController;
    repository.shelfRows = [
      const MediaCollection(
        id: 'c7',
        title: 'Uliza',
        order: 2,
        itemCount: 4,
        contentVersion: 9,
      ),
    ];
    versions.emit(9);
    await tester.pumpAndSettle();

    expect(repository.shelvesCalls, 2);
    expect(find.text('Uliza'), findsOneWidget);
    expect(find.text('Podcast'), findsNothing);
  });

  testWidgets('pull to refresh asks the server again', (tester) async {
    final repository = await pumpLearn(tester, rows: sampleMediaShelves());

    await tester.drag(find.byType(ListView), const Offset(0, 260));
    await tester.pumpAndSettle();

    expect(repository.shelvesCalls, greaterThan(1));
  });

  testWidgets('a shelf lists its recordings with the byline the ministry wrote', (tester) async {
    await pumpShelf(tester, row: sampleMediaShelves().first);

    expect(find.text('IN ORDER'), findsOneWidget);
    expect(find.textContaining('Edgar Karuma'), findsOneWidget);
    expect(find.text('15:40'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    // A mark is the server's promise, not the app's: a recording nobody has
    // started carries neither a watched nor a resume pill.
    expect(find.text('Watched'), findsNothing);
    expect(find.text('Resume 3:00'), findsNothing);
  });

  testWidgets('a row the student stopped partway through says where', (tester) async {
    await pumpShelf(
      tester,
      row: MediaCollection(
        id: 'c1',
        title: 'SOMA',
        order: 1,
        itemCount: 1,
        items: [sampleRecording(resumeAt: 180)],
      ),
    );

    expect(find.text('Resume 3:00'), findsOneWidget);
  });

  testWidgets('a recording the student finished is marked, not resumed', (tester) async {
    await pumpShelf(
      tester,
      row: MediaCollection(
        id: 'c1',
        title: 'SOMA',
        order: 1,
        itemCount: 1,
        items: [sampleRecording(watched: true, resumeAt: 180)],
      ),
    );

    expect(find.text('Watched'), findsOneWidget);
    expect(find.text('Resume 3:00'), findsNothing);
  });

  testWidgets('a recording the ministry distributes as a file is labelled a file', (tester) async {
    await pumpShelf(
      tester,
      row: MediaCollection(
        id: 'c1',
        title: 'SOMA',
        order: 1,
        itemCount: 1,
        items: [
          sampleRecording(
            youtubeVideoId: null,
            downloadUrl: 'https://files.udm.ac.ug/media/soma-01.mp3',
          ),
        ],
      ),
    );

    expect(find.text('File'), findsOneWidget);
    expect(find.text('Video'), findsNothing);
  });

  testWidgets('a row on the shelf really opens that recording', (tester) async {
    await pumpShelf(tester, row: sampleMediaShelves().first);

    await tester.tap(find.text('True faith sides with God | Hebrews 11:29-31'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.mediaItem);
    expect(find.text('RECORDING SCREEN'), findsOneWidget);
  });

  testWidgets('a shelf offline comes back from this device, labelled', (tester) async {
    await pumpShelf(
      tester,
      row: sampleMediaShelves().first.asCached(),
      failure: const Failure(FailureKind.offline, 'No connection to the UDM service.'),
    );

    expect(find.text('True faith sides with God | Hebrews 11:29-31'), findsOneWidget);
    expect(find.text('Offline copy of this shelf'), findsOneWidget);
    expect(find.text('We could not load this'), findsNothing);
  });

  testWidgets('a shelf that stopped being published says so', (tester) async {
    await pumpShelf(
      tester,
      failure: const Failure(FailureKind.notFound, 'We could not find that.'),
    );

    expect(find.text('Nothing released on this shelf yet'), findsOneWidget);
    expect(
      find.text('The ministry team has not published a recording here. Check back soon.'),
      findsOneWidget,
    );
  });
}
