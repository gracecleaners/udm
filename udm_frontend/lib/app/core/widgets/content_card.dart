import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_kit.dart';
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
              const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.scrim))),
              if (compact)
                Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.22))),
            ] else
              Positioned.fill(child: Mark.backdrop(tint: AppColors.white, alpha: 0.14)),
            if (!compact) PositionedDirectional(
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Eyebrow('Memory verse', color: Colors.white70)),
                        if (translationCode.isNotEmpty)
                          AppText(translationCode.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppText(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.scriptureVerse(AppColors.white, size: 18).copyWith(
                        height: 1.28,
                        shadows: [Shadow(color: AppColors.ink.withValues(alpha: 0.45), blurRadius: 12)],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(child: AppText(reference, style: AppTypography.scriptureReference(Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                              ),
                              label: AppText(
                                'Keep',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              )
            else Padding(
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
                                icon: AppIcons.checkCircle,
                                onDark: true,
                              )
                            else
                              GhostButton(
                                key: const Key('udm.markMemorized'),
                                label: savingReview ? 'Saving…' : 'Mark memorized',
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
}
