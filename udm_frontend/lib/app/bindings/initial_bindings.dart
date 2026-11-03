import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/storage/local_cache.dart';
import '../core/storage/token_store.dart';
import '../data/providers/udm_api.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/home_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../modules/session/session_controller.dart';

/// App-wide singletons. Resolved before `runApp` because the cache needs an
/// already-loaded `SharedPreferences` handle.
Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  Get.put<LocalCache>(LocalCache(prefs), permanent: true);
  Get.put<SettingsRepository>(SettingsRepository(Get.find<LocalCache>()), permanent: true);

  final tokens = SecureTokenStore();
  Get.put<TokenStore>(tokens, permanent: true);
  // Giving the client a token store is what makes the whole app authenticated:
  // every request carries the bearer token and refreshes once when it expires.
  Get.put<ApiClient>(ApiClient(tokenStore: tokens), permanent: true);
  Get.put<UdmApi>(UdmApi(Get.find<ApiClient>()), permanent: true);
  Get.put<HomeRepository>(
    HomeRepository(Get.find<UdmApi>(), Get.find<LocalCache>()),
    permanent: true,
  );
  Get.put<ContentRepository>(ContentRepository(Get.find<UdmApi>()), permanent: true);
  Get.put<AuthRepository>(
    AuthRepository(Get.find<UdmApi>(), tokens, Get.find<LocalCache>()),
    permanent: true,
  );
  // Permanent: the session survives navigation, and an expired token has to
  // reach one object that owns the signed-in state.
  Get.put<SessionController>(
    SessionController(Get.find<AuthRepository>(), Get.find<ApiClient>()),
    permanent: true,
  );
}

void clearDependencies() {
  Get.reset();
}
