import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/devotion_series.dart';
import '../../data/models/devotional.dart';
import '../../data/repositories/devotions_repository.dart';
import '../content_version/content_version_controller.dart';

/// The Devotions tab: the day's reading, then the ministry's reading series.
class DevotionsController extends GetxController with RefetchesOnContentChange {
  DevotionsController(this._devotions);

  final DevotionsRepository _devotions;

  final RxList<DevotionSeries> series = <DevotionSeries>[].obs;
  final RxList<Devotional> feed = <Devotional>[].obs;
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  bool get isOfflineCopy => series.isNotEmpty && series.first.fromCache;

  /// The page to read today: the server lists devotionals newest first, so the
  /// first row is the ministry's most recent word rather than the app's guess.
  Devotional? get todays => feed.isEmpty ? null : feed.first;

  /// What sits behind today's page, newest next.
  List<Devotional> get more => feed.length < 2 ? const [] : feed.sublist(1);

  @override
  void onInit() {
    super.onInit();
    load();
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
    await loadFeed();
    // A tab holding the day's reading is not an empty tab: the notice is only
    // honest once neither the devotionals nor the library has a row.
    if (state.value == ViewState.empty && feed.isNotEmpty) {
      state.value = ViewState.ready;
    }
  }

  /// The day's page and the ones behind it. A failure here is not the tab
  /// failing: the saved library still reads underneath, so the most recent
  /// devotionals simply stay undrawn until the next connection.
  Future<void> loadFeed() async {
    if (feed.isEmpty) {
      final stored = _devotions.cachedDevotionals();
      if (stored != null) feed.assignAll(stored);
    }
    try {
      feed.assignAll(await _devotions.devotionals());
    } on Failure {
      // What this device saved is still the ministry's own text, so it stays.
    }
  }

  void openDevotion(Devotional item) => Get.toNamed(
    AppRoutes.devotion,
    arguments: {RouteArgs.devotionId: item.id},
  );

  void openSeries(DevotionSeries item) => Get.toNamed(
    AppRoutes.devotionSeries,
    arguments: {RouteArgs.seriesId: item.id},
  );
}
