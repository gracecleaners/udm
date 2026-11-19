import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_art.dart';
import '../theme/app_theme.dart';
import 'app_kit.dart';
import 'app_text.dart';
import 'formatted_content.dart';
import 'state_view.dart';
import 'udm_widgets.dart';

/// The list row used by home and detail pages. When `onTap` is null the row is
/// a plain card, never a control that looks tappable and does nothing.
class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingLabel,
    this.onTap,
    this.tone = IconBadgeTone.brand,
    this.badgeFilled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback? onTap;
  final IconBadgeTone tone;
  final bool badgeFilled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconBadge(icon: icon, tone: tone, filled: badgeFilled),
          const SizedBox(width: AppSpacing.md),
          // The title owns the full width; only the byline shares a line, and
          // it is the one allowed to ellipsize.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        subtitle,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trailingLabel != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      MetaPill(label: trailingLabel!, icon: AppIcons.clock),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The scripture feature card: the brand's signature surface, and the one thing
/// on the home screen that should look unlike any other card.
class ScripturePanel extends StatelessWidget {
  const ScripturePanel({
    super.key,
    required this.reference,
    required this.text,
    this.translationCode = '',
    this.artUrl = '',
    this.compact = false,
    this.offline = false,
    this.onTap,
    this.ctaLabel,
    this.onReview,
    this.memorized = false,
    this.savingReview = false,
  });

  final String reference;
  final String text;
  final String translationCode;

  /// A picture behind the verse, as staff published it in the console — an
  /// upload or a link. With none, the card keeps its brand gradient.
  final String artUrl;
  final bool compact;
  final bool offline;
  final VoidCallback? onTap;

  /// Null when there is no devotion to open, so the call to action is never a lie.
  final String? ctaLabel;

  /// The student's own action on this verse: marking it memorized. Null where
  /// there is no verse to mark, so the card never offers a button that leads
  /// nowhere.
  final VoidCallback? onReview;

  /// Once the server says the verse is learned, the button becomes a fact
  /// rather than staying a request to press again.
  final bool memorized;
  final bool savingReview;

  @override
  Widget build(BuildContext context) {
    final hasArt = artUrl.isNotEmpty;
    if (compact) return _compactCard(context, hasArt);
    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: AppGradients.scripture,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
          boxShadow: AppShadows.float,
        ),
        child: Stack(
          children: [
            if (hasArt) ...[
              Positioned.fill(
                child: CoverArt(
                  url: artUrl,
                  monogram: '',
                  radius: 0,
                  gradient: AppGradients.scripture,
                ),
              ),
              // The verse is written over somebody else's picture, so the scrim
              // is what makes the card readable rather than a decoration.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppGradients.scrim),
                ),
              ),
              if (compact)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.22),
                  ),
                ),
            ] else
              Positioned.fill(
                child: Mark.backdrop(tint: AppColors.white, alpha: 0.14),
              ),
            if (!compact)
              PositionedDirectional(
                top: -18,
                start: 6,
                child: ExcludeSemantics(
                  child: Text(
                    '“',
                    style: TextStyle(
                      fontFamily: AppFonts.scripture,
                      fontSize: 132,
                      height: 1,
                      color: AppColors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
            if (compact)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Eyebrow('Memory verse', color: Colors.white70),
                        ),
                        if (translationCode.isNotEmpty)
                          AppText(
                            translationCode.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.white70),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppText(
                      text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTypography.scriptureVerse(
                            AppColors.white,
                            size: 22,
                          ).copyWith(
                            height: 1.3,
                            shadows: [
                              Shadow(
                                color: AppColors.ink.withValues(alpha: 0.45),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        // The reference is the one address a student repeats, so
                        // it is marked as scripture rather than left as bare text.
                        const Icon(
                          AppIcons.bookOpen,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AppText(
                            reference,
                            style: AppTypography.scriptureReference(
                              Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onReview != null)
                          // A kept verse answers with the mark itself rather
                          // than a disabled button, so it cannot be counted
                          // twice by an accidental second tap.
                          if (memorized)
                            const MetaPill(
                              label: 'Memorized',
                              icon: AppIcons.checkCircle,
                              onDark: true,
                            )
                          else
                            TextButton.icon(
                              key: const Key('udm.markMemorized'),
                              onPressed: savingReview ? null : onReview,
                              icon: const Icon(AppIcons.verify, size: 16),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                              ),
                              label: AppText(
                                'Keep',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                      ],
                    ),
                    if (ctaLabel != null && onTap != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: onTap,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          icon: const Icon(AppIcons.bookOpen, size: 15),
                          label: AppText(
                            ctaLabel!,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Eyebrow('Memory verse', color: Colors.white70),
                        ),
                        if (offline)
                          const OfflineChip(onDark: true)
                        else if (translationCode.isNotEmpty)
                          MetaPill(
                            label: translationCode.toUpperCase(),
                            onDark: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppText(
                      text,
                      style:
                          AppTypography.scriptureVerse(
                            AppColors.white,
                            size: 21,
                          ).copyWith(
                            shadows: [
                              Shadow(
                                color: AppColors.ink.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const GoldRule(width: 64),
                    const SizedBox(height: AppSpacing.sm),
                    AppText(
                      reference,
                      style: AppTypography.scriptureReference(Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (onReview != null ||
                        (ctaLabel != null && onTap != null)) ...[
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (onReview != null)
                              if (memorized)
                                const MetaPill(
                                  label: 'Memorized',
                                  icon: AppIcons.checkCircle,
                                  onDark: true,
                                )
                              else
                                GhostButton(
                                  key: const Key('udm.markMemorized'),
                                  label: savingReview
                                      ? 'Saving…'
                                      : 'Mark memorized',
                                  icon: AppIcons.verify,
                                  onTap: savingReview ? null : onReview,
                                ),
                            if (ctaLabel != null && onTap != null)
                              GhostButton(
                                label: ctaLabel!,
                                icon: AppIcons.bookmarkBorder,
                                onTap: onTap,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _compactCard(BuildContext context, bool hasArt) {
    final cardHeight = (MediaQuery.sizeOf(context).width * .56).clamp(
      210.0,
      238.0,
    );
    final width = MediaQuery.sizeOf(context).width;
    final quoteInset = (width * .22).clamp(64.0, 86.0);
    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: PhysicalShape(
        clipper: const _HeroCardClipper(),
        color: AppColors.deepBlue,
        elevation: 11,
        shadowColor: const Color(0x6680B9FF),
        child: SizedBox(
          height: cardHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasArt)
                CoverArt(
                  url: artUrl,
                  monogram: '',
                  radius: 0,
                  gradient: AppGradients.scripture,
                )
              else
                Image.asset(
                  AppArt.splash,
                  fit: BoxFit.cover,
                  alignment: const Alignment(.18, -.12),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xD4102B50),
                      Color(0x9E102B50),
                      Color(0x17102B50),
                    ],
                    stops: [0, .56, 1],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x7607172E), Colors.transparent],
                    stops: [0, .5],
                  ),
                ),
              ),
              if (!hasArt)
                const Positioned(
                  right: 20,
                  top: 20,
                  width: 94,
                  height: 164,
                  child: CustomPaint(painter: _HeroCrossPainter()),
                ),
              const Positioned(
                left: 0,
                top: 0,
                width: 96,
                height: 88,
                child: CustomPaint(painter: _VerseLeavesPainter()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 31,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            AppIcons.bookOpen,
                            size: 19,
                            color: AppColors.deepBlue,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'MEMORY VERSE',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.deepBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .15,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 11),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: quoteInset),
                        child: _HighlightedVerse(
                          text: text,
                          fontSize: (width * .048).clamp(18.0, 21.0),
                        ),
                      ),
                    ),
                    const GoldRule(width: 38, height: 2.5),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            reference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 15.5,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (ctaLabel != null && onTap != null) ...[
                          const SizedBox(width: 7),
                          SizedBox(
                            width: 112,
                            height: 34,
                            child: OutlinedButton.icon(
                              onPressed: onTap,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1.2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                                shape: const StadiumBorder(),
                                backgroundColor: const Color(0x22071125),
                              ),
                              icon: const Icon(AppIcons.next, size: 15),
                              label: Text(
                                ctaLabel!,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontFamily: AppFonts.ui,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    const Center(child: _HeroPageIndicators()),
                  ],
                ),
              ),
              if (onReview != null)
                Positioned(
                  right: 7,
                  top: 6,
                  child: IconButton(
                    key: const Key('udm.markMemorized'),
                    tooltip: memorized ? 'Memorized' : 'Keep this verse',
                    onPressed: savingReview || memorized ? null : onReview,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      memorized ? AppIcons.checkCircle : AppIcons.bookmarkAdd,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedVerse extends StatelessWidget {
  const _HighlightedVerse({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final clean = text.trim().replaceAll(RegExp(r'^[“"]|[”"]$'), '');
    final base = TextStyle(
      fontFamily: AppFonts.ui,
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      height: 1.22,
      letterSpacing: -.25,
      shadows: const [Shadow(color: Color(0xB3071125), blurRadius: 10)],
    );
    return FormattedContent(
      '“$clean”',
      style: base,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _HeroPageIndicators extends StatelessWidget {
  const _HeroPageIndicators();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 9),
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: i == 0 ? 1 : .45),
            shape: BoxShape.circle,
          ),
        ),
      ],
    ],
  );
}

class _HeroCardClipper extends CustomClipper<Path> {
  const _HeroCardClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 25)
    ..quadraticBezierTo(0, 0, 25, 0)
    ..lineTo(size.width - 25, 0)
    ..quadraticBezierTo(size.width, 0, size.width, 25)
    ..lineTo(size.width, size.height - 36)
    ..cubicTo(
      size.width * .8,
      size.height - 2,
      size.width * .28,
      size.height - 1,
      0,
      size.height - 25,
    )
    ..close();

  @override
  bool shouldReclip(covariant _HeroCardClipper oldClipper) => false;
}

class _HeroCrossPainter extends CustomPainter {
  const _HeroCrossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = const Color(0x77071325)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final upright = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .44,
        size.height * .04,
        size.width * .14,
        size.height * .9,
      ),
      const Radius.circular(2),
    );
    final beam = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .08,
        size.height * .29,
        size.width * .84,
        size.height * .13,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(upright.shift(const Offset(3, 4)), shadow);
    canvas.drawRRect(beam.shift(const Offset(3, 4)), shadow);
    final wood = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF63391F), Color(0xFFC08B51), Color(0xFF63391F)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(upright, wood);
    canvas.drawRRect(beam, wood);
  }

  @override
  bool shouldRepaint(covariant _HeroCrossPainter oldDelegate) => false;
}

class _VerseLeavesPainter extends CustomPainter {
  const _VerseLeavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = const Color(0xFF54883C)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-5, 4)
        ..quadraticBezierTo(35, 29, 87, 78),
      stem,
    );
    const colors = [
      Color(0xFF4E923F),
      Color(0xFF77A847),
      Color(0xFF2F7541),
      Color(0xFF93B954),
    ];
    for (var i = 0; i < 6; i++) {
      final t = (i + 1) / 7;
      final point = Offset(7 + t * 76, 7 + t * 67);
      final side = i.isEven ? 1.0 : -1.0;
      final leaf = Path()
        ..moveTo(point.dx, point.dy)
        ..quadraticBezierTo(
          point.dx + side * 19,
          point.dy - 18,
          point.dx + side * 26,
          point.dy - 9,
        )
        ..quadraticBezierTo(
          point.dx + side * 17,
          point.dy + 3,
          point.dx,
          point.dy,
        )
        ..close();
      canvas.drawPath(
        leaf,
        Paint()..color = colors[i % colors.length].withValues(alpha: .9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VerseLeavesPainter oldDelegate) => false;
}
