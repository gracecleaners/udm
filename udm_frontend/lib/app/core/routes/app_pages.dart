import 'package:get/get.dart';

import '../../modules/article/article_binding.dart';
import '../../modules/article/article_view.dart';
import '../../modules/article/articles_binding.dart';
import '../../modules/article/articles_view.dart';
import '../../modules/auth/auth_binding.dart';
import '../../modules/auth/register_view.dart';
import '../../modules/auth/sign_in_view.dart';
import '../../modules/bible/verse_detail_view.dart';
import '../../modules/community/community_binding.dart';
import '../../modules/community/community_view.dart';
import '../../modules/devotion/devotion_binding.dart';
import '../../modules/devotion/devotion_view.dart';
import '../../modules/devotions/devotion_series_binding.dart';
import '../../modules/devotions/devotion_series_view.dart';
import '../../modules/media/media_collection_binding.dart';
import '../../modules/media/media_collection_view.dart';
import '../../modules/media/media_item_binding.dart';
import '../../modules/media/media_item_view.dart';
import '../../modules/onboarding/onboarding_binding.dart';
import '../../modules/onboarding/onboarding_view.dart';
import '../../modules/profile/reading_history_binding.dart';
import '../../modules/profile/reading_history_view.dart';
import '../../modules/resources/courses_binding.dart';
import '../../modules/resources/courses_view.dart';
import '../../modules/resources/resource_step_binding.dart';
import '../../modules/resources/resource_step_view.dart';
import '../../modules/resources/resource_topic_binding.dart';
import '../../modules/resources/resource_topic_view.dart';
import '../../modules/settings/settings_view.dart';
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
      name: AppRoutes.signIn,
      page: () => const SignInView(),
      binding: SignInBinding(),
      transition: Transition.upToDown,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const RegisterView(),
      binding: RegisterBinding(),
      transition: Transition.upToDown,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.devotion,
      page: () => const DevotionView(),
      binding: DevotionBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.devotionSeries,
      page: () => const DevotionSeriesView(),
      binding: DevotionSeriesBinding(),
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
    GetPage(
      name: AppRoutes.articles,
      page: () => const ArticlesView(),
      binding: ArticlesBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.resourceTopic,
      page: () => const ResourceTopicView(),
      binding: ResourceTopicBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.resourceStep,
      page: () => const ResourceStepView(),
      binding: ResourceStepBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.courses,
      page: () => const CoursesView(),
      binding: CoursesBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.newBeliever,
      page: () => const CoursesView(newBelieverMode: true),
      binding: CoursesBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.readingHistory,
      page: () => const ReadingHistoryView(),
      binding: ReadingHistoryBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    // No binding: every choice on this screen already lives in a controller the
    // app keeps for the whole run — the light, the reading size, the language.
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.mediaCollection,
      page: () => const MediaCollectionView(),
      binding: MediaCollectionBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.mediaItem,
      page: () => const MediaItemView(),
      binding: MediaItemBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    GetPage(
      name: AppRoutes.community,
      page: () => const CommunityView(),
      binding: CommunityBinding(),
      transition: Transition.rightToLeft,
      transitionDuration: transitionDuration,
    ),
    // No binding: a verse is opened from scripture the student is already
    // reading, so the Bible controller that served that chapter is still on
    // the deck and owns the bookmarks and notes it is asked to write.
    GetPage(
      name: AppRoutes.verse,
      page: () => const VerseDetailView(),
      transition: Transition.fadeIn,
      transitionDuration: transitionDuration,
    ),
  ];
}
