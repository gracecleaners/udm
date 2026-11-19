import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/media_item.dart';
import '../../data/repositories/media_repository.dart';
import '../content_version/content_version_controller.dart';
import '../session/session_controller.dart';

/// One recording: the player, the ministry's write-up of the teaching, and this
/// student's own note and place in it.
///
/// The note and the place are the student's, so they are read from the server
/// when the page opens and written back when it closes. Nothing about them is
/// kept on the device, which is what lets a shared phone stay private.
class MediaItemController extends GetxController
    with RefetchesOnContentChange {
  MediaItemController(this._media, this.session, this.itemId);

  final MediaRepository _media;
  final SessionController session;
  final String itemId;

  final Rxn<MediaItem> item = Rxn<MediaItem>();
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  /// Where the player has got to, kept here rather than only in the frame so a
  /// long recording can be picked up again on another visit.
  final RxInt positionSeconds = 0.obs;
  final RxBool savingWatch = false.obs;
  final RxString watchMessage = ''.obs;

  final RxBool noteEditorOpen = false.obs;
  final RxString noteDraft = ''.obs;
  final RxBool savingNote = false.obs;
  final RxString noteMessage = ''.obs;

  bool get isOfflineCopy => item.value?.fromCache ?? false;

  /// Whether this student can leave anything behind. Public content stays
  /// readable without an account; a note and a place need one to belong to.
  bool get keepsPrivateState => session.isSignedIn;

  bool get watched => item.value?.watched ?? false;

  int get resumeAt => watched ? 0 : (item.value?.resumeAt ?? 0);

  bool get hasResumePoint => resumeAt > 0;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    // Leaving the page is the moment the student's place in the recording is
    // worth storing — not every second of playback.
    _flushPosition();
    super.onClose();
  }

  @override
  Future<void> load() async {
    if (item.value == null) {
      final stored = _media.cachedItem(itemId);
      if (stored != null) {
        item.value = stored;
        state.value = ViewState.ready;
        stampLoadedContent(stored.contentVersion);
      }
    }
    failureMessage.value = '';
    try {
      final fresh = await _media.item(itemId);
      item.value = fresh;
      // The server's copy answers the student's own state. A draft still open
      // in the editor is theirs and is not replaced by a background refetch.
      if (!noteEditorOpen.value) noteDraft.value = fresh.note;
      stampLoadedContent(fresh.contentVersion);
      state.value = ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      // A recording that stopped being published still has its saved copy on
      // this device — its description is the student's own reading notes, while
      // the note and the place in it wait for a connection.
      if (item.value != null) {
        state.value = ViewState.ready;
      } else {
        state.value = failure.kind == FailureKind.notFound
            ? ViewState.empty
            : ViewState.error;
      }
    }
  }

  /// Reported by the player as the recording moves on.
  void recordPosition(int seconds) {
    if (seconds < 0) return;
    positionSeconds.value = seconds;
  }

  Future<void> markWatched() => _writeWatch(completed: true);

  /// Un-marking is a real action, not a cosmetic toggle: the recording goes back
  /// on the list as one still to finish.
  Future<void> undoWatched() => _writeWatch(completed: false);

  Future<void> _writeWatch({required bool completed}) async {
    if (!session.isSignedIn) {
      Get.toNamed(AppRoutes.signIn);
      return;
    }
    if (savingWatch.value) return;
    savingWatch.value = true;
    watchMessage.value = '';
    final current = item.value;
    try {
      final saved = await _media.saveWatch(
        itemId,
        positionSeconds: completed
            ? (current?.durationSeconds ?? positionSeconds.value)
            : positionSeconds.value,
        completed: completed,
      );
      item.value =
          current?.copyWith(watched: saved.completed, resumeAt: saved.positionSeconds);
      if (!saved.completed) positionSeconds.value = saved.positionSeconds;
    } on Failure catch (failure) {
      watchMessage.value = failure.message;
    } finally {
      savingWatch.value = false;
    }
  }

  /// Blank text deletes the note on the server, which is what the student
  /// means by clearing the field.
  Future<void> saveNote() async {
    if (!session.isSignedIn) {
      Get.toNamed(AppRoutes.signIn);
      return;
    }
    if (savingNote.value) return;
    savingNote.value = true;
    noteMessage.value = '';
    try {
      final saved = await _media.saveNote(itemId, noteDraft.value);
      item.value = item.value?.copyWith(note: saved.text, noteUpdatedAt: saved.updatedAt);
      noteDraft.value = saved.text;
      if (saved.text.isEmpty) {
        noteEditorOpen.value = false;
        Get.snackbar('Note deleted', 'Your note on this recording is gone.');
      } else {
        noteEditorOpen.value = false;
        Get.snackbar('Note saved', 'Kept on your account, for you alone.');
      }
    } on Failure catch (failure) {
      noteMessage.value = failure.message;
    } finally {
      savingNote.value = false;
    }
  }

  void openNoteEditor() {
    if (!session.isSignedIn) {
      Get.toNamed(AppRoutes.signIn);
      return;
    }
    noteEditorOpen.value = !noteEditorOpen.value;
  }

  /// Sends the recording on to whichever app the student chooses — a message,
  /// an email, a study group. Only the ministry's own public address is shared.
  Future<void> share() async {
    final current = item.value;
    final url = current?.shareUrl ?? '';
    if (current == null || url.isEmpty) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${current.title} — UDM ${current.collectionTitle}\n$url',
        ),
      );
    } on Exception {
      Get.snackbar(
        'Could not share',
        'No sharing app answered. Copy the link from YouTube instead.',
      );
    }
  }

  /// Hands the ministry-hosted file to the device's own downloader, which is
  /// where a recording meant to be kept belongs.
  Future<void> download() async {
    final url = item.value?.downloadUrl ?? '';
    if (url.isEmpty) return;
    try {
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) {
        Get.snackbar(
          'Could not open the file',
          'No app on this device can take this download.',
        );
      }
    } on Exception {
      Get.snackbar(
        'Could not open the file',
        'No app on this device can take this download.',
      );
    }
  }

  Future<void> _flushPosition() async {
    if (!session.isSignedIn) return;
    final current = item.value;
    final seconds = positionSeconds.value;
    // Nothing to store for a recording that was never started, and nothing for
    // one already finished: its place is behind the completion mark.
    if (current == null || current.watched || seconds <= 0) return;
    if (current.resumeAt == seconds) return;
    try {
      await _media.saveWatch(itemId, positionSeconds: seconds, completed: false);
    } on Failure {
      // Losing a place in a recording is not worth an error the student cannot
      // act on: they were leaving the page, and the next open starts from the
      // last place the server does know.
      return;
    }
  }
}
