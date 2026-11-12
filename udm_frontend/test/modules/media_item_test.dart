import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/models/media_item.dart';
import 'package:udm_frontend/app/data/repositories/media_repository.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/media/media_item_binding.dart';
import 'package:udm_frontend/app/modules/media/media_item_controller.dart';
import 'package:udm_frontend/app/modules/media/media_item_view.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';

import '../support/fakes.dart';

/// One recording opened: the ministry's link and write-up, and the two things
/// that belong to the student alone — what they wrote about it and where they
/// stopped. Both are read from the server when the page opens and written back
/// to it, never to this device.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  /// A run has no WebView behind the embedded frame, so these cases stand for a
  /// build without an inline player: the page hands the recording to YouTube
  /// and says so. The platform is set for the body and given back at the end of
  /// it, which is where the framework checks.
  void testRecording(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body(tester);
        // GetX runs its snackbars through a queue that only frees a job once the
        // bar finishes its closing animation, and the bar's auto-dismiss timer
        // outlives the tree. Both would hold the next case hostage, so every bar
        // is dismissed and animated away here.
        Get.closeAllSnackbars();
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Future<FakeMediaRepository> pumpRecording(
    WidgetTester tester, {
    MediaItem? row,
    Failure? failure,
    bool signedIn = false,
  }) async {
    final repository = FakeMediaRepository(itemRow: row, failure: failure);
    Get.put<MediaRepository>(repository, permanent: true);
    Get.put<ContentVersionController>(FakeContentVersionController(), permanent: true);
    Get.put<SessionController>(fakeSession(signedIn: signedIn), permanent: true);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(
            name: AppRoutes.mediaItem,
            page: () => const MediaItemView(),
            binding: MediaItemBinding(),
          ),
          GetPage(
            name: AppRoutes.signIn,
            page: () => const Center(child: Text('SIGN IN SCREEN')),
          ),
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Get.toNamed(
                  AppRoutes.mediaItem,
                  arguments: {RouteArgs.mediaItemId: 'm1'},
                ),
                child: const Text('OPEN RECORDING'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN RECORDING'));
    await tester.pumpAndSettle();
    return repository;
  }

  /// The page's controller, once the binding has built the page.
  MediaItemController controller() => Get.find<MediaItemController>();

  /// The recording is a scrolling list and the test font is wider than the
  /// shipped one, so the note and the sign-in line below it are not even built
  /// until a student reaches them.
  Future<void> reach(WidgetTester tester, Finder finder) async {
    await tester.dragUntilVisible(finder, find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
  }

  testRecording('the page is the ministry\'s recording and its write-up', (tester) async {
    await pumpRecording(tester, row: sampleRecording());

    expect(find.text('True faith sides with God | Hebrews 11:29-31'), findsOneWidget);
    expect(find.text('Edgar Karuma'), findsOneWidget);
    expect(find.text('15:40'), findsOneWidget);
    expect(
      find.text('Hebrews 11 is not a list of heroes. It is a list of listeners.'),
      findsOneWidget,
    );
    // The body is the staff's prose, in its own paragraphs.
    expect(find.text('Moses chose the people over the palace.'), findsOneWidget);
    expect(find.text('Faith sides with God before it understands why.'), findsOneWidget);
    expect(find.text('This build has no video engine for the inline player.'), findsOneWidget);
    expect(find.text('Play on YouTube'), findsOneWidget);
  });

  testRecording('Download appears only for a file the ministry hosts', (tester) async {
    await pumpRecording(tester, row: sampleRecording());

    // A YouTube recording may not be downloaded under its terms, so the button
    // a student cannot honestly use is not drawn.
    expect(find.byKey(const Key('udm.downloadRecording')), findsNothing);
    expect(find.text('Download'), findsNothing);
    expect(find.byKey(const Key('udm.shareRecording')), findsOneWidget);
  });

  testRecording('a file the ministry distributes itself is offered as one', (tester) async {
    await pumpRecording(
      tester,
      row: sampleRecording(
        youtubeVideoId: null,
        downloadUrl: 'https://files.udm.ac.ug/media/soma-01.mp3',
      ),
    );

    expect(find.byKey(const Key('udm.downloadRecording')), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    // There is still something to send: the ministry's own address.
    expect(find.byKey(const Key('udm.shareRecording')), findsOneWidget);
  });

  testRecording('a recording nobody has attached yet is the page it says it is', (tester) async {
    await pumpRecording(tester, row: sampleRecording(youtubeVideoId: null));

    expect(
      find.text(
        'The ministry has not put this recording online yet. Its write-up is here to read, and the teaching arrives as soon as staff attach it.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('udm.shareRecording')), findsNothing);
    expect(find.byKey(const Key('udm.downloadRecording')), findsNothing);
  });

  testRecording('marking watched is stored by the server, and un-marking is too', (tester) async {
    final repository = await pumpRecording(tester, row: sampleRecording(), signedIn: true);

    await tester.tap(find.byKey(const Key('udm.markWatched')));
    await tester.pumpAndSettle();

    // Finishing a recording stores the end of it, not wherever the frame was.
    expect(repository.savedWatches.single.completed, isTrue);
    expect(repository.savedWatches.single.positionSeconds, 940);
    expect(find.text('Watched'), findsOneWidget);

    await tester.tap(find.text('Watched'));
    await tester.pumpAndSettle();

    expect(repository.savedWatches.last.completed, isFalse);
    expect(find.text('Mark watched'), findsOneWidget);
  });

  testRecording('a signed out student is taken to sign in before anything is kept', (tester) async {
    final repository = await pumpRecording(tester, row: sampleRecording());

    await tester.tap(find.byKey(const Key('udm.markWatched')));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.signIn);
    expect(find.text('SIGN IN SCREEN'), findsOneWidget);
    expect(repository.savedWatches, isEmpty);
  });

  testRecording('a signed out page says what is waiting on an account', (tester) async {
    await pumpRecording(tester, row: sampleRecording());

    final waiting = find.text('Sign in to keep your notes and your place in a recording.');
    await reach(tester, waiting);

    expect(waiting, findsOneWidget);
  });

  testRecording('a signed in page does not offer what the student already has', (tester) async {
    await pumpRecording(tester, row: sampleRecording(), signedIn: true);

    expect(
      find.text('Sign in to keep your notes and your place in a recording.'),
      findsNothing,
    );
  });

  testRecording('a note is written to the server and read back from it', (tester) async {
    final repository = await pumpRecording(
      tester,
      row: sampleRecording(note: 'Faith sides before it understands why.'),
      signedIn: true,
    );

    final kept = find.text('Faith sides before it understands why.');
    await reach(tester, kept);
    expect(kept, findsOneWidget);
    expect(find.text('YOUR NOTE'), findsOneWidget);

    await reach(tester, find.byKey(const Key('udm.takeNote')));
    await tester.tap(find.byKey(const Key('udm.takeNote')));
    await tester.pumpAndSettle();

    // The field opens with what the server holds, so the student edits their
    // own note rather than starting it again.
    final field = find.byKey(const Key('udm.noteField'));
    await reach(tester, field);
    expect(tester.widget<TextField>(field).controller!.text,
        'Faith sides before it understands why.');

    await tester.enterText(field, 'He listened first.');
    await tester.tap(find.byKey(const Key('udm.saveNote')));
    await tester.pumpAndSettle();

    // It went to the server and nowhere else.
    expect(repository.savedNotes.single.id, 'm1');
    expect(repository.savedNotes.single.text, 'He listened first.');
    expect(find.text('He listened first.'), findsOneWidget);
    expect(find.text('Note saved'), findsOneWidget);
  });

  testRecording('clearing the field deletes the note', (tester) async {
    final repository = await pumpRecording(
      tester,
      row: sampleRecording(note: 'Faith sides before it understands why.'),
      signedIn: true,
    );

    await reach(tester, find.byKey(const Key('udm.takeNote')));
    await tester.tap(find.byKey(const Key('udm.takeNote')));
    await tester.pumpAndSettle();

    final remove = find.byKey(const Key('udm.deleteNote'));
    await reach(tester, remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();

    expect(repository.savedNotes.single.text, '');
    expect(find.text('Note deleted'), findsOneWidget);
    expect(find.text('Faith sides before it understands why.'), findsNothing);
    expect(find.text('YOUR NOTE'), findsNothing);
  });

  testRecording('a note the server refused says so instead of pretending', (tester) async {
    final repository = await pumpRecording(tester, row: sampleRecording(), signedIn: true);
    repository.noteFailure = const Failure(
      FailureKind.offline,
      'No connection to the UDM service.',
    );

    await reach(tester, find.byKey(const Key('udm.takeNote')));
    await tester.tap(find.byKey(const Key('udm.takeNote')));
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('udm.noteField'));
    await reach(tester, field);
    await tester.enterText(field, 'Anything at all');
    await tester.tap(find.byKey(const Key('udm.saveNote')));
    await tester.pumpAndSettle();

    expect(repository.savedNotes, isEmpty);
    expect(find.text('No connection to the UDM service.'), findsOneWidget);
    // The typing is not thrown away with the failure.
    expect(controller().noteDraft.value, 'Anything at all');
  });

  testRecording('where the student stopped is stored when the page closes', (tester) async {
    final repository = await pumpRecording(tester, row: sampleRecording(), signedIn: true);

    controller().recordPosition(240);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(repository.savedWatches.single.positionSeconds, 240);
    expect(repository.savedWatches.single.completed, isFalse);
  });

  testRecording('a recording nobody started leaves nothing behind', (tester) async {
    final repository = await pumpRecording(tester, row: sampleRecording(), signedIn: true);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(repository.savedWatches, isEmpty);
  });

  testRecording('a finished recording does not store a place', (tester) async {
    final repository = await pumpRecording(
      tester,
      row: sampleRecording(watched: true),
      signedIn: true,
    );

    controller().recordPosition(500);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(repository.savedWatches, isEmpty);
  });

  testRecording('the page says where the student stopped', (tester) async {
    await pumpRecording(tester, row: sampleRecording(resumeAt: 180), signedIn: true);

    expect(
      find.text('Continuing from 3:00. Press play where you stopped.'),
      findsOneWidget,
    );
  });

  testRecording('a watched recording resumes from the beginning', (tester) async {
    await pumpRecording(
      tester,
      row: sampleRecording(watched: true, resumeAt: 180),
      signedIn: true,
    );

    expect(find.textContaining('Continuing from'), findsNothing);
    expect(find.text('Watched'), findsOneWidget);
  });

  testRecording('a saved recording reads offline without another student\'s state', (tester) async {
    await pumpRecording(
      tester,
      row: sampleRecording().asCached(),
      failure: const Failure(FailureKind.offline, 'No connection to the UDM service.'),
      signedIn: true,
    );

    expect(find.text('True faith sides with God | Hebrews 11:29-31'), findsOneWidget);
    expect(find.text('Offline copy of this recording'), findsOneWidget);
    expect(find.text('We could not load this'), findsNothing);
    // The private half waits on a connection: the copy on the device never
    // carried a note or a place in it.
    expect(find.text('YOUR NOTE'), findsNothing);
    expect(find.textContaining('Continuing from'), findsNothing);
  });

  testRecording('a recording that stopped being published says so', (tester) async {
    await pumpRecording(
      tester,
      failure: const Failure(FailureKind.notFound, 'We could not find that.'),
    );

    expect(find.text('Recording unavailable'), findsOneWidget);
    expect(find.text('This recording is no longer published.'), findsOneWidget);
  });

  testRecording('a ministry edit reloads the page while it is open', (tester) async {
    // The page needs the number its copy was taken under, which is what a
    // dated payload gives it: an undated copy cannot be compared.
    final repository = await pumpRecording(
      tester,
      row: sampleRecording().withCacheStamp(DateTime.utc(2026, 11, 10), version: 4),
      signedIn: true,
    );

    repository.itemRow = sampleRecording()
        .withCacheStamp(DateTime.utc(2026, 11, 12), version: 99)
        .copyWith(title: 'Why faith waited');
    (Get.find<ContentVersionController>() as FakeContentVersionController).emit(99);
    await tester.pumpAndSettle();

    expect(find.text('Why faith waited'), findsOneWidget);
  });
}
