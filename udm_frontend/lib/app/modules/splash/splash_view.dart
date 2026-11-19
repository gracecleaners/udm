import 'package:flutter/material.dart';

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
          Positioned.fill(child: BackdropArt(asset: AppArt.splash)),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF5003C9B),
                    Color(0xE80048B4),
                    Color(0x5B0757B9),
                    Color(0xA500347F),
                  ],
                  stops: [0, .44, .72, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),
                const FadeIn(child: _SplashLogo()),
                const SizedBox(height: AppSpacing.md),
                FadeIn(
                  delay: const Duration(milliseconds: 140),
                  child: AppText(
                    'University Discipleship\nMission',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const FadeIn(
                  delay: Duration(milliseconds: 240),
                  child: AppText(
                    'Grow · Learn · Connect · Serve',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                const FadeIn(
                  delay: Duration(milliseconds: 340),
                  child: _SplashDots(),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recreates the supplied UDM lockup in the same cross, open-Bible and wordmark
/// arrangement, without the rounded app-icon tile used on other screens.
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 78,
        height: 58,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            const Icon(Icons.menu_book_rounded, color: Colors.white, size: 68),
            Positioned(
              top: 0,
              child: Container(
                width: 4,
                height: 39,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              top: 9,
              child: Container(
                width: 28,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 3),
      const Text(
        'UDM',
        style: TextStyle(
          color: Colors.white,
          fontSize: 38,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    ],
  );
}

class _SplashDots extends StatelessWidget {
  const _SplashDots();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (index) => Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: index == 2 ? 1 : .55),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}
