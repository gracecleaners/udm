import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../data/repositories/settings_repository.dart';

class OnboardingSlide {
  const OnboardingSlide(this.icon, this.eyebrow, this.title, this.body);

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
}

class OnboardingController extends GetxController {
  OnboardingController(this._settings);

  static const List<OnboardingSlide> slides = [
    OnboardingSlide(
      Icons.menu_book_rounded,
      'Know Christ',
      'Scripture you actually finish',
      'Read a licensed Bible, take today\'s devotion, and memorise a verse. Notes and highlights stay yours.',
    ),
    OnboardingSlide(
      Icons.smart_display_rounded,
      'Grow in Christ',
      'Discipleship, not downloads',
      'Work through the ministry\'s teaching recordings, write what each one '
          'brought you, and follow a guided resource on the questions you '
          'actually ask.',
    ),
    OnboardingSlide(
      Icons.send_rounded,
      'Make Disciples',
      'Sent to your campus',
      'Share a teaching with a friend, work through a guide with someone new '
          'to the faith, and keep a verse ready for the day they ask you why.',
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
