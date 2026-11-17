/// The ministry's own pictures, named once.
///
/// Only the opening screen and the three onboarding slides are carried in the
/// build: they paint before any request comes back, so the first thing a fresh
/// device shows cannot depend on the network. Every other surface — a devotion,
/// an article, a verse, a recording — takes its artwork from the ministry
/// console, where staff either upload a file or paste a link to one, and shows
/// the brand gradient when they have not chosen either yet.
class AppArt {
  const AppArt._();

  static const String splash = 'assets/images/splash.jpg';

  static const String onboardingWord = 'assets/images/onboard_word.png';
  static const String onboardingHabits = 'assets/images/onboard_habits.png';
  static const String onboardingCommunity = 'assets/images/onboard_community.png';
}
