import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/udm_widgets.dart';
import 'onboarding_controller.dart';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, 0),
              child: Row(
                children: [
                  const UdmLogo(size: 34),
                  const Spacer(),
                  TextButton(
                    onPressed: controller.finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: controller.pager,
                itemCount: OnboardingController.slides.length,
                onPageChanged: (page) => controller.index.value = page,
                itemBuilder: (context, page) {
                  final slide = OnboardingController.slides[page];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.lightBlue, AppColors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(slide.icon, size: 40, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          slide.eyebrow.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primaryBlue),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(slide.title, style: theme.textTheme.displaySmall),
                        const SizedBox(height: AppSpacing.md),
                        Text(slide.body, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
              child: Column(
                children: [
                  Obx(
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        OnboardingController.slides.length,
                        (dot) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 7,
                          width: controller.index.value == dot ? 26 : 7,
                          decoration: BoxDecoration(
                            color: controller.index.value == dot
                                ? AppColors.primaryBlue
                                : AppColors.secondaryText.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Obx(
                        () => TextButton(
                          onPressed: controller.index.value == 0 ? null : controller.previous,
                          child: const Text('Back'),
                        ),
                      ),
                      const Spacer(),
                      Obx(
                        () => FilledButton(
                          onPressed: controller.isLast ? controller.finish : controller.next,
                          child: Text(controller.isLast ? 'Start my journey' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
