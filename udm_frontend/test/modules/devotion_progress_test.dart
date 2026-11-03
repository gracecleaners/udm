import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_pages.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/modules/devotion/devotion_controller.dart';
import 'package:udm_frontend/app/modules/devotion/devotion_view.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeContentRepository content;
  late FakeAuthRepository auth;
  late ApiClient client;

  setUp(() {
    Get.testMode = true;
    content = FakeContentRepository(serverDevotional: sampleHome().devotion!);
    auth = FakeAuthRepository(profile: sampleProfile());
    client = ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1/api/v1')), tokenStore: InMemoryTokenStore());
  });

  tearDown(() {
    Get.reset();
    client.close();
  });

  Future<void> openReader(WidgetTester tester) async {
    Get.put<SessionController>(SessionController(auth, client));
    Get.put(DevotionController(content, Get.find<SessionController>(), 'd1'));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(name: AppRoutes.shell, page: () => const DevotionView()),
          ...AppPages.pages.where(
            (page) => page.name == AppRoutes.signIn || page.name == AppRoutes.register,
          ),
        ],
        initialRoute: AppRoutes.shell,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('marking a devotion read sends it to the server and says so', (tester) async {
    auth = FakeAuthRepository(profile: sampleProfile(), hasSessionValue: true);
    await openReader(tester);

    await tester.tap(find.byKey(const Key('udm.markRead')));
    await tester.pumpAndSettle();

    expect(content.completions, ['devotional:d1']);
    expect(find.text('Marked as read'), findsOneWidget);
    expect(find.text('Sign in to keep this in your reading history.'), findsNothing);
  });

  testWidgets('an anonymous reader is offered sign-in instead of a silent failure', (tester) async {
    await openReader(tester);

    expect(find.text('Sign in to keep this in your reading history.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('udm.markRead')));
    await tester.pumpAndSettle();

    expect(content.completions, isEmpty);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a failed completion keeps the button and explains itself', (tester) async {
    auth = FakeAuthRepository(profile: sampleProfile(), hasSessionValue: true);
    content.progressFailure = const Failure(FailureKind.offline, 'You appear to be offline.');
    await openReader(tester);

    await tester.tap(find.byKey(const Key('udm.markRead')));
    await tester.pumpAndSettle();

    expect(find.text('You appear to be offline.'), findsOneWidget);
    expect(find.text('Marked as read'), findsNothing);
    expect(find.byKey(const Key('udm.markRead')), findsOneWidget);
  });

  testWidgets('the reader still shows the devotion itself', (tester) async {
    await openReader(tester);

    expect(find.text('A Heart That Listens'), findsOneWidget);
    expect(find.text('Reflect'), findsOneWidget);
  });
}
