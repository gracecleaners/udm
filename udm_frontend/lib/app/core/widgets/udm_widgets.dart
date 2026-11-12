import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_text.dart';

/// The UDM mark: a lit book on the brand gradient, with a wordmark when a
/// screen has room for it. Used by the splash, onboarding and home header.
class UdmLogo extends StatelessWidget {
  const UdmLogo({super.key, this.size = 44, this.showWordmark = true, this.tagline = '', this.onDark = false});

  final double size;
  final bool showWordmark;
  final String tagline;

  /// Set on a gradient background, where the wordmark must be white.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = Mark(size: size);

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.3),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'UDM',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: size * 0.44,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: onDark ? AppColors.white : theme.textTheme.bodyLarge?.color,
                ),
              ),
              if (tagline.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AppText(
                    tagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: math.max(9.5, size * 0.21),
                      color: onDark ? Colors.white70 : theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The gradient tile itself, so a screen can reuse it as an avatar or badge.
class Mark extends StatelessWidget {
  const Mark({super.key, required this.size, this.icon = Icons.auto_stories_rounded});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppGradients.hero,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: AppShadows.glow(AppColors.primaryBlue),
        ),
        child: Stack(
          children: [
            // A soft highlight across the top-left corner: the flat gradient
            // alone reads like a coloured square rather than a lit object.
            PositionedDirectional(
              top: -size * 0.25,
              start: -size * 0.2,
              child: Container(
                width: size * 0.8,
                height: size * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white.withValues(alpha: 0.34), Colors.white.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            Center(child: Icon(icon, color: AppColors.white, size: size * 0.48)),
          ],
        ),
      );

  /// Decorative arcs behind a brand screen. Purely visual: `IgnorePointer` plus
  /// `ExcludeSemantics` keeps it out of the tap and screen-reader paths.
  static Widget backdrop({Color tint = AppColors.primaryBlue, double alpha = 0.10}) => IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(painter: _ArcPainter(tint: tint, alpha: alpha), size: Size.infinite),
        ),
      );
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.tint, required this.alpha});

  final Color tint;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = tint.withValues(alpha: alpha);
    final centre = Offset(size.width * 0.86, size.height * 0.12);
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(centre, i * size.width * 0.14, paint);
    }
    final wash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.9, -0.9),
        radius: 0.9,
        colors: [tint.withValues(alpha: alpha * 1.6), tint.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.tint != tint || old.alpha != alpha;
}

/// The gradient icon tile shared by rows, panels and status screens.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = AppSpacing.iconTile,
    this.tone = IconBadgeTone.brand,
    this.filled = true,
  });

  final IconData icon;
  final double size;
  final IconBadgeTone tone;

  /// `false` for quieter rows: tinted background, coloured glyph, no gradient.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      IconBadgeTone.brand => AppColors.primaryBlue,
      IconBadgeTone.success => AppColors.success,
      IconBadgeTone.warning => AppColors.warning,
      IconBadgeTone.gold => AppColors.gold,
      IconBadgeTone.neutral => Theme.of(context).textTheme.bodySmall?.color ?? AppColors.secondaryText,
    };
    if (!filled) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(icon, color: color, size: size * 0.48),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: switch (tone) {
          IconBadgeTone.success => const LinearGradient(
              colors: [AppColors.success, Color(0xFF146B4E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          IconBadgeTone.gold => const LinearGradient(
              colors: [AppColors.gold, Color(0xFFD08A1B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          _ => AppGradients.hero,
        },
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: AppShadows.glow(color),
      ),
      child: Icon(icon, color: AppColors.white, size: size * 0.48),
    );
  }
}

enum IconBadgeTone { brand, success, warning, gold, neutral }

/// A small labelled fact: reading time, translation, member count. One place so
/// meta rows never drift into three different pill shapes.
class MetaPill extends StatelessWidget {
  const MetaPill({
    super.key,
    required this.label,
    this.icon,
    this.onDark = false,
    this.tone,
  });

  final String label;
  final IconData? icon;

  /// On the gradient hero the pill must be a translucent white shape.
  final bool onDark;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tone ?? (onDark ? AppColors.white : theme.colorScheme.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.18) : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: onDark ? Colors.white24 : color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: AppText(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A card-like surface that owns the sheen, hairline and shadow together.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.gradient,
    this.border = true,
    this.radius = AppSpacing.radiusCard,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final bool border;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: gradient == null
            ? surfaces.card(border: border).copyWith(borderRadius: BorderRadius.circular(radius))
            : BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: AppShadows.card(surfaces.shadowTint),
              ),
        child: padding == EdgeInsets.zero ? child : Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A full-screen brand wash: a soft tint at the top fading into the canvas,
/// with the concentric arcs behind it. Decorative only, so it never takes a tap.
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, this.tint = AppColors.primaryBlue, this.strength = 0.12});

  final Color tint;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    return IgnorePointer(
      child: ColoredBox(
        color: base,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tint.withValues(alpha: strength), Colors.transparent],
            ),
          ),
          child: SizedBox.expand(child: Mark.backdrop(tint: tint, alpha: 0.09)),
        ),
      ),
    );
  }
}

/// Cards grow slightly and lift under the finger. A 90 ms press feels alive
/// without delaying the tap, and it works the same for mouse and touch.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.scale = 0.982,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onTap == null || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: widget.onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      );
}

/// The gold hairline that opens a scripture block: a rule, not a divider, so it
/// fades out instead of running edge to edge.
class GoldRule extends StatelessWidget {
  const GoldRule({super.key, this.width = 58, this.height = 3});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          gradient: AppGradients.goldRule,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
}

/// Small all-caps label that opens a group of related rows.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color ?? theme.textTheme.bodySmall?.color),
          const SizedBox(width: 6),
        ],
        AppText(
          text.toUpperCase(),
          style: AppTypography.eyebrow(color ?? theme.textTheme.bodySmall?.color ?? AppColors.secondaryText),
        ),
      ],
    );
  }
}

/// Screen initials in a gradient ring, so a signed-in student has a face on the
/// shell before photo uploads exist.
class UdmAvatar extends StatelessWidget {
  const UdmAvatar({super.key, required this.initials, this.size = 56});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.hero,
          boxShadow: AppShadows.glow(AppColors.primaryBlue),
        ),
        child: AppText(
          initials,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AppColors.white,
          ),
        ),
      );

  static String initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'UDM';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.eyebrow,
    this.onSeeAll,
    this.seeAllLabel = 'See all',
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? eyebrow;

  /// When the screen has a real destination for the whole group. A label with
  /// nowhere to go is not rendered.
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Eyebrow(eyebrow!, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(title, style: theme.textTheme.titleLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    AppText(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  visualDensity: VisualDensity.compact,
                ),
                child: Row(
                  children: [
                    AppText(seeAllLabel, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.primary),
                  ],
                ),
              )
            else
              ?trailing,
          ],
        ),
      ],
    );
  }
}

/// Fades content in as it becomes ready, so a screen swap is not a hard cut.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 320)});

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) => _Ramp(
        delay: delay,
        duration: duration,
        builder: (context, value) => Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child),
        ),
      );
}

/// Drives a 0→1 value after [delay]; used by [FadeIn] and the splash.
class _Ramp extends StatefulWidget {
  const _Ramp({required this.builder, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 320)});

  final Duration delay;
  final Duration duration;
  final Widget Function(BuildContext context, double value) builder;

  @override
  State<_Ramp> createState() => _RampState();
}

class _RampState extends State<_Ramp> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(context, Curves.easeOutCubic.transform(_controller.value)),
      );
}

/// The greeting header on the home screen: brand gradient, arcs behind, greeting
/// and title, plus whatever the screen wants on the right (offline chip, menu).
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.children = const [],
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusSheet);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: AppGradients.hero, borderRadius: radius, boxShadow: AppShadows.float),
      child: Stack(
        children: [
          Positioned.fill(child: Mark.backdrop(tint: AppColors.white, alpha: 0.16)),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The greeting is the server's own sentence, so it is
                          // set in the tracked label style but never re-cased.
                          AppText(eyebrow, style: AppTypography.eyebrow(Colors.white70)),
                          const SizedBox(height: 8),
                          AppText(
                            title,
                            style: const TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 26,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: AppColors.white,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            AppText(
                              subtitle!,
                              style: const TextStyle(
                                fontFamily: AppFonts.ui,
                                fontSize: 13.5,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A translucent control that sits on the hero gradient.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, this.icon, this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PressableScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.white),
                const SizedBox(width: 7),
              ],
              AppText(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Placeholder rows while a list loads. A spinner says "wait"; a skeleton says
/// "this is what is coming", which reads far better on a slow campus network.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = 10, this.animate = true});

  final double height;
  final double? width;
  final double radius;
  final bool animate;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.animate) _shimmer.repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final base = surfaces.scripture;
    final highlight = Color.alphaBlend(AppColors.white.withValues(alpha: 0.55), base);
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + _shimmer.value * 2 - 0.6, 0),
            end: Alignment(_shimmer.value * 2 - 0.6, 0.4),
            colors: [base, highlight, base],
            stops: const [0.1, 0.5, 0.9],
          ),
          border: Border.all(color: surfaces.hairline),
        ),
      ),
    );
  }
}

/// A content row shown while the real one loads.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 2});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      child: Row(
        children: [
          SkeletonBox(height: AppSpacing.iconTile, width: AppSpacing.iconTile, radius: AppSpacing.radiusTile),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 14, width: double.infinity),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < lines; i++) ...[
                  SkeletonBox(height: 11, width: i == lines - 1 ? 120 : double.infinity),
                  const SizedBox(height: 7),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.textTheme.bodySmall?.color),
        ],
      ),
    );
  }
}
