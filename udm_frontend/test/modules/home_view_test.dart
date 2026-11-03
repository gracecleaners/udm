import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/modules/home/home_controller.dart';
import 'package:udm_frontend/app/modules/home/home_view.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';

import '../support/fakes.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<void> pumpHome(WidgetTester tester, HomeController controller) async {
    Get.put(controller);
    Get.put(
      SessionController(
        FakeAuthRepository(profile: sampleProfile()),
        ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1/api/v1')), tokenStore: InMemoryTokenStore()),
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(name: AppRoutes.devotion, page: () => const Center(child: Text('DEVOTION SCREEN'))),
          GetPage(name: AppRoutes.article, page: () => const Center(child: Text('ARTICLE SCREEN'))),
          GetPage(name: AppRoutes.signIn, page: () => const Center(child: Text('SIGN IN SCREEN'))),
          GetPage(name: AppRoutes.register, page: () => const Center(child: Text('REGISTER SCREEN'))),
        ],
        home: const HomeView(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the server-curated verse, devotion and articles', (tester) async {
    await pumpHome(tester, HomeController(FakeHomeRepository(payload: sampleHome())));

    expect(find.text('Good morning, Grace'), findsOneWidget);
    expect(find.textContaining('Be not conformed to this world.'), findsOneWidget);
    expect(find.text('A Heart That Listens'), findsOneWidget);
    expect(find.text('How to Study a Chapter'), findsOneWidget);
    expect(find.text('Offline copy'), findsNothing);
  });

  testWidgets('opening the devotion really navigates to the reader', (tester) async {
    await pumpHome(tester, HomeController(FakeHomeRepository(payload: sampleHome())));

    await tester.tap(find.text('A Heart That Listens').first);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.devotion);
    expect(find.text('DEVOTION SCREEN'), findsOneWidget);
  });

  testWidgets('cached content is labelled offline, never silently stale', (tester) async {
    await pumpHome(tester, HomeController(FakeHomeRepository(payload: sampleHome().asCached())));

    expect(find.text('Offline copy'), findsWidgets);
  });

  testWidgets('a failed first load offers a working retry', (tester) async {
    final repository = FakeHomeRepository(failure: const Failure(FailureKind.offline, 'No connection'));
    await pumpHome(tester, HomeController(repository));

    expect(find.text('We could not load this'), findsOneWidget);

    repository
      ..failure = null
      ..payload = sampleHome();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    expect(find.text('A Heart That Listens'), findsOneWidget);
  });
}
