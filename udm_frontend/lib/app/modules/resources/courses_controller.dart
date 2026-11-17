import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/resource_topic.dart';
import '../../data/repositories/resources_repository.dart';
import '../content_version/content_version_controller.dart';

/// The Courses screen: the ministry's guided reads, with where this student is
/// in each one.
///
/// The numbers come from the server, which counts the steps of every live
/// guide against the student's own history in one pass. A visitor sees the
/// guides and their lengths and no progress, which is the truth rather than an
/// empty bar.
class CoursesController extends GetxController with RefetchesOnContentChange {
  CoursesController(this._resources);

  final ResourcesRepository _resources;

  final RxList<ResourceTopic> topics = <ResourceTopic>[].obs;
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  bool get isOfflineCopy => topics.isNotEmpty && topics.first.fromCache;

  /// Started guides first: a student coming back to a course should not have to
  /// find it in a list the ministry ordered for somebody else.
  List<ResourceTopic> get started =>
      topics.where((topic) => topic.stepsCompleted > 0).toList();

  List<ResourceTopic> get untouched =>
      topics.where((topic) => topic.stepsCompleted == 0).toList();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  Future<void> load() async {
    if (topics.isEmpty) {
      final stored = _resources.cachedTopics();
      if (stored != null) {
        topics.assignAll(stored);
        if (stored.isNotEmpty) state.value = ViewState.ready;
        stampLoadedContent(stored.isEmpty ? null : stored.first.contentVersion);
      }
    }
    failureMessage.value = '';
    try {
      final fresh = await _resources.topics();
      topics.assignAll(fresh);
      stampLoadedContent(fresh.isEmpty ? null : fresh.first.contentVersion);
      state.value = fresh.isEmpty ? ViewState.empty : ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      if (topics.isEmpty) state.value = ViewState.error;
    }
  }

  void open(ResourceTopic topic) => Get.toNamed(
    AppRoutes.resourceTopic,
    arguments: {RouteArgs.resourceTopicId: topic.id},
  );
}
