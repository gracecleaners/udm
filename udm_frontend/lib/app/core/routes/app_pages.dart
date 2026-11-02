import 'package:get/get.dart';

import '../../modules/article/article_binding.dart';
import '../../modules/article/article_view.dart';
import '../../modules/devotion/devotion_binding.dart';
import '../../modules/devotion/devotion_view.dart';
import '../../modules/onboarding/onboarding_binding.dart';
import '../../modules/onboarding/onboarding_view.dart';
import '../../modules/shell/shell_binding.dart';
import '../../modules/shell/shell_view.dart';
import '../../modules/splash/splash_binding.dart';
import '../../modules/splash/splash_view.dart';
import 'app_routes.dart';

abstract class AppPages {
  static const Duration transitionDuration = Duration(milliseconds: 260);

  static final List<GetPage<void>> pages = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: AppRoutes.shell,
      page: () => const ShellView(),
      binding: ShellBinding(),
    ),
    GetPage(
      name: AppRoutes.devotion,
      page: () => const DevotionView(),
      binding: DevotionBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.article,
      page: () => const ArticleView(),
      binding: ArticleBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
  ];
}
