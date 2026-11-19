import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_art.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/udm_widgets.dart';

/// The opening brand screen, laid out to the ministry's own artwork: the
/// reader on the hillside under a blue sky, the white lockup, the mission's
/// full name, the four promises, and the two blue hills the page dots sit on.
///
/// Every position and size is a fraction of the viewport, measured off the
/// supplied artwork, so the composition keeps its proportions from a small
/// phone to a tablet instead of drifting as the screen changes.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  /// The reference's sky: near-black blue at the top, lifting to the ministry's
  /// brighter blue where the reader sits, and thinning over the photograph so
  /// the sunrise still reads through it.
  static const LinearGradient _sky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xF5012A7E),
      Color(0xE60441B1),
      Color(0xD90A6ADB),
      Color(0xB32E78DE),
      Color(0x593D7FD6),
      Color(0x33062C63),
    ],
    stops: [0, .25, .45, .58, .78, 1],
  );

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final width = MediaQuery.sizeOf(context).width;
    // The lockup is a band of the screen in the reference; the caps keep it
    // from taking over a tall or wide viewport.
    final lockup = math.min(height * .237, 210.0);
    final name = math.min(height * .023, 21.0);
    final tagline = math.min(height * .0175, 16.0);
    // The reference sets the dots at 1.4% of the screen width each.
    final dot = math.min(width * .014, 8.0);
    final gap = math.min(width * .0157, 9.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          BackdropArt(asset: AppArt.splash),
          const DecoratedBox(decoration: BoxDecoration(gradient: _sky)),
          const CustomPaint(painter: _HillsPainter()),
          Positioned(
            left: 0,
            right: 0,
            top: height * .181,
            child: Column(
              children: [
                FadeIn(
                  child: SizedBox(
                    height: lockup,
                    // The supplied lockup is 505x560: cross, open Bible and
                    // wordmark in one artwork, so the screen draws no wordmark
                    // of its own over it.
                    width: lockup * 0.902,
                    child: const Image(
                      image: AssetImage(AppArt.logoLockup),
                      semanticLabel: 'UDM',
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                SizedBox(height: height * .018),
                FadeIn(
                  delay: const Duration(milliseconds: 140),
                  child: AppText(
                    'University Discipleship\nMission',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: name,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
                SizedBox(height: height * .046),
                FadeIn(
                  delay: const Duration(milliseconds: 300),
                  child: AppText(
                    'Grow · Learn · Connect · Serve',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: tagline,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: height * .9217 - dot / 2,
            child: FadeIn(
              delay: const Duration(milliseconds: 380),
              child: _SplashDots(size: dot, gap: gap),
            ),
          ),
        ],
      ),
    );
  }
}

/// Five page dots on the hills. The reference lights two of them: the first in
/// the ministry's blue, the middle one in full white, the rest held back.
class _SplashDots extends StatelessWidget {
  const _SplashDots({required this.size, required this.gap});

  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      5,
      (index) => Container(
        width: size,
        height: size,
        margin: EdgeInsets.symmetric(horizontal: gap / 2),
        decoration: BoxDecoration(
          color: switch (index) {
            0 => AppColors.primaryBlue,
            2 => Colors.white,
            _ => Colors.white.withValues(alpha: .55),
          },
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

/// The ground the reader's hillside rests on: a dark ridge that lifts to the
/// right, and a brighter blue hill in front of it. Sampled from the reference.
class _HillsPainter extends CustomPainter {
  const _HillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final ridge = Path()
      ..moveTo(0, h * .958)
      ..cubicTo(w * .28, h * .905, w * .5, h * .868, w * .72, h * .845)
      ..quadraticBezierTo(w * .9, h * .826, w, h * .822)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      ridge,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF03307E), Color(0xFF01225C)],
        ).createShader(Rect.fromLTRB(0, h * .82, 0, h)),
    );

    final hill = Path()
      ..moveTo(0, h * .968)
      ..quadraticBezierTo(w * .18, h * .905, w * .40, h * .876)
      ..quadraticBezierTo(w * .62, h * .888, w * .78, h * 1.02)
      ..lineTo(0, h * 1.02)
      ..close();
    canvas.drawPath(
      hill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0149A4), Color(0xFF012C74)],
        ).createShader(Rect.fromLTRB(0, h * .876, 0, h)),
    );

    // A lit rim on the front crest, so the two surfaces read as separate.
    final crest = Path()
      ..moveTo(0, h * .968)
      ..quadraticBezierTo(w * .18, h * .905, w * .40, h * .876)
      ..quadraticBezierTo(w * .62, h * .888, w * .78, h * 1.02);
    canvas.clipPath(hill);
    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, h * .0022)
        ..color = const Color(0xFF2E74E8).withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(_HillsPainter oldDelegate) => false;
}
