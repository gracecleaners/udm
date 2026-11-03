import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The UDM mark. Used by the splash, onboarding and home header.
class UdmLogo extends StatelessWidget {
  const UdmLogo({super.key, this.size = 44, this.showWordmark = true, this.tagline = ''});

  final double size;
  final bool showWordmark;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.32;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.deepBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.auto_stories_rounded, color: AppColors.white, size: size * 0.5),
    );

    if (!showWordmark) return mark;

    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.28),
        Flexible(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UDM',
              style: TextStyle(
                fontSize: size * 0.46,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (tagline.isNotEmpty)
              Text(
                tagline,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: size * 0.24),
              ),
          ],
        ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
