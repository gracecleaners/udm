/// Named routes only; no screen is reached by a raw path string.
abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String shell = '/feed';
  static const String signIn = '/sign-in';
  static const String register = '/register';
  static const String devotion = '/devotion';
  static const String devotionSeries = '/devotion-series';
  static const String article = '/article';
  static const String resourceTopic = '/resource-topic';
  static const String resourceStep = '/resource-step';
  static const String mediaCollection = '/media-collection';
  static const String mediaItem = '/media-item';
}

/// Keys for `Get.arguments` maps, so a caller and its route never drift apart.
abstract class RouteArgs {
  static const String devotionId = 'devotionId';
  static const String seriesId = 'seriesId';
  static const String articleId = 'articleId';
  static const String resourceTopicId = 'resourceTopicId';
  static const String resourceStepId = 'resourceStepId';
  static const String mediaCollectionId = 'mediaCollectionId';
  static const String mediaItemId = 'mediaItemId';
}
