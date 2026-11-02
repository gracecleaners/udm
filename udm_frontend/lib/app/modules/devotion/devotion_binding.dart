import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../data/repositories/content_repository.dart';
import 'devotion_controller.dart';

class DevotionBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    final id = arguments is Map<String, dynamic> ? arguments[RouteArgs.devotionId] as String : '';
    Get.lazyPut(() => DevotionController(Get.find<ContentRepository>(), id));
  }
}
