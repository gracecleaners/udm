import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'state_view.dart';

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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: _Tappable(
        onTap: onTap,
        radius: AppSpacing.radiusCard,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.extension<AppSurfaces>()!.scripture,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailingLabel != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  trailingLabel!,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The scripture feature card: a gradient panel that leads the home screen.
class ScripturePanel extends StatelessWidget {
  const ScripturePanel({
    super.key,
    required this.reference,
    required this.text,
    this.translationCode = '',
    this.offline = false,
    this.onTap,
  });

  final String reference;
  final String text;
  final String translationCode;
  final bool offline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSheet)),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryBlue, AppColors.deepBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
        ),
        child: _Tappable(
          onTap: onTap,
          radius: AppSpacing.radiusSheet,
          splashColor: Colors.white24,
          highlightColor: Colors.white12,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'VERSE OF THE DAY',
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 1.2,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (offline) const OfflineChip() else if (translationCode.isNotEmpty)
                      Text(
                        translationCode.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '"$text"',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(reference, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                if (onTap != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Row(
                    children: [
                      Text(
                        'OPEN TODAY\'S DEVOTION',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          fontSize: 12.5,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Adds the tap gesture and its accessibility semantics to a surface that
/// already owns a [Material], so the ripple is painted on that surface.
class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.onTap,
    required this.radius,
    required this.child,
    this.splashColor,
    this.highlightColor,
  });

  final VoidCallback? onTap;
  final double radius;
  final Widget child;
  final Color? splashColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor,
        highlightColor: highlightColor,
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}
