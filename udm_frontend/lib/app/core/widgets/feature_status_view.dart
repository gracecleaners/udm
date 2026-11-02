import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
          Text(title, style: theme.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          if (workingToday.isNotEmpty) ...[
            const SectionHeader(title: 'Available today'),
            const SizedBox(height: AppSpacing.sm),
            ...workingToday.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Planned for $plannedFor', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
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
