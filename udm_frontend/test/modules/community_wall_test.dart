import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/core/widgets/app_kit.dart';
import 'package:udm_frontend/app/data/models/prayer_post.dart';
import 'package:udm_frontend/app/data/providers/udm_api.dart';
import 'package:udm_frontend/app/modules/community/community_controller.dart';
import 'package:udm_frontend/app/modules/community/community_view.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';

import '../support/fakes.dart';

/// The community wall: everything `/prayers/` answers for one student — the
/// published requests, their own group rows and their own private ones — plus
/// the promises made on them and the words written underneath.
void main() {
  late ApiClient client;

  setUp(() {
    Get.testMode = true;
    client = ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1/api/v1')),
      tokenStore: InMemoryTokenStore(),
    );
  });

  tearDown(() {
    Get.reset();
    client.close();
  });

  /// GetX leaves a snackbar's dismiss timer running past the widget tree, so a
  /// case that saw a bar hands it back here or the next case inherits it.
  Future<void> dismissSnackbars(WidgetTester tester) async {
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  }

  Future<_WallApi> openWall(
    WidgetTester tester, {
    List<PrayerPost> posts = const [],
    Map<String, List<PrayerComment>> comments = const {},
    bool signedIn = true,
    Failure? wallFailure,
    Size size = const Size(430, 1600),
    ThemeData? theme,
  }) async {
    // A wall card is taller than the 600dp test default once its replies are
    // open, and a lazy list builds only what the student has scrolled to, so
    // the cases below are given a surface that holds a card, its thread and
    // the field at the end of it.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _WallApi(posts)
      ..commentRows.addAll(comments)
      ..wallFailure = wallFailure;
    Get.put<UdmApi>(api, permanent: true);
    Get.put<SessionController>(
      SessionController(
        FakeAuthRepository(profile: signedIn ? sampleProfile() : null, hasSessionValue: signedIn),
        client,
      ),
      permanent: true,
    );
    Get.put(CommunityController(api, Get.find<SessionController>()));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: theme ?? AppTheme.light,
        home: const Scaffold(body: SafeArea(child: CommunityView())),
      ),
    );
    await tester.pumpAndSettle();
    // The tab opens on the campus directory; the wall is the fourth section.
    await tester.tap(find.text('Prayer'));
    await tester.pumpAndSettle();
    return api;
  }

  /// The wall's own filter row, named so it is never mistaken for the
  /// directory's section pills above it — both rows offer a choice called
  /// Prayer.
  Finder wallPill(String label) =>
      find.descendant(of: find.byKey(const Key('wall-tabs')), matching: find.text(label));

  /// A card's count doubles as its verb, so tapping the number is tapping the
  /// promise.
  Future<void> tapCount(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(ListView), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  PrayerPost post({
    String id = 'p1',
    String body = 'Please pray for my exams this week.',
    String category = 'prayer',
    String visibility = 'public',
    String moderationState = 'approved',
    bool isOwner = false,
    String ownerName = 'Grace Nabukeera',
    bool affirmed = false,
    int affirmationCount = 12,
    int commentCount = 2,
  }) =>
      PrayerPost(
        id: id,
        body: body,
        category: category,
        visibility: visibility,
        moderationState: moderationState,
        createdAt: DateTime(2026, 11, 11, 9),
        isOwner: isOwner,
        ownerName: ownerName,
        affirmed: affirmed,
        affirmationCount: affirmationCount,
        commentCount: commentCount,
      );

  PrayerComment word({
    String id = 'c1',
    String body = 'Standing with you.',
    String authorName = 'Peter Okello',
    bool isOwner = false,
  }) =>
      PrayerComment(
        id: id,
        body: body,
        authorName: authorName,
        createdAt: DateTime(2026, 11, 11, 10),
        isOwner: isOwner,
      );

  testWidgets('the wall prints who wrote it, how many stand with it and what was said', (tester) async {
    final api = await openWall(tester, posts: [
      post(),
      post(id: 'p2', body: 'God answered before the semester began.', category: 'testimony', ownerName: 'A student', affirmationCount: 0, commentCount: 0),
    ]);

    expect(api.wallsAsked, [null]);
    expect(find.text('Grace Nabukeera'), findsOneWidget);
    expect(find.text('A student'), findsOneWidget);
    expect(find.text('Please pray for my exams this week.'), findsOneWidget);
    expect(find.text('God answered before the semester began.'), findsOneWidget);
    // A number when anybody has promised, the verb when nobody has yet.
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Pray for this'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Encourage'), findsOneWidget);
    // The four walls the server answers for, and no tab for a discussion the
    // API has no endpoint for.
    for (final label in ['All', 'Prayer', 'Testimonies', 'Encouragement']) {
      expect(wallPill(label), findsOneWidget);
    }
    expect(find.text('Discussion'), findsNothing);
  });

  testWidgets('a tab asks the server for only that wall', (tester) async {
    final api = await openWall(tester, posts: [
      post(),
      post(id: 'p2', body: 'God answered before the semester began.', category: 'testimony'),
    ]);

    await tester.tap(wallPill('Testimonies'));
    await tester.pumpAndSettle();

    expect(api.wallsAsked, [null, 'testimony']);
    expect(find.text('God answered before the semester began.'), findsOneWidget);
    expect(find.text('Please pray for my exams this week.'), findsNothing);
  });

  testWidgets('praying for a request moves its own number without reloading the wall', (tester) async {
    final api = await openWall(tester, posts: [post()]);

    await tapCount(tester, '12');

    expect(api.affirmations, [('p1', true)]);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('12'), findsNothing);
    expect(api.wallsAsked, [null]);

    await tapCount(tester, '13');

    expect(api.affirmations, [('p1', true), ('p1', false)]);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('the words under a request are asked for when the card is opened', (tester) async {
    final api = await openWall(
      tester,
      posts: [post(isOwner: false)],
      comments: {
        'p1': [
          word(body: 'I will pray tonight.', id: 'c2', isOwner: true),
          word(body: 'Standing with you.', id: 'c1'),
        ],
      },
    );

    expect(api.commentsCalls, 0);

    await tapCount(tester, '2');

    expect(api.commentsCalls, 1);
    expect(find.text('Standing with you.'), findsOneWidget);
    expect(find.text('I will pray tonight.'), findsOneWidget);
    // Only the writer's own word carries the control the server would accept.
    expect(find.byIcon(AppIcons.delete), findsOneWidget);

    await tapCount(tester, '2');

    expect(find.text('Standing with you.'), findsNothing);
    // Reopening an answer already on screen does not ask again.
    await tapCount(tester, '2');
    expect(api.commentsCalls, 1);
  });

  testWidgets('a word written on the wall goes to the server and onto the top of the list', (tester) async {
    final api = await openWall(
      tester,
      posts: [post()],
      comments: {
        'p1': [word(isOwner: true)],
      },
    );

    await tapCount(tester, '2');
    await tester.enterText(find.descendant(of: find.byType(ListView), matching: find.byType(TextField)), 'Keep standing, Grace.');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(api.added, [('p1', 'Keep standing, Grace.')]);
    expect(find.text('Keep standing, Grace.'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();

    expect(api.removed, [('p1', 'c1')]);
    expect(find.text('Standing with you.'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a request that is not on the wall yet still says where it is waiting', (tester) async {
    final api = await openWall(tester, posts: [
      post(body: 'Pray with me about the interview.', visibility: 'group', moderationState: 'pending', isOwner: true, affirmationCount: 0, commentCount: 0),
    ]);

    expect(find.text('Waiting for review'), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();

    expect(api.deleted, 'p1');
    expect(find.text('Pray with me about the interview.'), findsNothing);
  });

  testWidgets('a visitor reads the wall but is not offered the pen', (tester) async {
    final api = await openWall(tester, posts: [post()], signedIn: false);

    expect(find.text('Please pray for my exams this week.'), findsOneWidget);
    expect(find.text('Write a prayer request'), findsNothing);
    expect(find.text('Sign in to write a private prayer or share one with consent.'), findsOneWidget);

    await tapCount(tester, '12');
    expect(api.affirmations, isEmpty);
    expect(find.text('Sign in required'), findsOneWidget);
    await dismissSnackbars(tester);
  });

  testWidgets('the wall chooses which category a request is written into', (tester) async {
    final api = await openWall(tester);

    await Get.find<CommunityController>().createPrayer(
      body: 'God healed my fear of the viva.',
      visibility: 'public',
      shareConsent: true,
      category: 'testimony',
    );
    await tester.pumpAndSettle();
    await dismissSnackbars(tester);

    expect(api.created?.category, 'testimony');
    expect(api.wallsAsked.length, 2);
  });

  testWidgets('a wall that will not load says so and keeps the rest of the tab', (tester) async {
    final api = await openWall(tester, posts: [post()], wallFailure: const Failure(FailureKind.offline, 'No connection'));

    expect(find.text('We could not load this'), findsNothing);
    expect(find.textContaining('No connection'), findsWidgets);
    expect(api.wallsAsked, [null]);
    // The directory, groups and events were answered before the wall failed,
    // so the other three tabs still have their content.
    expect(find.text('Campus'), findsOneWidget);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      final where = 'on ${size.width.toInt()}dp ${theme.brightness.name}';

      testWidgets('the wall and an open thread lay out $where', (tester) async {
        await openWall(
          tester,
          size: size,
          theme: theme,
          posts: [post(), post(id: 'p2', body: 'God answered before the viva.', category: 'testimony', ownerName: 'A student')],
          comments: {
            'p1': [word(isOwner: true), word(id: 'c2', body: 'Praying tonight from the fellowship.')],
          },
        );

        final controller = Get.find<CommunityController>();
        await controller.toggleComments(controller.wall.first);
        await tester.pumpAndSettle();

        // A screen is only laid out as far as the student has scrolled, so the
        // thread, the field and the second card are walked into view.
        for (var step = 0; step < 6; step++) {
          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pump();
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: '$where could not be laid out');
      });
    }
  }
}

/// What the wall endpoints answer, with every call counted so a test can tell
/// a refetch from an in-place update.
class _WallApi implements UdmApi {
  _WallApi(this.posts);

  List<PrayerPost> posts;
  final List<String?> wallsAsked = [];
  final List<(String, bool)> affirmations = [];
  final Map<String, List<PrayerComment>> commentRows = {};
  final List<(String, String)> added = [];
  final List<(String, String)> removed = [];
  int commentsCalls = 0;
  Failure? wallFailure;
  String? deleted;
  ({String body, String category, String visibility, bool shareConsent})? created;

  @override
  Future<List<PrayerPost>> prayerWall({String? category}) async {
    wallsAsked.add(category);
    if (wallFailure != null) throw wallFailure!;
    return category == null ? posts : posts.where((post) => post.category == category).toList();
  }

  @override
  Future<AffirmationState> setPrayerAffirmation(String prayerId, {required bool on}) async {
    affirmations.add((prayerId, on));
    return AffirmationState(affirmed: on, count: on ? 13 : 12);
  }

  @override
  Future<List<PrayerComment>> prayerComments(String prayerId) async {
    commentsCalls++;
    return commentRows[prayerId] ?? const [];
  }

  @override
  Future<PrayerComment> addPrayerComment(String prayerId, String body) async {
    added.add((prayerId, body));
    final comment = PrayerComment(
      id: 'new${added.length}',
      body: body,
      authorName: 'Grace Nabukeera',
      createdAt: DateTime(2026, 11, 11, 11),
      isOwner: false,
    );
    commentRows[prayerId] = [comment, ...?commentRows[prayerId]];
    return comment;
  }

  @override
  Future<void> removePrayerComment(String prayerId, String commentId) async {
    removed.add((prayerId, commentId));
    commentRows[prayerId] = (commentRows[prayerId] ?? const []).where((row) => row.id != commentId).toList();
  }

  @override
  Future<void> createPrayerRequest({
    required String body,
    required String visibility,
    String? groupId,
    required bool shareConsent,
    String category = 'prayer',
  }) async {
    created = (body: body, category: category, visibility: visibility, shareConsent: shareConsent);
    posts = [
      PrayerPost(
        id: 'p9',
        body: body,
        category: category,
        visibility: visibility,
        moderationState: visibility == 'private' ? 'approved' : 'pending',
        createdAt: DateTime(2026, 11, 11, 12),
        isOwner: true,
        ownerName: 'Grace Nabukeera',
        affirmed: false,
        affirmationCount: 0,
        commentCount: 0,
      ),
      ...posts,
    ];
  }

  @override
  Future<void> deletePrayerRequest(String id) async => deleted = id;

  @override
  Future<List<Map<String, dynamic>>> universities() async => const [
    {'id': 'u1', 'name': 'University of Kampala', 'city': 'Kampala', 'country': 'Uganda'},
  ];

  @override
  Future<List<Map<String, dynamic>>> campuses() async => const [];

  @override
  Future<List<Map<String, dynamic>>> fellowships() async => const [];

  @override
  Future<List<Map<String, dynamic>>> discipleshipGroups() async => const [];

  @override
  Future<List<Map<String, dynamic>>> events() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}
