import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_art.dart';
import '../../data/repositories/settings_repository.dart';

class OnboardingSlide {
  const OnboardingSlide(this.eyebrow, this.title, this.body, this.art);

  final String eyebrow;
  final String title;
  final String body;

  /// The scene drawn for this slide, bundled so the set reads the same with no
  /// signal.
  final String art;
}

class OnboardingController extends GetxController {
  OnboardingController(this._settings);

  static const List<OnboardingSlide> slides = [
    OnboardingSlide(
      'Know Christ',
      'Grow Deeper in God\'s Word',
      'Discover timeless truth and find guidance for everyday life.',
      AppArt.onboardingWord,
    ),
    OnboardingSlide(
      'Grow in Christ',
      'Build Consistent Spiritual Habits',
      'Pray, read, and grow in your faith through simple daily practices.',
      AppArt.onboardingHabits,
    ),
    OnboardingSlide(
      'Make Disciples',
      'Connect with a Faith Community',
      'Walk together in Christ and encourage one another as you grow.',
      AppArt.onboardingCommunity,
    ),
  ];

  final SettingsRepository _settings;
  final PageController pager = PageController();
  final RxInt index = 0.obs;

  bool get isLast => index.value == slides.length - 1;

  @override
  void onClose() {
    pager.dispose();
    super.onClose();
  }

  void goTo(int page) {
    if (page < 0 || page >= slides.length) return;
    index.value = page;
    pager.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void next() => goTo(isLast ? index.value : index.value + 1);

  void previous() => goTo(index.value - 1);

  Future<void> finish() async {
    await _settings.completeOnboarding();
    Get.offAllNamed(AppRoutes.shell);
  }
}
