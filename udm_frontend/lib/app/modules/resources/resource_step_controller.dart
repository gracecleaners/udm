import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/localized_snackbar.dart';
import '../../core/network/failure.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/content_kind.dart';
import '../../data/models/resource_step.dart';
import '../../data/repositories/content_repository.dart';
import '../reader/reading_progress.dart';
import '../session/session_controller.dart';

/// One step of a guide, read and marked finished like any other reading.
class ResourceStepController extends GetxController with TracksReadingProgress {
  ResourceStepController(this._content, this._session, this.stepId);

  final ContentRepository _content;
  final SessionController _session;
  final String stepId;

  @override
  ContentRepository get content => _content;

  @override
  SessionController get session => _session;

  @override
  ContentKind get progressKind => ContentKind.resourceStep;

  @override
  String get progressId => stepId;

  final Rxn<ResourceStep> step = Rxn<ResourceStep>();
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    state.value = ViewState.loading;
    failureMessage.value = '';
    try {
      step.value = await _content.resourceStep(stepId);
      state.value = ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      state.value = failure.kind == FailureKind.notFound ? ViewState.empty : ViewState.error;
    }
  }

  /// The video is a link the ministry curated, opened by the device's own
  /// browser. Nothing plays in-app, so an absent or unsafe link shows no
  /// control rather than one that fails.
  Future<void> openVideo() async {
    final rawUrl = step.value?.videoUrl ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      showLocalizedSnackbar('Video unavailable', 'This step has no safe video link.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        showLocalizedSnackbar('Video unavailable', 'No app could open this video.');
      }
    } on Exception {
      showLocalizedSnackbar('Video unavailable', 'No app could open this video.');
    }
  }
}
