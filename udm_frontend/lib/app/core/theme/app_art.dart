/// The ministry's own pictures, named once.
///
/// These are the scenes the app paints before any request comes back — the
/// opening screen, the three onboarding slides and the standing verse backdrops
/// a card uses when the server has no picture for the item in front of it.
/// Everything a student is shown that comes from the server arrives as a URL
/// uploaded by staff, so it is never in here.
class AppArt {
  const AppArt._();

  static const String splash = 'assets/images/splash.jpg';

  /// Sunrise over the hill, for a verse about light or a new morning.
  static const String verseSunrise = 'assets/images/verse_sunrise.jpg';

  /// The cross on the hill at dusk, for a verse about the cross or endurance.
  static const String verseCross = 'assets/images/verse_cross.jpg';

  /// A teaching in progress, behind the Learn tab's opening card.
  static const String teachingAction = 'assets/images/teaching_action.jpg';

  /// The seasons card: a path through changing light.
  static const String devotionalSeason = 'assets/images/devotional_season.jpg';

  static const String onboardingWord = 'assets/images/onboard_word.png';
  static const String onboardingHabits = 'assets/images/onboard_habits.png';
  static const String onboardingCommunity = 'assets/images/onboard_community.png';
}
