import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/models/resource_step.dart';
import 'package:udm_frontend/app/data/models/resource_topic.dart';
import 'package:udm_frontend/app/data/repositories/resources_repository.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/resources/resource_topic_binding.dart';
import 'package:udm_frontend/app/modules/resources/resource_topic_view.dart';

import '../support/fakes.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  /// Opens one guide the way home does: a named route carrying its id.
  Future<FakeResourcesRepository> pumpGuide(
    WidgetTester tester, {
    ResourceTopic? row,
    ResourceTopic? cachedRow,
    Failure? failure,
  }) async {
    final repository = FakeResourcesRepository(
      topicRow: row,
      cachedTopicRow: cachedRow,
      failure: failure,
    );
    Get.put<ResourcesRepository>(repository, permanent: true);
    Get.put<ContentVersionController>(FakeContentVersionController(), permanent: true);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(
            name: AppRoutes.resourceTopic,
            page: () => const ResourceTopicView(),
            binding: ResourceTopicBinding(),
          ),
          GetPage(
            name: AppRoutes.resourceStep,
            page: () => const Center(child: Text('STEP SCREEN')),
          ),
        ],
        // Home reaches a guide by name with its id, so the test does the same
        // and the binding is the one that reads it.
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Get.toNamed(
                  AppRoutes.resourceTopic,
                  arguments: {RouteArgs.resourceTopicId: 'r1'},
                ),
                child: const Text('OPEN GUIDE'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN GUIDE'));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('the guide lists its steps in the order the ministry wrote them', (tester) async {
    await pumpGuide(tester, row: sampleResourceTopic());

    expect(find.text('Receive Christ'), findsOneWidget);
    expect(find.text('STEP ORDER'), findsOneWidget);
    expect(find.text('He is near'), findsOneWidget);
    expect(find.text('Starting point'), findsOneWidget);
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('All turned aside'), findsOneWidget);
    expect(find.text('Acts 17:27-28'), findsOneWidget);
    expect(find.text('4 min'), findsOneWidget);
  });

  testWidgets('only a step with a curated link shows a play mark', (tester) async {
    await pumpGuide(tester, row: sampleResourceTopic());

    // Three of the four steps have no video, so exactly one row carries the
    // promise: the icon is the link, never decoration.
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('opening a row really opens that step', (tester) async {
    await pumpGuide(tester, row: sampleResourceTopic());

    await tester.tap(find.text('Calling on Him'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.resourceStep);
    expect(find.text('STEP SCREEN'), findsOneWidget);
  });

  testWidgets('a saved guide reads immediately while the network is out', (tester) async {
    final repository = await pumpGuide(
      tester,
      cachedRow: sampleResourceTopic().withCacheStamp(DateTime.utc(2026, 11, 9), version: 4).asCached(),
      failure: const Failure(FailureKind.offline, 'No connection to the UDM service.'),
    );

    expect(find.text('Receive Christ'), findsOneWidget);
    expect(find.text('All turned aside'), findsOneWidget);
    expect(find.text('Offline copy of this guide'), findsOneWidget);
    // The failure is not shown as an error over a guide that reads fine.
    expect(find.text('We could not load this'), findsNothing);
    expect(repository.topicCalls, 1);
  });

  testWidgets('a guide that stopped being published says so', (tester) async {
    await pumpGuide(
      tester,
      failure: const Failure(FailureKind.notFound, 'We could not find that.'),
    );

    expect(find.text('Nothing published in this guide yet'), findsOneWidget);
    expect(
      find.text('The ministry team has not released a step of this guide. Check back soon.'),
      findsOneWidget,
    );
  });

  testWidgets('a ministry edit reloads the guide while it is open', (tester) async {
    final repository = await pumpGuide(tester, row: sampleResourceTopic());

    final versions = Get.find<ContentVersionController>() as FakeContentVersionController;
    repository.topicRow = const ResourceTopic(
      id: 'r1',
      title: 'Receive Christ',
      stepCount: 1,
      contentVersion: 8,
      steps: [ResourceStep(id: 's9', title: 'Grace reached across', order: 1)],
    );
    versions.emit(8);
    await tester.pumpAndSettle();

    expect(repository.topicCalls, 2);
    expect(find.text('Grace reached across'), findsOneWidget);
    expect(find.text('All turned aside'), findsNothing);
  });
}
