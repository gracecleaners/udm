import 'package:get/get.dart';
import '../settings/app_language_controller.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/devotion_day.dart';
import '../../data/models/devotion_series.dart';
import '../../data/repositories/devotions_repository.dart';
import '../content_version/content_version_controller.dart';

/// One series opened: its days in reading order, Introduction first.
class DevotionSeriesController extends GetxController
    with RefetchesOnContentChange {
  DevotionSeriesController(this._devotions, this.seriesId);

  final DevotionsRepository _devotions;
  final String seriesId;
  Worker? _languageWorker;

  final Rxn<DevotionSeries> series = Rxn<DevotionSeries>();
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  bool get isOfflineCopy => series.value?.fromCache ?? false;

  List<DevotionDay> get days => series.value?.days ?? const [];

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

  @override
  Future<void> load() async {
    if (series.value == null) {
      final stored = _devotions.cachedSeries(seriesId);
      if (stored != null) {
        series.value = stored;
        state.value = ViewState.ready;
        stampLoadedContent(stored.contentVersion);
      }
    }
    failureMessage.value = '';
    try {
      final fresh = await _devotions.series(seriesId);
      series.value = fresh;
      stampLoadedContent(fresh.contentVersion);
      state.value = ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      // A series that stopped being published still has its saved copy on this
      // device, and that is the student's own reading, not a server state.
      if (series.value != null) {
        state.value = ViewState.ready;
      } else {
        state.value = failure.kind == FailureKind.notFound
            ? ViewState.empty
            : ViewState.error;
      }
    }
  }

  void openDay(DevotionDay day) => Get.toNamed(
    AppRoutes.devotion,
    arguments: {RouteArgs.devotionId: day.id},
  );
}
