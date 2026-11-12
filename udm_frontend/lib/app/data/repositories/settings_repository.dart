import '../../core/storage/local_cache.dart';

/// Persistent device-level choices. Kept separate from account data so the app
/// behaves the same before sign-in.
class SettingsRepository {
  SettingsRepository(this._cache);

  final LocalCache _cache;

  static const String onboardingCompleteKey = 'udm.onboarding.complete';
  static const String languageKey = 'udm.app.language';

  bool get hasSeenOnboarding => _cache.flag(onboardingCompleteKey);

  Future<void> completeOnboarding() => _cache.setFlag(onboardingCompleteKey, true);

  Future<void> restartOnboarding() => _cache.remove(onboardingCompleteKey);

  String get languageCode => _cache.readString(languageKey) ?? 'en';

  Future<void> setLanguageCode(String code) => _cache.writeString(languageKey, code);
}
