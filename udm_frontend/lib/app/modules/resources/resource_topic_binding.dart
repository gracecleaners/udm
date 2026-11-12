import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../data/repositories/resources_repository.dart';
import 'resource_topic_controller.dart';

class ResourceTopicBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    final id = arguments is Map<String, dynamic>
        ? arguments[RouteArgs.resourceTopicId] as String? ?? ''
        : '';
    Get.lazyPut(() => ResourceTopicController(Get.find<ResourcesRepository>(), id));
  }
}
