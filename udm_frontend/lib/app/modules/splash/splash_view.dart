import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_art.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/udm_widgets.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The whole opening screen is one photograph with the brand written on
          // it, so the app's first impression is the ministry's own art rather
          // than a gradient. The gradient stays underneath: a first launch
          // paints before the asset decodes, and a dark photo needs the scrim
          // to keep white text legible on any phone.
          const ColoredBox(color: AppColors.darkInk),
          Positioned.fill(child: BackdropArt(asset: AppArt.splash)),
          const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.scrim))),
          Positioned.fill(child: Mark.backdrop(tint: AppColors.white, alpha: 0.10)),
          SafeArea(
            child: Stack(
              children: [
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
                            AppConfig.tagline,
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
