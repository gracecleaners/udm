import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum ViewState { loading, ready, empty, error }

/// Every screen renders through this so loading, failure and empty states look
/// and behave the same across features.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.state,
    required this.child,
    this.onRetry,
    this.failureMessage,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon = Icons.auto_awesome_outlined,
    this.retryLabel = 'Try again',
  });

  final ViewState state;
  final Widget child;
  final VoidCallback? onRetry;
  final String? failureMessage;
  final String? emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ViewState.loading:
        return const CenteredSlot(child: UdmProgress());
      case ViewState.error:
        return CenteredSlot(
          child: MessagePanel(
            icon: Icons.cloud_off_rounded,
            iconColor: AppColors.warning,
            title: 'We could not load this',
            message: failureMessage ?? 'Check your connection and try again.',
            actionLabel: onRetry == null ? null : retryLabel,
            onAction: onRetry,
          ),
        );
      case ViewState.empty:
        return CenteredSlot(
          child: MessagePanel(
            icon: emptyIcon,
            iconColor: Theme.of(context).colorScheme.primary,
            title: emptyTitle ?? 'Nothing here yet',
            message: emptyMessage ?? 'Content published by the ministry team will appear here.',
            actionLabel: onRetry == null ? null : retryLabel,
            onAction: onRetry,
          ),
        );
      case ViewState.ready:
        return child;
    }
  }
}

class CenteredSlot extends StatelessWidget {
  const CenteredSlot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Centered(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: child,
        ),
      );
}

/// Small helper so a state panel never stretches oddly on tablets.
class Centered extends StatelessWidget {
  const Centered({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: child),
      );
}

class MessagePanel extends StatelessWidget {
  const MessagePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor = AppColors.secondaryText,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: theme.extension<AppSurfaces>()!.scripture,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 30),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color), textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

class UdmProgress extends StatelessWidget {
  const UdmProgress({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(label!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
}

/// Labels content that came from the device rather than the server. Never rely
/// on colour alone: the icon and the words both say it.
class OfflineChip extends StatelessWidget {
  const OfflineChip({super.key, this.message = 'Offline copy'});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 14, color: AppColors.warning),
            const SizedBox(width: 6),
            Text(
              message,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.warning),
            ),
          ],
        ),
      );
}
