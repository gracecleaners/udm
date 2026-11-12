import 'package:get/get.dart';
import '../settings/app_language_controller.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/resource_step.dart';
import '../../data/models/resource_topic.dart';
import '../../data/repositories/resources_repository.dart';
import '../content_version/content_version_controller.dart';

/// One guide opened: its steps in the order they are meant to be worked
/// through, the unnumbered starting point first.
class ResourceTopicController extends GetxController with RefetchesOnContentChange {
  ResourceTopicController(this._resources, this.topicId);

  final ResourcesRepository _resources;
  final String topicId;
  Worker? _languageWorker;

  final Rxn<ResourceTopic> topic = Rxn<ResourceTopic>();
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  bool get isOfflineCopy => topic.value?.fromCache ?? false;

  List<ResourceStep> get steps => topic.value?.steps ?? const [];

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
    if (topic.value == null) {
      final stored = _resources.cachedTopic(topicId);
      if (stored != null) {
        topic.value = stored;
        state.value = ViewState.ready;
        stampLoadedContent(stored.contentVersion);
      }
    }
    failureMessage.value = '';
    try {
      final fresh = await _resources.topic(topicId);
      topic.value = fresh;
      stampLoadedContent(fresh.contentVersion);
      state.value = ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      // A guide that stopped being published still has its saved copy on this
      // device, and that is the student's own reading, not a server state.
      if (topic.value != null) {
        state.value = ViewState.ready;
      } else {
        state.value = failure.kind == FailureKind.notFound
            ? ViewState.empty
            : ViewState.error;
      }
    }
  }

  void openStep(ResourceStep step) => Get.toNamed(
    AppRoutes.resourceStep,
    arguments: {RouteArgs.resourceStepId: step.id},
  );
}
