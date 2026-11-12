import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/models/home_payload.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/home/home_controller.dart';
import 'package:udm_frontend/app/modules/home/home_view.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';

import '../support/fakes.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<void> pumpHome(WidgetTester tester, HomeController controller) async {
    Get.put<ContentVersionController>(FakeContentVersionController(), permanent: true);
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
          GetPage(name: AppRoutes.resourceTopic, page: () => const Center(child: Text('GUIDE SCREEN'))),
          GetPage(name: AppRoutes.signIn, page: () => const Center(child: Text('SIGN IN SCREEN'))),
          GetPage(name: AppRoutes.register, page: () => const Center(child: Text('REGISTER SCREEN'))),
        ],
        home: const HomeView(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The feed is a lazy list and the test font is far wider than the bundled
  /// one, so the day's cards start below the fold. Reach them the way a
  /// student would: scroll, then look.
  Future<void> scrollToCard(WidgetTester tester, Finder finder) async {
    await tester.dragUntilVisible(finder, find.byType(ListView), const Offset(0, -200));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  /// GetX keeps a snackbar in a queue that only frees its job once the bar has
  /// finished closing, and the bar's auto-dismiss timer outlives the widget
  /// tree. A case that saw a bar gives it away here, or the next case is left
  /// with a pending timer and a queue that will not show its own message.
  Future<void> dismissSnackbars(WidgetTester tester) async {
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  }

  testWidgets('renders the server-curated verse, devotion and articles', (tester) async {
    await pumpHome(tester, HomeController(FakeHomeRepository(payload: sampleHome()), fakeSession()));

    expect(find.text('Good morning, Grace'), findsOneWidget);
    expect(find.textContaining('Be not conformed to this world.'), findsOneWidget);
    await scrollToCard(tester, find.text('A Heart That Listens'));
    expect(find.text('A Heart That Listens'), findsOneWidget);
    await scrollToCard(tester, find.text('How to Study a Chapter'));
    expect(find.text('How to Study a Chapter'), findsOneWidget);
    expect(find.text('Offline copy'), findsNothing);
  });

  testWidgets('opening the devotion really navigates to the reader', (tester) async {
    await pumpHome(tester, HomeController(FakeHomeRepository(payload: sampleHome()), fakeSession()));

    final devotionCard = find.text('A Heart That Listens');
    await scrollToCard(tester, devotionCard);
    await tester.tap(devotionCard.first);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.devotion);
    expect(find.text('DEVOTION SCREEN'), findsOneWidget);
  });

  testWidgets('cached content is labelled offline, never silently stale', (tester) async {
    await pumpHome(tester, HomeController(FakeHomeRepository(payload: sampleHome().asCached()), fakeSession()));

    expect(find.text('Offline copy'), findsWidgets);
  });

  testWidgets('a failed first load offers a working retry', (tester) async {
    final repository = FakeHomeRepository(failure: const Failure(FailureKind.offline, 'No connection'));
    await pumpHome(tester, HomeController(repository, fakeSession()));

    expect(find.text('We could not load this'), findsOneWidget);

    repository
      ..failure = null
      ..payload = sampleHome();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    await scrollToCard(tester, find.text('A Heart That Listens'));
    expect(find.text('A Heart That Listens'), findsOneWidget);
  });

  testWidgets('the card a student memorises is the memory verse', (tester) async {
    await pumpHome(tester, HomeController(FakeHomeRepository(payload: sampleHome()), fakeSession()));

    expect(find.text('MEMORY VERSE'), findsOneWidget);
    // The old label promised whatever the server happened to pick for the day;
    // this one is the verse the ministry chose for memorising.
    expect(find.text('VERSE OF THE DAY'), findsNothing);
  });

  testWidgets('the guides are listed in the order the ministry set', (tester) async {
    await pumpHome(tester, HomeController(FakeHomeRepository(payload: sampleHome()), fakeSession()));

    await scrollToCard(tester, find.text('Find resources on'));
    expect(find.text('Find resources on'), findsOneWidget);
    expect(find.text('GUIDED READING'), findsOneWidget);
    expect(find.text('Receive Christ'), findsOneWidget);
    expect(
      find.text('Short guides for the questions students actually ask'),
      findsOneWidget,
    );
    // A guide is offered by what it holds, so the count the server dares to
    // promise is on the row.
    expect(find.text('5 steps'), findsWidgets);
    expect(find.text('3 steps'), findsOneWidget);
  });

  testWidgets('a guide row really opens that guide', (tester) async {
    await pumpHome(tester, HomeController(FakeHomeRepository(payload: sampleHome()), fakeSession()));

    final row = find.text('New Believer');
    await scrollToCard(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.resourceTopic);
    expect(find.text('GUIDE SCREEN'), findsOneWidget);
  });

  testWidgets('a home with no guides published shows no resources section', (tester) async {
    final payload = HomePayload(
      greeting: 'Good morning',
      devotion: sampleHome().devotion,
      articles: sampleHome().articles,
      resources: const [],
    );
    await pumpHome(tester, HomeController(FakeHomeRepository(payload: payload), fakeSession()));

    expect(find.text('Find resources on'), findsNothing);
  });

  testWidgets('marking the verse memorized goes to the account, not the device', (tester) async {
    final repository = FakeHomeRepository(payload: sampleHome());
    await pumpHome(tester, HomeController(repository, fakeSession(signedIn: true)));

    final button = find.byKey(const Key('udm.markMemorized'));
    await scrollToCard(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(repository.memorized, ['v1']);
    // The card answers with the server's copy: the action is replaced by the
    // mark, so the same verse cannot be counted twice by accident.
    expect(find.text('Memorized'), findsOneWidget);
    expect(find.byKey(const Key('udm.markMemorized')), findsNothing);
    expect(find.text('Saved'), findsOneWidget);

    await dismissSnackbars(tester);
  });

  testWidgets('a signed out student signs in before the verse is kept', (tester) async {
    final repository = FakeHomeRepository(payload: sampleHome());
    await pumpHome(tester, HomeController(repository, fakeSession()));

    final button = find.byKey(const Key('udm.markMemorized'));
    await scrollToCard(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.signIn);
    expect(repository.memorized, isEmpty);
  });

  testWidgets('a review the server refused says so and leaves the card alone', (tester) async {
    final repository = FakeHomeRepository(
      payload: sampleHome(),
      memorizeFailure: const Failure(FailureKind.offline, 'No connection to the UDM service.'),
    );
    await pumpHome(tester, HomeController(repository, fakeSession(signedIn: true)));

    final button = find.byKey(const Key('udm.markMemorized'));
    await scrollToCard(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(repository.memorized, isEmpty);
    expect(find.text('Could not save review'), findsOneWidget);
    // Nothing was pretended: the verse is still one to mark.
    expect(find.text('Memorized'), findsNothing);
    expect(find.byKey(const Key('udm.markMemorized')), findsOneWidget);

    await dismissSnackbars(tester);
  });
}
