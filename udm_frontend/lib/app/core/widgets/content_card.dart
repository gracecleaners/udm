import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_text.dart';
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
                AppText(title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
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
                      MetaPill(label: trailingLabel!, icon: Icons.schedule_rounded),
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
            Positioned.fill(child: Mark.backdrop(tint: AppColors.white, alpha: 0.14)),
            // Oversized open-quote set in the reading serif: decoration, not text.
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
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Eyebrow('Memory verse', color: Colors.white70)),
                      if (offline)
                        const OfflineChip(onDark: true)
                      else if (translationCode.isNotEmpty)
                        MetaPill(label: translationCode.toUpperCase(), onDark: true),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppText(
                    text,
                    style: AppTypography.scriptureVerse(AppColors.white, size: 21).copyWith(
                      shadows: [Shadow(color: AppColors.ink.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 3))],
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
                  if (onReview != null || (ctaLabel != null && onTap != null)) ...[
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
                                icon: Icons.check_circle_rounded,
                                onDark: true,
                              )
                            else
                              GhostButton(
                                key: const Key('udm.markMemorized'),
                                label: savingReview ? 'Saving…' : 'Mark memorized',
                                icon: Icons.fact_check_outlined,
                                onTap: savingReview ? null : onReview,
                              ),
                          if (ctaLabel != null && onTap != null)
                            GhostButton(
                              label: ctaLabel!,
                              icon: Icons.bookmark_border_rounded,
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
}
