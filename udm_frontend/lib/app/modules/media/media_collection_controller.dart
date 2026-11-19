import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/media_collection.dart';
import '../../data/models/media_item.dart';
import '../../data/repositories/media_repository.dart';
import '../content_version/content_version_controller.dart';

/// One shelf opened: its recordings in the order the ministry set them, newest
/// first where a recording has no number of its own.
class MediaCollectionController extends GetxController
    with RefetchesOnContentChange {
  MediaCollectionController(this._media, this.collectionId);

  final MediaRepository _media;
  final String collectionId;

  final Rxn<MediaCollection> collection = Rxn<MediaCollection>();
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  bool get isOfflineCopy => collection.value?.fromCache ?? false;

  List<MediaItem> get items => collection.value?.items ?? const [];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  Future<void> load() async {
    if (collection.value == null) {
      final stored = _media.cachedShelf(collectionId);
      if (stored != null) {
        collection.value = stored;
        state.value = ViewState.ready;
        stampLoadedContent(stored.contentVersion);
      }
    }
    failureMessage.value = '';
    try {
      final fresh = await _media.shelf(collectionId);
      collection.value = fresh;
      stampLoadedContent(fresh.contentVersion);
      state.value = ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      // A shelf that stopped being published still has its saved copy on this
      // device, and that is the student's own reading, not a server state.
      if (collection.value != null) {
        state.value = ViewState.ready;
      } else {
        state.value = failure.kind == FailureKind.notFound
            ? ViewState.empty
            : ViewState.error;
      }
    }
  }

  void openItem(MediaItem item) => Get.toNamed(
    AppRoutes.mediaItem,
    arguments: {RouteArgs.mediaItemId: item.id},
  );
}
