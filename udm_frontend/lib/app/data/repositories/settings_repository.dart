import '../../core/storage/local_cache.dart';

/// Persistent device-level choices. Kept separate from account data so the app
/// behaves the same before sign-in.
class SettingsRepository {
  SettingsRepository(this._cache);

  final LocalCache _cache;

  static const String onboardingCompleteKey = 'udm.onboarding.complete';

  bool get hasSeenOnboarding => _cache.flag(onboardingCompleteKey);

  Future<void> completeOnboarding() => _cache.setFlag(onboardingCompleteKey, true);

  Future<void> restartOnboarding() => _cache.remove(onboardingCompleteKey);
}
