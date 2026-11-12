import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_pages.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/models/resource_step.dart';
import 'package:udm_frontend/app/modules/resources/resource_step_controller.dart';
import 'package:udm_frontend/app/modules/resources/resource_step_view.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeContentRepository content;
  late FakeAuthRepository auth;
  late ApiClient client;

  setUp(() {
    Get.testMode = true;
    content = FakeContentRepository(serverStep: sampleResourceStep());
    auth = FakeAuthRepository(profile: sampleProfile());
    client = ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1/api/v1')),
      tokenStore: InMemoryTokenStore(),
    );
  });

  tearDown(() {
    Get.reset();
    client.close();
  });

  Future<void> openStep(WidgetTester tester, ResourceStep step) async {
    content.serverStep = step;
    Get.put<SessionController>(SessionController(auth, client));
    Get.put(ResourceStepController(content, Get.find<SessionController>(), step.id));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(name: AppRoutes.shell, page: () => const ResourceStepView()),
          ...AppPages.pages.where(
            (page) => page.name == AppRoutes.signIn || page.name == AppRoutes.register,
          ),
        ],
        initialRoute: AppRoutes.shell,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the reader shows where the step sits in its guide', (tester) async {
    await openStep(tester, sampleResourceStep());

    expect(find.text('Receive Christ'), findsOneWidget);
    expect(find.text('RECEIVE CHRIST · STEP 2 OF 4'), findsOneWidget);
    expect(find.text('Love reached across'), findsOneWidget);
    expect(find.text('John 3:16'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('What the verse says before it is read.'), findsOneWidget);
    expect(find.text('God so loved the world.'), findsOneWidget);
    expect(find.text('That is the whole argument of the guide.'), findsOneWidget);
  });

  testWidgets('a step with no curated video shows no way to watch one', (tester) async {
    await openStep(tester, sampleResourceStep());

    expect(find.text('Watch'), findsNothing);
    expect(find.text('Watch this step'), findsNothing);
    expect(find.text('Video'), findsNothing);
  });

  testWidgets('a curated link gets a control that says where it goes', (tester) async {
    await openStep(
      tester,
      sampleResourceStep(videoUrl: 'https://videos.udm.ac.ug/receive-christ-love.mp4'),
    );

    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Watch this step'), findsOneWidget);
    expect(
      find.text('Opens in your browser, hosted by the ministry.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('udm.watchStep')), findsOneWidget);
  });

  testWidgets('finishing a step is saved as a resource step', (tester) async {
    auth = FakeAuthRepository(profile: sampleProfile(), hasSessionValue: true);
    await openStep(tester, sampleResourceStep());

    await tester.tap(find.byKey(const Key('udm.markRead')));
    await tester.pumpAndSettle();

    expect(content.completions, ['resource_step:s2']);
    expect(find.text('Marked as read'), findsOneWidget);
  });

  testWidgets('an anonymous reader is offered sign-in', (tester) async {
    await openStep(tester, sampleResourceStep());

    await tester.tap(find.byKey(const Key('udm.markRead')));
    await tester.pumpAndSettle();

    expect(content.completions, isEmpty);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a step the ministry unpubished says so instead of an empty page', (tester) async {
    content.failure = const Failure(FailureKind.notFound, 'We could not find that.');
    await openStep(tester, sampleResourceStep());

    expect(find.text('Step unavailable'), findsOneWidget);
    expect(find.text('This step is no longer published.'), findsOneWidget);
    expect(find.text('Love reached across'), findsNothing);
  });

  testWidgets('the starting point is named, not numbered', (tester) async {
    await openStep(
      tester,
      const ResourceStep(
        id: 'i1',
        title: 'He is near',
        scriptureReference: 'Acts 17:27-28',
        body: 'He is not far from any one of us.',
        topicTitle: 'Receive Christ',
        topicStepCount: 4,
      ),
    );

    expect(find.text('RECEIVE CHRIST · STARTING POINT'), findsOneWidget);
    expect(find.textContaining('Step'), findsNothing);
  });
}
