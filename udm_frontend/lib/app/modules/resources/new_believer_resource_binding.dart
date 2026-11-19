import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/resources_repository.dart';
import '../session/session_controller.dart';
import 'new_believer_resource_controller.dart';

class NewBelieverResourceBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    final id = arguments is Map<String, dynamic>
        ? arguments[RouteArgs.newBelieverResourceId] as String? ?? ''
        : '';
    Get.lazyPut(
      () => NewBelieverResourceController(
        Get.find<ResourcesRepository>(),
        Get.find<ContentRepository>(),
        Get.find<SessionController>(),
        id,
      ),
    );
  }
}
