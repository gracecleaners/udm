import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/providers/udm_api.dart';
import 'package:udm_frontend/app/data/repositories/devotions_repository.dart';
import 'package:udm_frontend/app/data/repositories/home_repository.dart';
import 'package:udm_frontend/app/data/repositories/media_repository.dart';
import 'package:udm_frontend/app/data/repositories/settings_repository.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/devotions/devotions_view.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';
import 'package:udm_frontend/app/modules/settings/app_language_controller.dart';
import 'package:udm_frontend/app/modules/shell/shell_binding.dart';
import 'package:udm_frontend/app/modules/shell/shell_controller.dart';
import 'package:udm_frontend/app/modules/shell/shell_view.dart';

import '../support/fakes.dart';

/// The tab bar hosts every feature at once, so this is the one fake that has to
/// answer for all of them. Everything the shell does not render is left to
/// `noSuchMethod`, which fails a test loudly instead of silently.
class _ShellApi implements UdmApi {
  int contentVersionCalls = 0;

  @override
  Future<int> contentVersion() async {
    contentVersionCalls++;
    return 3;
  }

  @override
  Future<List<Map<String, dynamic>>> bibleTranslations({String language = 'en'}) async => const [
    {
      'id': 't1',
      'code': 'kjv',
      'name': 'King James Version',
      'offline_allowed': true,
      'attribution': 'King James Version (public domain).',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> bibleBooks(String code) async => const [
    {'id': 'b1', 'name': 'John', 'provider_id': 'JHN', 'order': 43, 'testament': 'new', 'chapter_count': 21},
  ];

  @override
  Future<List<int>> bibleBookChapters(String code, String book) async => const [1];

  @override
  Future<Map<String, dynamic>> bibleChapter(String code, String book, int chapter) async => const {
    'id': 'c1',
    'book': 'John',
    'number': 1,
    'translation': 'kjv',
    'verses': [
      {'id': 'v1', 'verse': 1, 'text': 'In the beginning was the Word.'},
    ],
  };

  @override
  Future<List<Map<String, dynamic>>> biblePassageSources() async => const [
    {'code': 'kjv', 'name': 'King James Version', 'text_available': true, 'offline_allowed': true, 'configured': true},
  ];

  @override
  Future<List<Map<String, dynamic>>> biblePlans() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<_ShellApi> pumpShell(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final cache = LocalCache(await SharedPreferences.getInstance());
    final api = _ShellApi();
    Get.put<LocalCache>(cache, permanent: true);
    Get.put<AppLanguageController>(AppLanguageController(SettingsRepository(cache)), permanent: true);
    Get.put<UdmApi>(api, permanent: true);
    Get.put<ContentVersionController>(ContentVersionController(api), permanent: true);
    Get.put<HomeRepository>(FakeHomeRepository(payload: sampleHome()), permanent: true);
    Get.put<DevotionsRepository>(
      FakeDevotionsRepository(gridRows: sampleSeriesGrid()),
      permanent: true,
    );
    Get.put<MediaRepository>(
      FakeMediaRepository(shelfRows: sampleMediaShelves()),
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
    ShellBinding().dependencies();
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const ShellView()),
    );
    await tester.pumpAndSettle();
    return api;
  }

  /// The tab bar only: every label a feature screen also uses is in the tree at
  /// the same time, because the shell builds all its tabs up front.
  Finder nav(String label) => find.descendant(
    of: find.byKey(const Key('udm.tabBar')),
    matching: find.text(label),
  );

  testWidgets('the bottom nav reads Home, Devotions, Bible, Learn, Profile', (tester) async {
    await pumpShell(tester);

    expect(nav('Home'), findsOneWidget);
    expect(nav('Devotions'), findsOneWidget);
    expect(nav('Bible'), findsOneWidget);
    expect(nav('Learn'), findsOneWidget);
    expect(nav('Profile'), findsOneWidget);
    // Community is out of the tab bar; the ministry pages that replaced it are
    // not reachable from here any more.
    expect(find.text('Community'), findsNothing);
    expect(find.text('Fellowships'), findsNothing);
  });

  testWidgets('the feed is what opens, and the devotion it curates is readable', (tester) async {
    await pumpShell(tester);

    expect(Get.find<ShellController>().tab.value, ShellController.homeTab);
    expect(find.text('Good morning, Grace'), findsOneWidget);
  });

  testWidgets('the Devotions tab is the series grid', (tester) async {
    await pumpShell(tester);

    await tester.tap(nav('Devotions'));
    await tester.pumpAndSettle();

    expect(Get.find<ShellController>().tab.value, ShellController.devotionsTab);
    expect(find.byType(DevotionsView), findsOneWidget);
    expect(find.text('The Book of James'), findsOneWidget);
  });

  testWidgets('moving between tabs asks the server whether the library moved', (tester) async {
    final api = await pumpShell(tester);
    expect(api.contentVersionCalls, 1);

    await tester.tap(nav('Bible'));
    await tester.pumpAndSettle();
    await tester.tap(nav('Profile'));
    await tester.pumpAndSettle();

    // One poll at launch, then one per tab change: one integer, not the library.
    expect(api.contentVersionCalls, 3);
  });

  testWidgets('every tab keeps working after the swap', (tester) async {
    await pumpShell(tester);

    await tester.tap(nav('Bible'));
    await tester.pumpAndSettle();
    expect(Get.find<ShellController>().tab.value, ShellController.bibleTab);

    await tester.tap(nav('Learn'));
    await tester.pumpAndSettle();
    expect(Get.find<ShellController>().tab.value, ShellController.learnTab);
    // The tab is the ministry's shelves, not a course list that no longer
    // exists: what staff publish in the console is what this tab renders.
    expect(find.text('SOMA'), findsOneWidget);
    expect(find.text('Podcast'), findsOneWidget);
    expect(find.text('Courses'), findsNothing);

    await tester.tap(nav('Profile'));
    await tester.pumpAndSettle();
    expect(Get.find<ShellController>().tab.value, ShellController.profileTab);
    expect(find.text('Not signed in'), findsOneWidget);
  });
}
