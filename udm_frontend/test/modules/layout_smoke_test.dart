import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/routes/app_pages.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/providers/udm_api.dart';
import 'package:udm_frontend/app/data/repositories/content_repository.dart';
import 'package:udm_frontend/app/data/repositories/devotions_repository.dart';
import 'package:udm_frontend/app/data/repositories/home_repository.dart';
import 'package:udm_frontend/app/data/repositories/media_repository.dart';
import 'package:udm_frontend/app/data/repositories/resources_repository.dart';
import 'package:udm_frontend/app/data/repositories/settings_repository.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/onboarding/onboarding_controller.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';
import 'package:udm_frontend/app/modules/settings/app_language_controller.dart';
import 'package:udm_frontend/app/modules/shell/shell_controller.dart';
import 'package:udm_frontend/app/modules/shell/shell_view.dart';

import '../support/fakes.dart';

/// The redesign has to survive the phone a student actually has, in the theme
/// they actually picked. Nothing here asserts what a screen says — only that
/// laying it out at a small width, or a tall one, in light or dark, stays
/// quiet.
///
/// The test font is wider and taller than Plus Jakarta Sans, so a layout that
/// passes here has room to spare in the app.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  /// 320 x 568 is the smallest Android screen the ministry's students still
  /// carry; 430 x 932 is a large modern device.
  const smallPhone = Size(320, 568);
  const largePhone = Size(430, 932);

  /// The whole app on its real route table, with the fakes behind every
  /// repository a screen asks for.
  Future<void> openApp(WidgetTester tester, {required Size size, required ThemeData theme}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final cache = LocalCache(await SharedPreferences.getInstance());
    final api = FakeShellApi();
    Get.put<LocalCache>(cache, permanent: true);
    Get.put<UdmApi>(api, permanent: true);
    Get.put<AppLanguageController>(
      AppLanguageController(SettingsRepository(cache)),
      permanent: true,
    );
    Get.put<ContentVersionController>(ContentVersionController(api), permanent: true);
    Get.put<SettingsRepository>(SettingsRepository(cache), permanent: true);
    Get.put<HomeRepository>(FakeHomeRepository(payload: sampleHome()), permanent: true);
    Get.put<DevotionsRepository>(
      FakeDevotionsRepository(gridRows: sampleSeriesGrid(), seriesRow: sampleSeriesDetail()),
      permanent: true,
    );
    Get.put<MediaRepository>(
      FakeMediaRepository(
        shelfRows: sampleMediaShelves(),
        shelfRow: sampleMediaShelves().first,
        itemRow: sampleRecording(),
      ),
      permanent: true,
    );
    Get.put<ResourcesRepository>(
      FakeResourcesRepository(topicRows: sampleResourceTopics(), topicRow: sampleResourceTopic()),
      permanent: true,
    );
    Get.put<ContentRepository>(
      FakeContentRepository(
        serverDevotional: sampleHome().devotion,
        serverStep: sampleResourceStep(),
        serverArticle: sampleHome().articles.first,
      ),
      permanent: true,
    );
    Get.put<SessionController>(
      SessionController(
        FakeAuthRepository(profile: sampleProfile()),
        ApiClient(
          dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1/api/v1')),
          tokenStore: InMemoryTokenStore(),
        ),
      ),
      permanent: true,
    );

    await tester.pumpWidget(
      GetMaterialApp(theme: theme, getPages: AppPages.pages, initialRoute: AppRoutes.shell),
    );
    await tester.pumpAndSettle();
  }

  /// A screen is only laid out as far as the student has scrolled, and these
  /// lists build their rows lazily, so every scroller on the page is walked to
  /// its end before the page is judged.
  Future<void> scrollEverything(WidgetTester tester) async {
    for (var pass = 0; pass < 2; pass++) {
      final scrollers = find.byType(Scrollable);
      final count = scrollers.evaluate().length;
      for (var i = 0; i < count; i++) {
        final target = scrollers.at(i);
        try {
          for (var step = 0; step < 6; step++) {
            await tester.drag(target, const Offset(0, -400));
            await tester.pump();
          }
        } catch (_) {
          // A scroller that has left the tree mid-walk is not a layout
          // failure. The assertion after this walk is the verdict.
        }
      }
    }
    await tester.pumpAndSettle();
    // The layout error, if any, is left unhandled on purpose: the test then
    // fails with the rendering library's own report of the widget at fault.
  }

  /// Opens one screen the way the feed does — pushed by name with its id —
  /// judges it, then returns to the feed before the next is opened.
  Future<void> visit(
    WidgetTester tester,
    String route,
    Map<String, dynamic> arguments,
    String label,
  ) async {
    debugPrint('layout: $label');
    Get.toNamed(route, arguments: arguments);
    await tester.pumpAndSettle();
    await scrollEverything(tester);
    Get.back();
    await tester.pumpAndSettle();
  }

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final size in [smallPhone, largePhone]) {
      final where = '${size.width.toInt()}dp ${theme.brightness.name}';

      testWidgets('every tab lays out on $where', (tester) async {
        await openApp(tester, size: size, theme: theme);

        for (var tab = 0; tab < ShellView.tabs.length; tab++) {
          debugPrint('layout: tab $tab');
          Get.find<ShellController>().select(tab);
          await tester.pumpAndSettle();
          await scrollEverything(tester);
        }
      });

      testWidgets('the reading screens keep their shape on $where', (tester) async {
        await openApp(tester, size: size, theme: theme);

        await visit(tester, AppRoutes.devotion, {RouteArgs.devotionId: 'd1'}, 'devotion');
        await visit(tester, AppRoutes.devotionSeries, {RouteArgs.seriesId: 's1'}, 'series');
        await visit(tester, AppRoutes.article, {RouteArgs.articleId: 'a1'}, 'article');
      });

      testWidgets('a guide and its steps keep their shape on $where', (tester) async {
        await openApp(tester, size: size, theme: theme);

        await visit(tester, AppRoutes.resourceTopic, {RouteArgs.resourceTopicId: 'r1'}, 'guide');
        await visit(tester, AppRoutes.resourceStep, {RouteArgs.resourceStepId: 's2'}, 'step');
      });

      testWidgets('a shelf and its recording keep their shape on $where', (tester) async {
        await openApp(tester, size: size, theme: theme);

        await visit(tester, AppRoutes.mediaCollection, {RouteArgs.mediaCollectionId: 'c1'}, 'shelf');
        await visit(tester, AppRoutes.mediaItem, {RouteArgs.mediaItemId: 'm1'}, 'recording');
      });

      testWidgets('sign in and registration keep their shape on $where', (tester) async {
        await openApp(tester, size: size, theme: theme);

        await visit(tester, AppRoutes.signIn, const {}, 'sign in');
        await visit(tester, AppRoutes.register, const {}, 'register');
      });

      testWidgets('onboarding keeps its shape on $where', (tester) async {
        await openApp(tester, size: size, theme: theme);

        Get.toNamed(AppRoutes.onboarding);
        await tester.pumpAndSettle();
        for (var slide = 0; slide < OnboardingController.slides.length; slide++) {
          Get.find<OnboardingController>().next();
          await tester.pumpAndSettle();
          await scrollEverything(tester);
        }
      });

      testWidgets('a signed-out profile keeps its shape on $where', (tester) async {
        await openApp(tester, size: size, theme: theme);

        Get.find<ShellController>().select(ShellController.profileTab);
        await tester.pumpAndSettle();
        await Get.find<SessionController>().signOut();
        await tester.pumpAndSettle();
        await scrollEverything(tester);
      });
    }
  }
}
