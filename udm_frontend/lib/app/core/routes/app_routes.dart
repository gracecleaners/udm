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
  static const String articles = '/articles';
  static const String resourceTopic = '/resource-topic';
  static const String resourceStep = '/resource-step';
  static const String courses = '/courses';
  static const String newBeliever = '/new-believer';
  static const String newBelieverResource = '/new-believer-resource';
  static const String mediaCollection = '/media-collection';
  static const String mediaItem = '/media-item';
  static const String community = '/community';
  static const String verse = '/verse';
  static const String readingHistory = '/reading-history';
  static const String readingDay = '/reading-day';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
}

/// Keys for `Get.arguments` maps, so a caller and its route never drift apart.
abstract class RouteArgs {
  static const String devotionId = 'devotionId';
  static const String seriesId = 'seriesId';
  static const String articleId = 'articleId';
  static const String resourceTopicId = 'resourceTopicId';
  static const String resourceStepId = 'resourceStepId';
  static const String newBelieverResourceId = 'newBelieverResourceId';
  static const String mediaCollectionId = 'mediaCollectionId';
  static const String mediaItemId = 'mediaItemId';

  /// A `VerseFocus`: the one verse a student stopped on, taken to its own
  /// screen whole rather than looked up a second time.
  static const String verse = 'verse';
}
