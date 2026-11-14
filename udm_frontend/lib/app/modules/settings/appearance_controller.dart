import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/settings_repository.dart';

/// One step of the reading size the student can pick for scripture.
///
/// The app offers a handful of named steps rather than a slider: a slider
/// gives fifty sizes, and only a few of them are ones the reading cards were
/// proofed to hold.
class ReadingSize {
  const ReadingSize(this.label, this.scale);

  final String label;
  final double scale;
}

/// Device-level looks: light or dark, and how large the reading text is.
///
/// Deliberately not on the account. A shared family phone can be dark for one
/// student and light for the next, and neither choice is data the ministry
/// should be storing.
class AppearanceController extends GetxController {
  AppearanceController(this._settings);

  final SettingsRepository _settings;

  final Rx<ThemeMode> mode = ThemeMode.system.obs;
  final RxDouble readingScale = 1.0.obs;

  static const List<ReadingSize> readingSizes = [
    ReadingSize('Small', 0.9),
    ReadingSize('Medium', 1.0),
    ReadingSize('Large', 1.15),
    ReadingSize('Extra large', 1.3),
  ];

  @override
  void onInit() {
    mode.value = switch (_settings.themeModeCode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    readingScale.value = _settings.readingScale;
    _publishScale();
    super.onInit();
  }

  /// The step whose scale the student is on, or the middle step when the
  /// stored value came from a release that offered different ones.
  ReadingSize get readingSize =>
      readingSizes.firstWhereOrNull((size) => size.scale == readingScale.value) ?? readingSizes[1];

  /// A design size run through the student's choice, for the surfaces that set
  /// their type from this controller and so can follow the change on the frame
  /// it happens. Everything else is sized by `AppTypography.readingScale`.
  double scaled(double base) => base * readingScale.value;

  void _publishScale() => AppTypography.readingScale = readingScale.value;

  Future<void> selectMode(ThemeMode selected) async {
    mode.value = selected;
    await _settings.setThemeModeCode(switch (selected) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> selectReadingSize(ReadingSize size) async {
    readingScale.value = size.scale;
    _publishScale();
    await _settings.setReadingScale(size.scale);
  }
}
