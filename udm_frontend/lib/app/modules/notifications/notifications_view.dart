import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/user_notification.dart';
import '../session/session_controller.dart';
import 'notifications_controller.dart';

class NotificationsView extends GetView<NotificationsController> {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Notifications'),
        actions: [
          Obx(() => TextButton(
                onPressed: controller.unreadCount.value == 0 ? null : controller.markAllRead,
                child: const AppText('Mark all read'),
              )),
        ],
      ),
      body: Obx(() {
        if (!session.isSignedIn) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const IconBadge(icon: AppIcons.notifications, size: 58),
                const SizedBox(height: AppSpacing.md),
                const AppText('Sign in to see your notifications', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: () => Get.toNamed(AppRoutes.signIn), child: const AppText('Sign in')),
              ]),
            ),
          );
        }
        if (controller.loading.value && controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error.value.isNotEmpty && controller.items.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppText(controller.error.value, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(onPressed: controller.load, icon: const Icon(AppIcons.refresh), label: const AppText('Try again')),
            ]),
          );
        }
        if (controller.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: IconBadge(icon: AppIcons.notifications, size: 58)),
                SizedBox(height: AppSpacing.md),
                Center(child: AppText('You’re all caught up')),
                SizedBox(height: AppSpacing.sm),
                Center(child: AppText('New updates from UDM will appear here.', textAlign: TextAlign.center)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
            itemCount: controller.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _NotificationTile(
              item: controller.items[index],
              onTap: () => _open(controller.items[index]),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _open(UserNotification item) async {
    try {
      await controller.markRead(item);
    } catch (_) {
      // The screen remains useful if marking read fails; the backend keeps the
      // unread badge correct on the next refresh.
    }
    final route = item.destination;
    if (route.isEmpty) return;
    // Only destinations a notice can open on its own. A route that reads an id
    // out of Get.arguments is not one of them: the staff console is offered the
    // same list, so a notice never promises a screen the app cannot build.
    const allowed = [
      AppRoutes.shell,
      AppRoutes.notifications,
      AppRoutes.readingDay,
      AppRoutes.readingHistory,
      AppRoutes.articles,
      AppRoutes.community,
      AppRoutes.courses,
      AppRoutes.newBeliever,
      AppRoutes.settings,
    ];
    // A row read from the inbox itself must not stack a second copy of it.
    if (allowed.contains(route) && Get.currentRoute != route) Get.toNamed(route);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final UserNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Material(
      color: surfaces.elevated,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: surfaces.hairline),
            color: item.isRead ? null : theme.colorScheme.primary.withValues(alpha: 0.045),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconBadge(icon: _iconFor(item.kind), size: 42, tone: item.isRead ? IconBadgeTone.neutral : IconBadgeTone.brand),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: AppText(item.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                  if (!item.isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: AppSpacing.xs),
                AppText(item.body, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                AppText(DateFormat('MMM d · h:mm a').format(item.createdAt.toLocal()), style: theme.textTheme.labelSmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  IconData _iconFor(String kind) => switch (kind.toLowerCase()) {
        'devotion' || 'devotional' || 'reading' || 'reading_plan' => AppIcons.bookOpen,
        'event' => AppIcons.calendar,
        'community' || 'prayer' => AppIcons.community,
        _ => AppIcons.notifications,
      };
}
