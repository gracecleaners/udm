import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../data/repositories/media_repository.dart';
import '../session/session_controller.dart';
import 'media_item_controller.dart';

class MediaItemBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    final id = arguments is Map<String, dynamic>
        ? arguments[RouteArgs.mediaItemId] as String? ?? ''
        : '';
    Get.lazyPut(
      () => MediaItemController(
        Get.find<MediaRepository>(),
        Get.find<SessionController>(),
        id,
      ),
    );
  }
}
