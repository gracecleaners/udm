import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_text.dart';
import 'udm_widgets.dart';

/// Honest status panel for a tab whose feature has not shipped yet. It states
/// what exists today instead of pretending to be a working screen.
class FeatureStatusView extends StatelessWidget {
  const FeatureStatusView({
    super.key,
    required this.title,
    required this.message,
    required this.plannedFor,
    required this.icon,
    this.workingToday = const [],
  });

  final String title;
  final String message;
  final String plannedFor;
  final IconData icon;
  final List<String> workingToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xl),
        children: [
          IconBadge(icon: icon, size: 58),
          const SizedBox(height: AppSpacing.lg),
          AppText(title, style: theme.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodySmall?.color),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (workingToday.isNotEmpty) ...[
            const SectionHeader(eyebrow: 'Already working', title: 'Available today'),
            const SizedBox(height: AppSpacing.md),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Column(
                children: [
                  for (var i = 0; i < workingToday.length; i++)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? AppSpacing.sm : 0, bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: AppText(workingToday[i], style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: AppGradients.sheen,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.18)),
              boxShadow: AppShadows.card(AppColors.primaryBlue),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const IconBadge(icon: Icons.flag_outlined, size: 42, tone: IconBadgeTone.gold),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText('Planned for $plannedFor', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        AppText(
                          'This tab is intentionally empty until that phase ships.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
