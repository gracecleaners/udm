import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
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
                    child: const AppText('Skip'),
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
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, 0),
                    child: LayoutBuilder(
                      builder: (context, bounds) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: bounds.maxHeight),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: (bounds.maxHeight * 0.56).clamp(150.0, 420.0),
                                child: _SlideArt(slide: slide, page: page),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              AppText(
                                slide.title,
                                style: theme.textTheme.displaySmall,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AppText(
                                slide.body,
                                style: AppTypography.scriptureBody(
                                  theme.textTheme.bodyLarge?.color ?? AppColors.darkText,
                                ).copyWith(fontSize: 16.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.lg),
              child: Column(
                children: [
                  Obx(
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        OnboardingController.slides.length,
                        (dot) => AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 7,
                          width: controller.index.value == dot ? 28 : 7,
                          decoration: BoxDecoration(
                            gradient: controller.index.value == dot ? AppGradients.hero : null,
                            color: controller.index.value == dot
                                ? null
                                : (theme.textTheme.bodySmall?.color ?? AppColors.secondaryText)
                                    .withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
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
                          child: const AppText('Back'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Obx(
                          () => FilledButton.icon(
                            onPressed: controller.isLast ? controller.finish : controller.next,
                            icon: Icon(controller.isLast ? AppIcons.target : AppIcons.next, size: 19),
                            label: AppText(controller.isLast ? 'Get Started' : 'Next'),
                          ),
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

/// The scene a slide is remembered by: the ministry's own drawing, the line it
/// carries, and where the student is in the set.
class _SlideArt extends StatelessWidget {
  const _SlideArt({required this.slide, required this.page});

  final OnboardingSlide slide;
  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
        boxShadow: AppShadows.float,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropArt(
            asset: slide.art,
            errorBuilder: (context, error, stack) =>
                Mark.backdrop(tint: AppColors.white, alpha: 0.16),
          ),
          // The drawing is light, so the words sit on the brand's own scrim
          // rather than on whatever the picture happens to put there.
          const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.scrimSide))),
          PositionedDirectional(
            top: AppSpacing.md,
            start: AppSpacing.md,
            end: AppSpacing.md,
            child: AppText(
              slide.eyebrow,
              style: AppTypography.scriptureReference(Colors.white.withValues(alpha: 0.92))
                  .copyWith(fontSize: 16),
            ),
          ),
          PositionedDirectional(
            bottom: AppSpacing.md,
            start: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: AppText(
                '${page + 1} / ${OnboardingController.slides.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
