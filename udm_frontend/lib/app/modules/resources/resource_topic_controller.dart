import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/resource_step.dart';
import '../../data/models/resource_topic.dart';
import '../../data/repositories/resources_repository.dart';
import '../content_version/content_version_controller.dart';
import 'resource_pdf_view.dart';

/// One guide opened: its steps in the order they are meant to be worked
/// through, the unnumbered starting point first.
class ResourceTopicController extends GetxController
    with RefetchesOnContentChange {
  ResourceTopicController(this._resources, this.topicId);

  final ResourcesRepository _resources;
  final String topicId;

  final Rxn<ResourceTopic> topic = Rxn<ResourceTopic>();
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  bool get isOfflineCopy => topic.value?.fromCache ?? false;

  List<ResourceStep> get steps => topic.value?.steps ?? const [];

  @override
  void onInit() {
    super.onInit();
    load();
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

  /// The tick on a step row is the server's answer, and the page this student
  /// just left is where they may have changed it, so the guide is asked again
  /// on the way back rather than left showing the list they walked in on.
  Future<void> openStep(ResourceStep step) async {
    await Get.toNamed(
      AppRoutes.resourceStep,
      arguments: {RouteArgs.resourceStepId: step.id},
    );
    load();
  }

  Future<void> openPdf() async {
    final url = topic.value?.pdfUrl ?? '';
    if (url.isEmpty) {
      Get.snackbar(
        'PDF unavailable',
        'The ministry has not uploaded a PDF for this resource yet.',
      );
      return;
    }
    try {
      final resource = topic.value!;
      final views = await _resources.registerView(topicId);
      topic.value = ResourceTopic(
        id: resource.id,
        title: resource.title,
        summary: resource.summary,
        imageUrl: resource.imageUrl,
        pdfUrl: resource.pdfUrl,
        order: resource.order,
        stepCount: resource.stepCount,
        views: views,
        stepsCompleted: resource.stepsCompleted,
        steps: resource.steps,
        contentVersion: resource.contentVersion,
      );
    } catch (_) {
      // A view counter is helpful metadata, never a reason to block reading.
    }
    Get.to(() => ResourcePdfView(loadPdf: () => _resources.downloadPdf(url)));
  }
}
