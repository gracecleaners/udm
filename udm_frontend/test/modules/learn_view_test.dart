import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/models/media_collection.dart';
import 'package:udm_frontend/app/data/models/resume_item.dart';
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
    List<ResumeItem> resumeRows = const [],
    Failure? failure,
  }) async {
    final repository = FakeMediaRepository(
      shelfRows: rows,
      cachedShelfRows: cachedRows,
      shelfRow: shelfRow,
      failure: failure,
    )..resumeRows = resumeRows;
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
    List<ResumeItem> resumeRows = const [],
    bool signedIn = false,
    Failure? failure,
  }) {
    return pumpMedia(
      tester,
      home: const Scaffold(body: LearnView()),
      // The type is written out: GetX keys an instance by the type argument,
      // and this closure's void context would infer a different one.
      register: () {
        Get.put<LearnController>(
          LearnController(Get.find<MediaRepository>(), fakeSession(signedIn: signedIn)),
        );
      },
      rows: rows,
      cachedRows: cachedRows,
      shelfRow: shelfRow,
      resumeRows: resumeRows,
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

  /// The tab is a scroll view and the test window is short, so a shelf in the
  /// second grid row is either not built yet or built below the fold where a
  /// tap cannot land. Drag until the row sits inside the viewport.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    final viewport = tester.getRect(find.byType(CustomScrollView));
    for (var attempt = 0; attempt < 8; attempt++) {
      if (finder.evaluate().isNotEmpty && tester.getRect(finder.first).bottom <= viewport.bottom) {
        return;
      }
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -220));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the tab opens on the heading and the teaching it carries', (tester) async {
    final repository = await pumpLearn(tester, rows: sampleMediaShelves());

    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Grow in God’s Word'), findsOneWidget);
    // The teaching the ministry puts first is its own card under the heading,
    // and it is also a shelf on the grid, so its name is on the screen twice.
    expect(find.text('Featured Teaching'), findsOneWidget);
    expect(find.text('Watch Now'), findsOneWidget);
    expect(find.text('SOMA'), findsWidgets);
    expect(find.text('Study, Observe, Meditate, and Apply the Scriptures.'), findsWidgets);
    expect(find.text('2 Lessons'), findsOneWidget);
    expect(find.text('Podcast'), findsOneWidget);
    // One recording reads as one recording.
    expect(find.text('1 Lesson'), findsOneWidget);
    expect(find.text('Offline copy'), findsNothing);
    expect(repository.shelvesCalls, 1);
  });

  testWidgets('Watch Now opens the featured shelf\'s first recording', (tester) async {
    await pumpLearn(tester, rows: sampleMediaShelves());

    await tester.tap(find.text('Watch Now'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.mediaItem);
    expect(find.text('RECORDING SCREEN'), findsOneWidget);
  });

  testWidgets('shelf art that will not load leaves the name, not a broken box', (tester) async {
    await pumpLearn(tester, rows: sampleMediaShelves());

    // SOMA has art on the ministry's host and Podcast has none at all; neither
    // tile is allowed to show a hole, so each answers with its own letter.
    expect(find.text('S'), findsWidgets);
    await scrollTo(tester, find.text('P'));
    expect(find.text('P'), findsWidgets);
  });

  testWidgets('tapping a shelf really opens that shelf', (tester) async {
    await pumpLearn(tester, rows: sampleMediaShelves(), shelfRow: sampleMediaShelves().first);

    // Podcast is only ever a grid tile: SOMA is also the featured shelf in the
    // heading, where tapping it opens a recording instead of the shelf.
    await scrollTo(tester, find.text('Podcast'));
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.mediaCollection);
    expect(find.byType(MediaCollectionView), findsOneWidget);
    expect(find.text('True faith sides with God | Hebrews 11:29-31'), findsOneWidget);
  });

  testWidgets('an empty library says so instead of showing a blank tab', (tester) async {
    await pumpLearn(tester);

    expect(find.text('No recordings published yet'), findsOneWidget);
    expect(
      find.text('When the ministry team publishes a teaching series, it will appear here.'),
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

    expect(find.text('SOMA'), findsWidgets);
    expect(find.text('Offline copy'), findsOneWidget);
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
    // SOMA is both the teaching the heading carries and a shelf of its own.
    expect(find.text('SOMA'), findsWidgets);
  });

  testWidgets('a ministry edit reloads the tab while it is open', (tester) async {
    final dated = sampleMediaShelves()
        .map((shelf) => shelf.withCacheStamp(DateTime.utc(2026, 11, 10), version: 4))
        .toList();
    final repository = await pumpLearn(tester, rows: dated);

    final versions = Get.find<ContentVersionController>() as FakeContentVersionController;
    repository.shelfRows = [
      const MediaCollection(id: 'c7', title: 'Uliza', order: 2, itemCount: 4, contentVersion: 9),
    ];
    versions.emit(9);
    await tester.pumpAndSettle();

    expect(repository.shelvesCalls, 2);
    // Uliza is both the shelf the grid lists and the one the heading features.
    expect(find.text('Uliza'), findsWidgets);
    expect(find.text('Podcast'), findsNothing);
  });

  testWidgets('pull to refresh asks the server again', (tester) async {
    final repository = await pumpLearn(tester, rows: sampleMediaShelves());

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 260));
    await tester.pumpAndSettle();

    expect(repository.shelvesCalls, greaterThan(1));
  });

  testWidgets('a signed-in student picks up the recording they stopped', (tester) async {
    final repository = await pumpLearn(
      tester,
      rows: sampleMediaShelves(),
      signedIn: true,
      resumeRows: const [
        ResumeItem(
          id: 'm1',
          title: 'True faith sides with God | Hebrews 11:29-31',
          durationSeconds: 940,
          positionSeconds: 640,
          collectionTitle: 'SOMA',
        ),
      ],
    );

    expect(find.text('Continue Watching'), findsOneWidget);
    expect(find.text('True faith sides with God | Hebrews 11:29-31'), findsOneWidget);
    expect(find.text('Series: SOMA'), findsOneWidget);
    // The heading carries its door whether the student has one place to return
    // to or several, and Browse Series has the same words further down the tab.
    final door = find.descendant(
      of: find.ancestor(of: find.text('Continue Watching'), matching: find.byType(Row)).first,
      matching: find.text('See All'),
    );
    expect(door, findsOneWidget);
    expect(repository.resumeCalls, 1);

    await tester.tap(find.text('True faith sides with God | Hebrews 11:29-31').first);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.mediaItem);
    expect(find.text('RECORDING SCREEN'), findsOneWidget);
  });

  testWidgets('the two newest places are on the tab, the rest are one tap away', (tester) async {
    await pumpLearn(
      tester,
      rows: sampleMediaShelves(),
      signedIn: true,
      resumeRows: const [
        ResumeItem(
          id: 'm1',
          title: 'True faith sides with God | Hebrews 11:29-31',
          durationSeconds: 940,
          positionSeconds: 640,
          collectionTitle: 'SOMA',
        ),
        ResumeItem(
          id: 'm2',
          title: 'Why the law was not enough',
          durationSeconds: 1200,
          positionSeconds: 300,
          collectionTitle: 'SOMA',
        ),
        ResumeItem(
          id: 'm3',
          title: 'Prayer the church cannot outpray',
          durationSeconds: 1500,
          positionSeconds: 300,
          collectionTitle: 'Uliza',
        ),
      ],
    );

    // The tab carries the two places the server put first; a third waits in the
    // sheet rather than pushing the library off the first screen.
    expect(find.text('True faith sides with God | Hebrews 11:29-31'), findsOneWidget);
    expect(find.text('Why the law was not enough'), findsOneWidget);
    expect(find.text('Prayer the church cannot outpray'), findsNothing);

    // Continue Watching is the first heading on the tab, so its door is first.
    await tester.tap(find.text('See All').first);
    await tester.pumpAndSettle();

    expect(find.text('Prayer the church cannot outpray'), findsOneWidget);
    // The sheet answers the question the card cannot: how much is left.
    expect(find.text('Uliza · 20 min left'), findsOneWidget);

    await tester.tap(find.text('Prayer the church cannot outpray'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.mediaItem);
    expect(find.text('RECORDING SCREEN'), findsOneWidget);
  });

  testWidgets('nobody is offered a place they never got to', (tester) async {
    // The section belongs to an account. A visitor has no watch rows to read,
    // so the tab shows the shelves the ministry published and nothing else.
    final repository = await pumpLearn(tester, rows: sampleMediaShelves());

    expect(find.text('Continue Watching'), findsNothing);
    expect(repository.resumeCalls, 0);
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
