import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/media_collection.dart';
import '../../data/models/resume_item.dart';
import '../../data/repositories/media_repository.dart';
import '../content_version/content_version_controller.dart';
import '../session/session_controller.dart';

/// The Learn tab: the ministry's teaching recordings.
///
/// There are no courses here. A course is a guided read and lives under
/// Courses; this tab is what the staff publish on the ministry's YouTube
/// channel — SOMA, Uliza, the podcast — as rows they write and reorder in the
/// console, so the tab is not a fixed set of buttons.
class LearnController extends GetxController with RefetchesOnContentChange {
  LearnController(this._media, this.session);

  final MediaRepository _media;
  final SessionController session;

  final RxList<MediaCollection> shelves = <MediaCollection>[].obs;
  final Rxn<MediaCollection> featuredShelf = Rxn<MediaCollection>();
  final RxList<ResumeItem> resume = <ResumeItem>[].obs;
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  bool get isOfflineCopy => shelves.isNotEmpty && shelves.first.fromCache;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Cached shelves go up first when there is nothing on screen yet, so a
  /// returning student sees their library instead of a spinner; the network
  /// copy replaces it as soon as it arrives.
  @override
  Future<void> load() async {
    if (shelves.isEmpty) {
      final stored = _media.cachedShelves();
      if (stored != null) {
        shelves.assignAll(stored);
        if (stored.isNotEmpty) state.value = ViewState.ready;
        stampLoadedContent(stored.isEmpty ? null : stored.first.contentVersion);
      }
    }
    failureMessage.value = '';
    try {
      final fresh = await _media.shelves();
      shelves.assignAll(fresh);
      stampLoadedContent(fresh.isEmpty ? null : fresh.first.contentVersion);
      state.value = fresh.isEmpty ? ViewState.empty : ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      if (shelves.isEmpty) state.value = ViewState.error;
    }
    await loadFeaturedShelf();
    await loadPrivate();
    // A recording the student is still watching is something to show even when
    // the staff have nothing published on a shelf, so the empty notice has to
    // wait for both answers.
    if (state.value == ViewState.empty && resume.isNotEmpty) {
      state.value = ViewState.ready;
    }
  }

  Future<void> loadFeaturedShelf() async {
    if (shelves.isEmpty) {
      featuredShelf.value = null;
      return;
    }
    final fallback = shelves.first;
    try {
      featuredShelf.value = await _media.shelf(fallback.id);
    } on Failure {
      featuredShelf.value = fallback;
    }
  }

  /// Where this student is in the recordings. Their own row, so an empty list
  /// for a signed-out visitor is the whole truth rather than a missing section.
  Future<void> loadPrivate() async {
    if (!session.isSignedIn) {
      resume.clear();
      return;
    }
    try {
      resume.assignAll(
        (await _media.resume()).where((item) => item.hasStarted),
      );
    } on Failure {
      resume.clear();
    }
  }

  void openShelf(MediaCollection shelf) => Get.toNamed(
    AppRoutes.mediaCollection,
    arguments: {RouteArgs.mediaCollectionId: shelf.id},
  );

  void openRecording(ResumeItem item) => Get.toNamed(
    AppRoutes.mediaItem,
    arguments: {RouteArgs.mediaItemId: item.id},
  );

  void openFeatured() {
    final shelf = featuredShelf.value;
    if (shelf == null) return;
    if (shelf.items.isNotEmpty) {
      Get.toNamed(
        AppRoutes.mediaItem,
        arguments: {RouteArgs.mediaItemId: shelf.items.first.id},
      );
    } else {
      openShelf(shelf);
    }
  }
}
