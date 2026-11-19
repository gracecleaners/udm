/// The ministry's own pictures, named once.
///
/// Opening, onboarding, and profile identity art are bundled so they paint
/// before any request comes back. Content surfaces such as devotions, articles,
/// verses, and recordings take their artwork from the ministry console.
class AppArt {
  const AppArt._();

  static const String splash = 'assets/images/splash.jpg';

  /// The ministry's own lockup: cross, open Bible and wordmark in one white
  /// artwork. Screens draw this instead of composing a mark from icons.
  static const String logoLockup = 'assets/images/udm_logo_white.png';

  /// The same mark without the wordmark, for tiles, discs and avatars.
  static const String logoMark = 'assets/images/udm_mark_white.png';

  static const String onboardingWord = 'assets/images/onboard_word.png';
  static const String onboardingHabits = 'assets/images/onboard_habits.png';
  static const String onboardingCommunity = 'assets/images/onboard_community.png';
  static const String profileCrossBanner = 'assets/images/profile_cross_banner.jpg';
}
