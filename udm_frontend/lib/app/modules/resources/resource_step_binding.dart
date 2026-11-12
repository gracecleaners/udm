import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../data/repositories/content_repository.dart';
import '../session/session_controller.dart';
import 'resource_step_controller.dart';

class ResourceStepBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    final id = arguments is Map<String, dynamic>
        ? arguments[RouteArgs.resourceStepId] as String? ?? ''
        : '';
    Get.lazyPut(
      () => ResourceStepController(
        Get.find<ContentRepository>(),
        Get.find<SessionController>(),
        id,
      ),
    );
  }
}
