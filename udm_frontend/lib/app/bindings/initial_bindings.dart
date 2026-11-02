import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/storage/local_cache.dart';
import '../data/providers/udm_api.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/home_repository.dart';
import '../data/repositories/settings_repository.dart';

/// App-wide singletons. Resolved before `runApp` because the cache needs an
/// already-loaded `SharedPreferences` handle.
Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  Get.put<LocalCache>(LocalCache(prefs), permanent: true);
  Get.put<SettingsRepository>(SettingsRepository(Get.find<LocalCache>()), permanent: true);
  Get.put<ApiClient>(ApiClient(), permanent: true);
  Get.put<UdmApi>(UdmApi(Get.find<ApiClient>()), permanent: true);
  Get.put<HomeRepository>(
    HomeRepository(Get.find<UdmApi>(), Get.find<LocalCache>()),
    permanent: true,
  );
  Get.put<ContentRepository>(ContentRepository(Get.find<UdmApi>()), permanent: true);
}

void clearDependencies() {
  Get.reset();
}
