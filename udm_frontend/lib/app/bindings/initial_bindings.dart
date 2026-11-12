import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/storage/local_cache.dart';
import '../core/storage/token_store.dart';
import '../data/providers/udm_api.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/devotions_repository.dart';
import '../data/repositories/home_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/resources_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../modules/content_version/content_version_controller.dart';
import '../modules/session/session_controller.dart';
import '../modules/settings/app_language_controller.dart';

/// App-wide singletons. Resolved before `runApp` because the cache needs an
/// already-loaded `SharedPreferences` handle.
Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  Get.put<LocalCache>(LocalCache(prefs), permanent: true);
  Get.put<SettingsRepository>(SettingsRepository(Get.find<LocalCache>()), permanent: true);
  Get.put<AppLanguageController>(AppLanguageController(Get.find<SettingsRepository>()), permanent: true);

  final tokens = SecureTokenStore();
  Get.put<TokenStore>(tokens, permanent: true);
  // Giving the client a token store is what makes the whole app authenticated:
  // every request carries the bearer token and refreshes once when it expires.
  Get.put<ApiClient>(
    ApiClient(
      tokenStore: tokens,
      languageCode: () => Get.find<AppLanguageController>().locale.value.languageCode,
    ),
    permanent: true,
  );
  Get.put<UdmApi>(UdmApi(Get.find<ApiClient>()), permanent: true);
  // One watched integer, so a ministry edit reaches a student who has the app
  // open without a restart and without re-downloading the library on every
  // resume. Registered before the repositories that stamp their cache with it.
  Get.put<ContentVersionController>(
    ContentVersionController(Get.find<UdmApi>()),
    permanent: true,
  );
  int? contentVersion() => Get.find<ContentVersionController>().known.value;
  String languageCode() =>
      Get.find<AppLanguageController>().locale.value.languageCode;

  Get.put<HomeRepository>(
    HomeRepository(
      Get.find<UdmApi>(),
      Get.find<LocalCache>(),
      languageCode: languageCode,
      contentVersion: contentVersion,
    ),
    permanent: true,
  );
  Get.put<DevotionsRepository>(
    DevotionsRepository(
      Get.find<UdmApi>(),
      Get.find<LocalCache>(),
      languageCode: languageCode,
      contentVersion: contentVersion,
    ),
    permanent: true,
  );
  Get.put<ContentRepository>(ContentRepository(Get.find<UdmApi>()), permanent: true);
  // The home "Find resources on" guides share the stamping rule the Devotions
  // grid uses, so a ministry edit reaches a cached guide list the same way.
  Get.put<ResourcesRepository>(
    ResourcesRepository(
      Get.find<UdmApi>(),
      Get.find<LocalCache>(),
      languageCode: languageCode,
      contentVersion: contentVersion,
    ),
    permanent: true,
  );
  // The Learn tab's shelves are stamped the same way. A student's note on a
  // recording and their place in it are not cached at all: they are private
  // writing, and the device cache is shared by whoever holds the phone.
  Get.put<MediaRepository>(
    MediaRepository(
      Get.find<UdmApi>(),
      Get.find<LocalCache>(),
      languageCode: languageCode,
      contentVersion: contentVersion,
    ),
    permanent: true,
  );
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
