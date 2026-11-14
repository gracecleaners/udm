import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/core/widgets/app_kit.dart';
import 'package:udm_frontend/app/data/models/resource_topic.dart';
import 'package:udm_frontend/app/data/repositories/resources_repository.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/resources/courses_controller.dart';
import 'package:udm_frontend/app/modules/resources/courses_view.dart';
import 'package:udm_frontend/app/modules/resources/resource_topic_binding.dart';
import 'package:udm_frontend/app/modules/resources/resource_topic_view.dart';

import '../support/fakes.dart';

/// The Courses screen: the ministry's guides, and the student's own place in
/// each one. Every number on this screen is the server's, worked out against
/// the steps it has published today.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<FakeResourcesRepository> pumpCourses(
    WidgetTester tester, {
    List<ResourceTopic> rows = const [],
    List<ResourceTopic>? cachedRows,
    ResourceTopic? row,
    Failure? failure,
  }) async {
    final repository = FakeResourcesRepository(
      topicRows: rows,
      cachedTopicRows: cachedRows,
      topicRow: row,
      failure: failure,
    );
    // Registered under the real type: this is the instance the screen's own
    // binding would look up for a student arriving from the feed.
    Get.put<ResourcesRepository>(repository, permanent: true);
    Get.put<ContentVersionController>(FakeContentVersionController(), permanent: true);
    Get.put(CoursesController(Get.find<ResourcesRepository>()));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(
            name: AppRoutes.resourceTopic,
            page: () => const ResourceTopicView(),
            binding: ResourceTopicBinding(),
          ),
        ],
        home: const CoursesView(),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  /// One guide the student is partway through, exactly as `/resources/` answers
  /// it for an account that has finished two of five steps.
  ResourceTopic begun({
    int done = 2,
    int of = 5,
    String title = 'Receive Christ',
    int? version,
  }) =>
      ResourceTopic(
        id: 'r1',
        title: title,
        summary: 'Five short steps through what God has already done.',
        stepCount: of,
        stepsCompleted: done,
        contentVersion: version,
      );

  testWidgets('every guide the ministry wrote is offered by what it holds', (tester) async {
    final repository = await pumpCourses(tester, rows: sampleResourceTopics());

    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Receive Christ'), findsOneWidget);
    expect(find.text('New Believer'), findsOneWidget);
    expect(find.text('Prayer'), findsOneWidget);
    // Nothing started, so nothing claims a student is partway through.
    expect(find.text('PICK UP WHERE YOU STOPPED'), findsNothing);
    expect(find.text('5 steps'), findsWidgets);
    expect(repository.topicsCalls, 1);
  });

  testWidgets('a guide already begun comes first and says how far it goes', (tester) async {
    await pumpCourses(tester, rows: [
      const ResourceTopic(id: 'r3', title: 'Prayer', stepCount: 3),
      begun(),
    ]);

    expect(find.text('PICK UP WHERE YOU STOPPED'), findsOneWidget);
    expect(find.text('OTHER GUIDES'), findsOneWidget);
    expect(find.text('2 of 5 steps done'), findsOneWidget);
    // The untouched guide keeps its plain count: a bar would read as a fact
    // about the guide rather than about the reader.
    expect(find.text('3 steps'), findsOneWidget);
  });

  testWidgets('a guide read through is marked through, not left at a full bar', (tester) async {
    await pumpCourses(tester, rows: [begun(done: 5)]);

    expect(find.text('5 of 5 steps done'), findsOneWidget);
    expect(find.byIcon(AppIcons.checkCircle), findsOneWidget);
  });

  testWidgets('a row really opens the guide it names', (tester) async {
    await pumpCourses(
      tester,
      rows: sampleResourceTopics(),
      // The guide page the row leads to fetches its own row by id.
      row: sampleResourceTopic(),
    );

    await tester.tap(find.text('Prayer'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.resourceTopic);
    expect(find.byType(ResourceTopicView), findsOneWidget);
  });

  testWidgets('a saved set of guides keeps the screen working offline', (tester) async {
    final saved = sampleResourceTopics()
        .map((topic) => topic.withCacheStamp(DateTime.utc(2026, 11, 9), version: 4))
        .map((topic) => topic.asCached())
        .toList();

    final repository = await pumpCourses(
      tester,
      cachedRows: saved,
      failure: const Failure(FailureKind.offline, 'No connection to the UDM service.'),
    );

    expect(find.text('Receive Christ'), findsOneWidget);
    expect(find.text('Offline copy of the guides'), findsOneWidget);
    expect(find.text('We could not load this'), findsNothing);
    expect(repository.topicsCalls, 1);
  });

  testWidgets('a ministry edit reloads the screen while it is open', (tester) async {
    final repository = await pumpCourses(tester, rows: [begun(version: 7)]);

    final versions = Get.find<ContentVersionController>() as FakeContentVersionController;
    repository.topicRows = [begun(title: 'Salt and Light', of: 4, done: 1, version: 8)];
    versions.emit(8);
    await tester.pumpAndSettle();

    expect(repository.topicsCalls, 2);
    expect(find.text('Salt and Light'), findsOneWidget);
    expect(find.text('1 of 4 steps done'), findsOneWidget);
    expect(find.text('New Believer'), findsNothing);
  });

  testWidgets('a first load that fails offers a working retry', (tester) async {
    final repository = await pumpCourses(
      tester,
      failure: const Failure(FailureKind.offline, 'No connection'),
    );

    expect(find.text('We could not load this'), findsOneWidget);

    repository
      ..failure = null
      ..topicRows = sampleResourceTopics();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.topicsCalls, 2);
    expect(find.text('Prayer'), findsOneWidget);
  });
}
