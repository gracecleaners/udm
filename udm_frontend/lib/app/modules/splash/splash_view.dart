import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/language_menu_button.dart';
import '../../core/widgets/udm_widgets.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.scripture),
        child: Stack(
          children: [
            Positioned.fill(child: Mark.backdrop(tint: AppColors.white, alpha: 0.16)),
            SafeArea(
              child: Stack(
                children: [
                  const Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: _GhostLanguageMenu(),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FadeIn(
                          child: _BrandMark(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FadeIn(
                          delay: const Duration(milliseconds: 140),
                          child: AppText(
                            'University Discipleship Mission',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.white,
                                  letterSpacing: 0.6,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FadeIn(
                          delay: const Duration(milliseconds: 240),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                            child: AppText(
                              'Know Christ. Grow in Christ. Make Disciples.',
                              textAlign: TextAlign.center,
                              style: AppTypography.scriptureReference(Colors.white70).copyWith(fontSize: 15.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl + AppSpacing.md),
                        const FadeIn(
                          delay: Duration(milliseconds: 340),
                          child: _LoadingRule(),
                        ),
                      ],
                    ),
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

/// The mark on the gradient needs its own light ring, so it is not the flat
/// `UdmLogo` tile used on white surfaces.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 116,
        height: 116,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.4),
        ),
        child: const Center(child: Mark(size: 78, icon: AppIcons.bookOpen)),
      );
}

/// A thin gold rule that sweeps while the session is restored — the brand
/// equivalent of a spinner, and honest about waiting without a second widget.
class _LoadingRule extends StatelessWidget {
  const _LoadingRule();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 120,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          child: LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
        ),
      );
}

class _GhostLanguageMenu extends StatelessWidget {
  const _GhostLanguageMenu();

  @override
  Widget build(BuildContext context) => const LanguageMenuButton(onDark: true);
}
