import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../data/providers/udm_api.dart';

/// The server's change stamp, watched so the app is never showing content the
/// ministry has already edited.
///
/// A worker saves a devotion in the console; the student's app should show it
/// without a restart and without re-downloading the whole library every time it
/// is opened. `/content-version/` is one integer that answers both: unchanged
/// means the copies on this device are still the copies the server would send,
/// changed means the screens loaded under the older number should refetch.
class ContentVersionController extends GetxController {
  ContentVersionController(this._api);

  final UdmApi _api;
  AppLifecycleListener? _lifecycle;

  /// Null until the server has answered. Deliberately not an observed zero: a
  /// screen must be able to tell "we do not know yet" from "version 0".
  final RxnInt known = RxnInt();

  @override
  void onInit() {
    super.onInit();
    _lifecycle = AppLifecycleListener(onResume: poll);
    poll();
  }

  @override
  void onClose() {
    _lifecycle?.dispose();
    super.onClose();
  }

  /// Never fatal: offline, the app simply keeps the last number it saw.
  ///
  /// Named `poll` rather than `refresh` because GetX already owns `refresh()` on
  /// a controller, and that one notifies listeners instead of asking the server.
  Future<void> poll() async {
    try {
      final version = await _api.contentVersion();
      // Only a real change is published, so a resume with nothing new does not
      // set the whole app refetching.
      if (known.value != version) known.value = version;
    } on Failure {
      return;
    }
  }
}

/// Screens that show ministry content reload themselves when the stamp moves.
///
/// A screen records the version its data was taken under — from the payload it
/// just fetched, or from the cached copy it fell back to. That is what makes the
/// comparison exact: a phone that read version 7 offline refetches the moment
/// the server answers 9, and a phone already on 9 does nothing.
mixin RefetchesOnContentChange on GetxController {
  Worker? _versionWorker;

  /// The stamp of what this screen is currently showing.
  final RxnInt loadedUnder = RxnInt();

  /// Each screen's own reload, already written for pull-to-refresh.
  Future<void> load();

  @override
  void onInit() {
    super.onInit();
    _versionWorker = ever(
      Get.find<ContentVersionController>().known,
      _settleFor,
    );
  }

  @override
  void onClose() {
    _versionWorker?.dispose();
    super.onClose();
  }

  void _settleFor(int? serverVersion) {
    if (serverVersion == null) return;
    if (loadedUnder.value == null) {
      // This screen fetched before the stamp was known; what it just downloaded
      // is the server's current copy, so adopt the number rather than refetch.
      loadedUnder.value = serverVersion;
      return;
    }
    if (serverVersion != loadedUnder.value) load();
  }

  /// Call after every load, with the stamp the data carries (a cached copy
  /// keeps the stamp it was saved under).
  void stampLoadedContent(int? version) => loadedUnder.value = version;

  /// For screens whose cached rows carry no stamp of their own: the number the
  /// server was on a moment ago is the number this fetch returned.
  void stampCurrentContent() =>
      stampLoadedContent(Get.find<ContentVersionController>().known.value);
}
