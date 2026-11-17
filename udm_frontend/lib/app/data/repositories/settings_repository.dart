import '../../core/storage/local_cache.dart';

/// Persistent device-level choices. Kept separate from account data so the app
/// behaves the same before sign-in.
class SettingsRepository {
  SettingsRepository(this._cache);

  final LocalCache _cache;

  static const String onboardingCompleteKey = 'udm.onboarding.complete';
  static const String themeModeKey = 'udm.app.themeMode';
  static const String readingScaleKey = 'udm.app.readingScale';

  bool get hasSeenOnboarding => _cache.flag(onboardingCompleteKey);

  Future<void> completeOnboarding() => _cache.setFlag(onboardingCompleteKey, true);

  Future<void> restartOnboarding() => _cache.remove(onboardingCompleteKey);

  /// How the app should follow the light. The device default is system: a
  /// student who never opened Settings still gets what their phone asks for.
  String get themeModeCode => _cache.readString(themeModeKey) ?? 'system';

  Future<void> setThemeModeCode(String code) => _cache.writeString(themeModeKey, code);

  /// Text size for scripture and reading bodies, as a multiplier. Stored as a
  /// string because the cache layer only promises primitives it can stamp.
  double get readingScale {
    final saved = double.tryParse(_cache.readString(readingScaleKey) ?? '');
    // A damaged or out-of-range value falls back to the size the design was
    // proofed at rather than an unreadable screen.
    if (saved == null || saved < 0.8 || saved > 1.6) return 1;
    return saved;
  }

  Future<void> setReadingScale(double scale) =>
      _cache.writeString(readingScaleKey, scale.toStringAsFixed(2));
}
