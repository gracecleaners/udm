/// Runtime configuration supplied at build time.
///
/// `flutter run --dart-define=UDM_API_BASE_URL=http://192.168.1.20:8000/api/v1`
class AppConfig {
  const AppConfig._();

  /// Android emulators reach the host machine through 10.0.2.2; a physical
  /// device or a desktop/web build needs the machine's LAN address instead.
  static const String apiBaseUrl = String.fromEnvironment(
    'UDM_API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static const Duration requestTimeout = Duration(seconds: 12);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static const String appName = 'UDM';
  static const String tagline = 'Know Christ. Grow in Christ. Make Disciples.';

  static const int onboardingSlideCount = 3;
}
