import 'package:get/get.dart';
import '../settings/app_language_controller.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/devotion_series.dart';
import '../../data/repositories/devotions_repository.dart';
import '../content_version/content_version_controller.dart';

/// The Devotions tab: the ministry's reading series, two to a row.
class DevotionsController extends GetxController with RefetchesOnContentChange {
  DevotionsController(this._devotions);

  final DevotionsRepository _devotions;
  Worker? _languageWorker;

  final RxList<DevotionSeries> series = <DevotionSeries>[].obs;
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  bool get isOfflineCopy => series.isNotEmpty && series.first.fromCache;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<AppLanguageController>()) {
      _languageWorker = ever(Get.find<AppLanguageController>().locale, (_) => load());
    }
    load();
  }

  @override
  void onClose() {
    _languageWorker?.dispose();
    super.onClose();
  }

  /// Cached rows go up first when there is nothing on screen yet, so a returning
  /// student sees their library instead of a spinner; the network copy replaces
  /// it as soon as it arrives.
  @override
  Future<void> load() async {
    if (series.isEmpty) {
      final stored = _devotions.cachedGrid();
      if (stored != null) {
        series.assignAll(stored);
        if (stored.isNotEmpty) state.value = ViewState.ready;
        stampLoadedContent(stored.isEmpty ? null : stored.first.contentVersion);
      }
    }
    failureMessage.value = '';
    try {
      final fresh = await _devotions.grid();
      series.assignAll(fresh);
      stampLoadedContent(fresh.isEmpty ? null : fresh.first.contentVersion);
      state.value = fresh.isEmpty ? ViewState.empty : ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      if (series.isEmpty) state.value = ViewState.error;
    }
  }

  void openSeries(DevotionSeries item) => Get.toNamed(
    AppRoutes.devotionSeries,
    arguments: {RouteArgs.seriesId: item.id},
  );
}
