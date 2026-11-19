import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/failure.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/content_kind.dart';
import '../../data/models/new_believer_resource.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/resources_repository.dart';
import '../reader/reading_progress.dart';
import '../session/session_controller.dart';

class NewBelieverResourceController extends GetxController
    with TracksReadingProgress {
  NewBelieverResourceController(
    this._resources,
    this._content,
    this._session,
    this.resourceId,
  );

  final ResourcesRepository _resources;
  final ContentRepository _content;
  final SessionController _session;
  final String resourceId;

  @override
  ContentRepository get content => _content;

  @override
  SessionController get session => _session;

  @override
  ContentKind get progressKind => ContentKind.newBeliever;

  @override
  String get progressId => resourceId;

  final Rxn<NewBelieverResource> resource = Rxn<NewBelieverResource>();
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
      resource.value = await _resources.newBelieverResource(resourceId);
      state.value = ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      state.value = failure.kind == FailureKind.notFound
          ? ViewState.empty
          : ViewState.error;
    }
  }

  Future<void> openVideo() async {
    final rawUrl = resource.value?.videoUrl ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      Get.snackbar('Video unavailable', 'This resource has no safe video link.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        Get.snackbar('Video unavailable', 'No app could open this video.');
      }
    } on Exception {
      Get.snackbar('Video unavailable', 'No app could open this video.');
    }
  }
}
