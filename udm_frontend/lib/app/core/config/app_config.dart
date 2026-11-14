/// Runtime configuration supplied at build time.
///
/// The API this build talks to is chosen with `--dart-define-from-file`, so one
/// flag switches a run between servers without a URL on the command line:
///
/// ```
/// flutter run   --dart-define-from-file=config/api.local.json    # this machine
/// flutter run   --dart-define-from-file=config/api.emulator.json # an emulator
/// flutter build apk --release --dart-define-from-file=config/api.aws.json
/// ```
///
/// The default below is the ministry's deployed server, because that is what a
/// plain `flutter run` is for: a build with no flags should show students the
/// content the ministry actually publishes. Point it at a `runserver` with the
/// first line above.
class AppConfig {
  const AppConfig._();

  /// The server this build reads. `config/` holds the named targets; the default
  /// is the deployed API.
  ///
  /// Plain http is accepted by debug builds only — the release manifest refuses
  /// an insecure origin, so a deployed server needs TLS before a release build
  /// can read it. A phone on USB can reach a local `runserver` without any
  /// address at all: `adb reverse tcp:8000 tcp:8000` forwards the phone's own
  /// `localhost` to it, and an Android emulator reaches the host through
  /// `10.0.2.2`, which is what `config/api.emulator.json` carries.
  static const String apiBaseUrl = String.fromEnvironment(
    'UDM_API_BASE_URL',
    defaultValue: 'http://16.171.149.175/api/v1',
  );

  static const Duration requestTimeout = Duration(seconds: 12);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static const String appName = 'UDM';
  static const String tagline = 'Know Christ. Grow in Christ. Make Disciples.';

  static const int onboardingSlideCount = 3;
}
