import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../data/repositories/devotions_repository.dart';
import 'devotion_series_controller.dart';

class DevotionSeriesBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    final id = arguments is Map<String, dynamic>
        ? arguments[RouteArgs.seriesId] as String? ?? ''
        : '';
    Get.lazyPut(
      () => DevotionSeriesController(Get.find<DevotionsRepository>(), id),
    );
  }
}
