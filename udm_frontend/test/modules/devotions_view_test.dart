import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/models/devotion_series.dart';
import 'package:udm_frontend/app/data/repositories/devotions_repository.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/devotions/devotion_series_binding.dart';
import 'package:udm_frontend/app/modules/devotions/devotion_series_view.dart';
import 'package:udm_frontend/app/modules/devotions/devotions_controller.dart';
import 'package:udm_frontend/app/modules/devotions/devotions_view.dart';

import '../support/fakes.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<FakeDevotionsRepository> pumpGrid(
    WidgetTester tester, {
    List<DevotionSeries> rows = const [],
    List<DevotionSeries>? cachedRows,
    Failure? failure,
    DevotionSeries? seriesRow,
  }) async {
    final repository = FakeDevotionsRepository(
      gridRows: rows,
      cachedRows: cachedRows,
      seriesRow: seriesRow,
      failure: failure,
    );
    // Registered under the real type: this is the instance every screen and
    // every binding looks up.
    Get.put<DevotionsRepository>(repository, permanent: true);
    Get.put<ContentVersionController>(FakeContentVersionController(), permanent: true);
    Get.put(DevotionsController(Get.find<DevotionsRepository>()));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(
            name: AppRoutes.devotionSeries,
            page: () => const DevotionSeriesView(),
            binding: DevotionSeriesBinding(),
          ),
          GetPage(
            name: AppRoutes.devotion,
            page: () => const Center(child: Text('DEVOTION SCREEN')),
          ),
        ],
        home: const Scaffold(body: DevotionsView()),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('the grid shows every published series with what a student can read', (tester) async {
    final repository = await pumpGrid(tester, rows: sampleSeriesGrid());

    expect(find.text('The Book of James'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('Christmas'), findsOneWidget);
    // One day reads as one day, not "1 days".
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('Offline copy'), findsNothing);
    expect(repository.gridCalls, 1);
  });

  testWidgets('cover art that will not load leaves the initials tile, not a broken box', (tester) async {
    await pumpGrid(tester, rows: sampleSeriesGrid());

    // Cover art lives on the ministry's own host, so a series can be perfectly
    // published with a picture that this run cannot fetch. Neither tile is
    // allowed to show a hole: the one with art asks for it, and both fall back
    // to their initials.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('TB'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('opening a tile really opens that series in reading order', (tester) async {
    await pumpGrid(
      tester,
      rows: sampleSeriesGrid(),
      seriesRow: sampleSeriesDetail(),
    );

    await tester.tap(find.text('The Book of James'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.devotionSeries);
    expect(find.byType(DevotionSeriesView), findsOneWidget);
    expect(find.text('READING ORDER'), findsOneWidget);
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Who wrote this, and why'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Count it all joy'), findsOneWidget);
    expect(find.text('James 1:2-4'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
  });

  testWidgets('a saved grid keeps the tab readable offline and says so', (tester) async {
    final saved = sampleSeriesGrid().map((series) => series.withCacheStamp(
      DateTime.utc(2026, 11, 9),
      version: 4,
    )).map((series) => series.asCached()).toList();

    final repository = await pumpGrid(
      tester,
      cachedRows: saved,
      failure: const Failure(FailureKind.offline, 'No connection to the UDM service.'),
    );

    expect(find.text('The Book of James'), findsOneWidget);
    expect(find.text('Offline copy'), findsWidgets);
    expect(
      find.text('Saved on this device. Pull to refresh when you are online.'),
      findsOneWidget,
    );
    // The failure is not shown as an error over content that reads fine.
    expect(find.text('We could not load this'), findsNothing);
    expect(repository.gridCalls, 1);
  });

  testWidgets('an unpublished library says so instead of showing nothing', (tester) async {
    await pumpGrid(tester);

    expect(find.text('No series published yet'), findsOneWidget);
    expect(
      find.text(
        'When the ministry team publishes a set of devotionals it appears here as a series.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a ministry edit reloads the grid while the tab is open', (tester) async {
    // Real rows arrive dated by the server, which is what lets the tab notice
    // an edit without a second request racing the first one.
    final dated = sampleSeriesGrid()
        .map((series) => series.withCacheStamp(DateTime.utc(2026, 11, 10), version: 4))
        .toList();
    final repository = await pumpGrid(tester, rows: dated);

    final versions = Get.find<ContentVersionController>() as FakeContentVersionController;
    repository.gridRows = [
      const DevotionSeries(id: 's9', title: 'Life of Joseph', dayCount: 5, contentVersion: 8),
    ];
    versions.emit(8);
    await tester.pumpAndSettle();

    expect(repository.gridCalls, 2);
    expect(find.text('Life of Joseph'), findsOneWidget);
    expect(find.text('The Book of James'), findsNothing);
  });

  testWidgets('pull to refresh asks the server again', (tester) async {
    final repository = await pumpGrid(tester, rows: sampleSeriesGrid());

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 260));
    await tester.pumpAndSettle();

    expect(repository.gridCalls, greaterThan(1));
  });

  testWidgets('the day list opens the devotion it points at', (tester) async {
    await pumpGrid(
      tester,
      rows: sampleSeriesGrid(),
      seriesRow: sampleSeriesDetail(),
    );
    await tester.tap(find.text('The Book of James'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Count it all joy'));
    await tester.pumpAndSettle();

    expect(find.text('DEVOTION SCREEN'), findsOneWidget);
  });
}
