import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../data/repositories/media_repository.dart';
import 'media_collection_controller.dart';

class MediaCollectionBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    final id = arguments is Map<String, dynamic>
        ? arguments[RouteArgs.mediaCollectionId] as String? ?? ''
        : '';
    Get.lazyPut(() => MediaCollectionController(Get.find<MediaRepository>(), id));
  }
}
