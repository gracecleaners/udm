/// Named routes only; no screen is reached by a raw path string.
abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String shell = '/feed';
  static const String signIn = '/sign-in';
  static const String register = '/register';
  static const String devotion = '/devotion';
  static const String article = '/article';
}

/// Keys for `Get.arguments` maps, so a caller and its route never drift apart.
abstract class RouteArgs {
  static const String devotionId = 'devotionId';
  static const String articleId = 'articleId';
}
