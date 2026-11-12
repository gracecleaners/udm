import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/providers/udm_api.dart';
import 'package:udm_frontend/app/data/repositories/settings_repository.dart';
import 'package:udm_frontend/app/modules/bible/bible_controller.dart';
import 'package:udm_frontend/app/modules/bible/bible_view.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';
import 'package:udm_frontend/app/modules/settings/app_language_controller.dart';

import '../support/fakes.dart';

/// Captured from the running backend, 2026-11-11:
/// `GET /api/v1/bible/passage/?reference=Jn 3:16-18&translation=niv`
/// The app asked for a version it may not print, so the response carries
/// public-domain text, the requested version's authorized link, and the reason.
const _liveNivFallback = '''
{
 "reference": "John 3:16-18",
 "translation": "kjv",
 "translation_name": "King James Version",
 "source": "bible_api",
 "text": "For God so loved the world, that he gave his only begotten Son.",
 "verses": [
  {"verse": 16, "text": "For God so loved the world, that he gave his only begotten Son.", "id": ""},
  {"verse": 17, "text": "For God sent not his Son into the world to condemn the world.", "id": ""},
  {"verse": 18, "text": "He that believeth on him is not condemned.", "id": ""}
 ],
 "deep_link_url": "https://www.biblegateway.com/passage/?search=John+3%3A16-18&version=NIV",
 "alternate_link_url": "",
 "attribution": "New International Version: NIV text is licensed by Biblica and may not be served from this app. Open it on an authorised site. Shown in King James Version because NIV text is licensed by Biblica and may not be served from this app. Open it on an authorised site.",
 "offline_allowed": true,
 "fallback": {"requested": "niv", "requested_name": "New International Version", "reason": "NIV text is licensed by Biblica and may not be served from this app. Open it on an authorised site."},
 "cached": true
}
''';

/// Captured from `GET /api/v1/bible/sources/` the same day, trimmed to four of
/// the eleven rows: the two shapes the picker has to tell apart.
const _liveSources = '''
[
 {"code": "kjv", "name": "King James Version", "source": "bible_api", "text_available": true,
  "offline_allowed": true, "attribution": "King James Version (public domain).", "configured": true},
 {"code": "esv", "name": "English Standard Version", "source": "esv", "text_available": true,
  "offline_allowed": false, "attribution": "ESV text (c) Crossway.", "configured": false},
 {"code": "niv", "name": "New International Version", "source": "deep_link", "text_available": false,
  "offline_allowed": false, "attribution": "Licensed by Biblica.", "configured": false},
 {"code": "web", "name": "World English Bible", "source": "bible_api", "text_available": true,
  "offline_allowed": true, "attribution": "World English Bible (public domain).", "configured": true}
]
''';

/// The one field no live response can show in this deployment: its database
/// holds YouVersion catalog rows only, so no verse has a stored row to point at.
/// `/api/v1/bible/passage/` fills `id` when it does, which is what makes a
/// searched verse savable; `StoredVerseIdentityTests` covers the server half.
Map<String, dynamic> _passageWithAStoredVerse() {
  final decoded = jsonDecode(_liveNivFallback) as Map<String, dynamic>;
  final verses = decoded['verses'] as List<dynamic>;
  verses[0] = {...verses[0] as Map<String, dynamic>, 'id': 'b7e1c2d0-4f6a-4b1e-9c3d-5a2b1c0d9e8f'};
  return decoded;
}

class _FakeBibleApi implements UdmApi {
  _FakeBibleApi({this.translations = const [], this.passage});

  final List<Map<String, dynamic>> translations;
  Map<String, dynamic>? passage;
  final List<List<String>> lookedUp = [];

  bool offlinePassage = false;

  @override
  Future<List<Map<String, dynamic>>> bibleTranslations({String language = 'en'}) async =>
      translations;

  @override
  Future<List<Map<String, dynamic>>> bibleBooks(String code) async => const [
    {
      'id': 'b1',
      'name': 'John',
      'provider_id': 'JHN',
      'order': 43,
      'testament': 'new',
      'chapter_count': 21,
    },
  ];

  @override
  Future<List<int>> bibleBookChapters(String code, String book) async => const [1, 3];

  @override
  Future<Map<String, dynamic>> bibleChapter(String code, String book, int chapter) async =>
      const {'id': 'c1', 'book': 'John', 'number': 1, 'translation': 'kjv', 'verses': []};

  @override
  Future<List<Map<String, dynamic>>> biblePassageSources() async =>
      (jsonDecode(_liveSources) as List).cast<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> biblePassage(String reference, {String? translation}) async {
    lookedUp.add([reference, translation ?? '']);
    if (offlinePassage) {
      throw const Failure(FailureKind.offline, 'No connection to the UDM service.');
    }
    return passage ?? jsonDecode(_liveNivFallback) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> biblePlans() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<_FakeBibleApi> pumpBible(
    WidgetTester tester, {
    required List<Map<String, dynamic>> translations,
    Map<String, dynamic>? passage,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final api = _FakeBibleApi(translations: translations, passage: passage);
    final cache = LocalCache(await SharedPreferences.getInstance());
    Get.put(AppLanguageController(SettingsRepository(cache)), permanent: true);
    Get.put(
      SessionController(
        FakeAuthRepository(),
        ApiClient(
          dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1/api/v1')),
          tokenStore: InMemoryTokenStore(),
        ),
      ),
      permanent: true,
    );
    Get.put<ContentVersionController>(FakeContentVersionController(), permanent: true);
    Get.put(BibleController(api, cache, Get.find<SessionController>()));
    // The shell hosts every tab inside a Scaffold, and a focused text field
    // needs that Material ancestor; pumping the view bare would test a shape
    // the app never renders.
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: BibleView())),
    );
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> search(WidgetTester tester, String reference) async {
    await tester.enterText(find.byType(TextField), reference);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  const catalogRow = {
    'id': 't1',
    'code': 'kjv',
    'name': 'King James Version',
    'license_name': 'Public domain',
    'attribution': 'King James Version (public domain).',
    'offline_allowed': true,
    'language': 'English',
  };

  testWidgets('a searched reference renders the passage exactly as the API served it', (tester) async {
    final api = await pumpBible(tester, translations: const [catalogRow]);

    await search(tester, 'Jn 3:16-18');

    expect(api.lookedUp.last, ['Jn 3:16-18', 'kjv']);
    expect(find.text('King James Version · John 3:16-18'), findsOneWidget);
    expect(find.text('For God sent not his Son into the world to condemn the world.'), findsOneWidget);
    expect(find.text('He that believeth on him is not condemned.'), findsOneWidget);
  });

  testWidgets('a version that cannot be printed says why and hands over the link', (tester) async {
    await pumpBible(
      tester,
      translations: const [catalogRow],
      passage: jsonDecode(_liveNivFallback) as Map<String, dynamic>,
    );

    await search(tester, 'John 3:16-18');

    expect(
      find.text(
        'New International Version: NIV text is licensed by Biblica and may not be served '
        'from this app. Open it on an authorised site.',
      ),
      findsOneWidget,
    );
    expect(find.text('Open New International Version on Bible Gateway'), findsOneWidget);
  });

  testWidgets('only a verse with a stored row offers the private save menu', (tester) async {
    // No catalog means the passage below is the only verse on screen, so the
    // menu count says exactly which rows the app may save against.
    await pumpBible(
      tester,
      translations: const [],
      passage: _passageWithAStoredVerse(),
    );

    await search(tester, 'John 3:16-18');

    expect(find.text('For God so loved the world, that he gave his only begotten Son.'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });

  testWidgets('lookup works with an empty catalog, chapter browsing does not', (tester) async {
    await pumpBible(tester, translations: const []);

    expect(find.text('LOOK UP ANY VERSE'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Book'), findsNothing);
    expect(
      find.textContaining('No translation has been synced into this deployment yet'),
      findsOneWidget,
    );
  });

  testWidgets('the version picker comes from the server and flags what it cannot print', (tester) async {
    await pumpBible(tester, translations: const []);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('World English Bible'), findsOneWidget);
    expect(find.text('New International Version · authorized link only'), findsOneWidget);
    expect(find.text('English Standard Version · needs a key'), findsOneWidget);
  });

  testWidgets('a passage saved on the device is labelled an offline copy when the network fails', (tester) async {
    final api = await pumpBible(tester, translations: const [catalogRow]);
    await search(tester, 'John 3:16-18');
    expect(find.text('Offline copy · saved on this device'), findsNothing);

    api.offlinePassage = true;
    // Another spelling of the same passage: the device keeps one copy per
    // passage, not one per way of typing it.
    await search(tester, 'john 3 16-18');

    expect(find.text('Offline copy · saved on this device'), findsOneWidget);
    expect(find.text('For God sent not his Son into the world to condemn the world.'), findsOneWidget);
  });

  testWidgets('a blank reference is answered on the device, not asked of the server', (tester) async {
    final api = await pumpBible(tester, translations: const [catalogRow]);

    await search(tester, '   ');

    expect(find.text('Type a reference, for example John 3:16.'), findsOneWidget);
    expect(api.lookedUp, isEmpty);
  });
}
