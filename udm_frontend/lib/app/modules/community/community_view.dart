import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../session/session_controller.dart';
import 'community_controller.dart';

class CommunityView extends GetView<CommunityController> {
  const CommunityView({super.key});

  static const sections = ['Campus', 'Groups', 'Events', 'Prayer'];

  @override
  Widget build(BuildContext context) => Obx(() {
        if (controller.loading.value && controller.universities.isEmpty && controller.groups.isEmpty) {
          return ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xl),
            children: [
              SkeletonCard(),
              SizedBox(height: AppSpacing.sm),
              SkeletonCard(),
              SizedBox(height: AppSpacing.sm),
              SkeletonCard(),
            ],
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    eyebrow: 'Together',
                    title: 'Community',
                    subtitle: 'Campuses, groups, events and prayer.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Four short sections fit on one line at 390dp and two at
                  // 320dp; a scroller would hide that the list is finite.
                  PillSelector(
                    options: sections,
                    selectedIndex: controller.selectedSection.value,
                    onSelect: (index) => controller.selectedSection.value = index,
                  ),
                ],
              ),
            ),
            if (controller.error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: NoticeBanner(message: controller.error.value, tone: NoticeTone.problem),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
                  children: switch (controller.selectedSection.value) {
                    0 => _campus(context),
                    1 => _groups(context),
                    2 => _events(context),
                    _ => _prayers(context),
                  },
                ),
              ),
            ),
          ],
        );
      });

  List<Widget> _campus(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.universities.isEmpty && controller.fellowships.isEmpty) {
      return [_empty(context, 'No campus directory entries have been published yet.')];
    }
    final widgets = <Widget>[];
    for (final university in controller.universities) {
      final campusRows = controller.campuses.where((row) => row['university'] == university['name']).toList();
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _Tile(
          icon: AppIcons.building,
          title: university['name'] as String,
          subtitle: [university['city'], university['country']]
              .whereType<String>()
              .where((part) => part.isNotEmpty)
              .join(' · '),
          children: campusRows
              .map((campus) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    leading: const Icon(AppIcons.pin, color: AppColors.primaryBlue),
                    title: AppText(campus['name'] as String),
                    subtitle: AppText(campus['location'] as String? ?? ''),
                  ))
              .toList(),
        ),
      ));
    }
    if (controller.fellowships.isNotEmpty) {
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.lg, AppSpacing.xs, AppSpacing.sm),
        child: const Eyebrow('Fellowships'),
      ));
      widgets.addAll(controller.fellowships.map(
        (fellowship) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Panel(
            child: Row(
              children: [
                const IconBadge(icon: AppIcons.community, size: 40, filled: false),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(fellowship['name'] as String, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 3),
                      AppText(
                        '${fellowship['campus']} · ${fellowship['meeting_schedule'] ?? fellowship['description'] ?? ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    }
    return widgets;
  }

  List<Widget> _groups(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.groups.isEmpty) return [_empty(context, 'No discoverable groups are available yet.')];
    return controller.groups.map((group) {
      final id = group['id'] as String;
      final membership = group['membership_status'] as String?;
      final isLeader = group['is_leader'] == true;
      final requests = controller.joinRequests[id] ?? const <Map<String, dynamic>>[];
      final prayerQueue = controller.groupPrayerQueues[id] ?? const <Map<String, dynamic>>[];
      final facts = [
        '${group['member_count']} members',
        if ((group['group_type'] as String? ?? '').isNotEmpty) group['group_type'] as String,
      ];
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _Tile(
          icon: AppIcons.community,
          title: group['name'] as String,
          subtitle: '${group['campus'] ?? 'Community group'} · ${facts.join(' · ')}',
          children: [
            if ((group['description'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                child: AppText(group['description'] as String, style: theme.textTheme.bodyMedium),
              ),
            if (membership == null && !isLeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                child: FilledButton.icon(
                  onPressed: () => controller.joinGroup(group),
                  icon: const Icon(AppIcons.personAdd, size: 18),
                  label: const AppText('Request to join'),
                ),
              )
            else if (membership == 'requested')
              ListTile(
                leading: const Icon(AppIcons.clock, color: AppColors.warning),
                title: const AppText('Membership request sent'),
              )
            else if (membership == 'approved')
              ListTile(
                leading: const Icon(AppIcons.checkCircle, color: AppColors.success),
                title: const AppText('You are a member'),
              ),
            if (isLeader && requests.isNotEmpty) ...[
              const Divider(),
              const ListTile(title: AppText('Membership requests')),
              ...requests.map((request) => ListTile(
                title: AppText(request['member_name'] as String? ?? 'Student'),
                trailing: Wrap(spacing: 4, children: [
                  IconButton(
                    tooltip: 'Approve'.tr,
                    icon: const Icon(AppIcons.check, color: AppColors.success),
                    onPressed: () => controller.decideMembership(id, request['id'] as String, 'approved'),
                  ),
                  IconButton(
                    tooltip: 'Decline'.tr,
                    icon: const Icon(AppIcons.close),
                    onPressed: () => controller.decideMembership(id, request['id'] as String, 'rejected'),
                  ),
                ]),
              )),
            ],
            if (isLeader && prayerQueue.isNotEmpty) ...[
              const Divider(),
              const ListTile(title: AppText('Prayer requests to review')),
              ...prayerQueue.map((prayer) => ListTile(
                title: AppText(prayer['body'] as String, maxLines: 3, overflow: TextOverflow.ellipsis),
                trailing: Wrap(spacing: 4, children: [
                  IconButton(
                    tooltip: 'Share with group'.tr,
                    icon: const Icon(AppIcons.check, color: AppColors.success),
                    onPressed: () => controller.moderatePrayer(id, prayer['id'] as String, 'approved'),
                  ),
                  IconButton(
                    tooltip: 'Decline'.tr,
                    icon: const Icon(AppIcons.close),
                    onPressed: () => controller.moderatePrayer(id, prayer['id'] as String, 'rejected'),
                  ),
                ]),
              )),
            ],
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _events(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.events.isEmpty) return [_empty(context, 'No upcoming events have been published yet.')];
    return controller.events.map((event) {
      final start = DateTime.tryParse(event['starts_at'] as String? ?? '')?.toLocal();
      final where = [event['campus'], event['location']]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(' · ');
      final full = event['capacity'] != null && (event['registration_count'] as int) >= (event['capacity'] as int);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (start != null) ...[
                    _DateBlock(date: start),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(event['title'] as String, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            if (start != null) ...[
                              // The block gives the day; this gives the month and
                              // year, in the format the device's locale expects.
                              MetaPill(
                                icon: AppIcons.calendar,
                                label: MaterialLocalizations.of(context).formatMonthYear(start),
                              ),
                              MetaPill(
                                icon: AppIcons.clock,
                                label: '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                              ),
                            ],
                            if (where.isNotEmpty)
                              MetaPill(icon: AppIcons.location, label: where),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((event['description'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AppText(event['description'] as String, style: theme.textTheme.bodyMedium),
              ],
              if ((event['online_url'] as String? ?? '').isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => controller.openEventLink(event['online_url'] as String),
                    icon: const Icon(AppIcons.external, size: 16),
                    label: const AppText('Join online event'),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: event['registered'] == true
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: Icon(AppIcons.check, size: 18, color: AppColors.success),
                        label: AppText('Registered'),
                      )
                    : FilledButton(
                        onPressed: full ? null : () => controller.registerForEvent(event),
                        child: AppText(full ? 'Full' : 'Register'),
                      ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _prayers(BuildContext context) {
    final theme = Theme.of(context);
    return [
      if (Get.find<SessionController>().isSignedIn)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: FilledButton.icon(
            onPressed: () => _newPrayer(context),
            icon: const Icon(AppIcons.add, size: 18),
            label: const AppText('Write a prayer request'),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Panel(
            child: Row(
              children: [
                const IconBadge(icon: AppIcons.lock, size: 38, filled: false),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppText(
                    'Sign in to write a private prayer or share one with consent.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      if (controller.prayers.isEmpty) _empty(context, 'No shared prayer requests are currently visible.'),
      ...controller.prayers.map((prayer) {
        final isOwner = prayer['is_owner'] == true;
        final id = prayer['id'] as String;
        final isPrivate = prayer['visibility'] == 'private';
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Panel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(
                  icon: isPrivate ? AppIcons.lock : AppIcons.heart,
                  size: 36,
                  filled: false,
                  tone: isPrivate ? IconBadgeTone.neutral : IconBadgeTone.success,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(prayer['body'] as String, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          MetaPill(
                            label: prayer['visibility'] as String,
                            tone: isPrivate ? AppColors.secondaryText : AppColors.success,
                          ),
                          if (prayer['moderation_state'] == 'pending')
                            const MetaPill(label: 'Waiting for review', icon: AppIcons.clock),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  IconButton(
                    tooltip: 'Delete my request'.tr,
                    icon: const Icon(AppIcons.delete),
                    onPressed: () => controller.deletePrayer(id),
                  ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  Future<void> _newPrayer(BuildContext context) async {
    final input = TextEditingController();
    var visibility = 'private';
    String? selectedGroup;
    var consent = false;
    final joined = controller.groups.where((group) => group['membership_status'] == 'approved').toList();
    final result = await showDialog<(String, String, String?, bool)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const AppText('Prayer request'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: input, maxLines: 4, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'What would you like prayer for?'.tr)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: visibility,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Who can see this?'.tr),
            items: const [
              DropdownMenuItem(value: 'private', child: AppText('Only me')),
              DropdownMenuItem(value: 'group', child: AppText('My group')),
              DropdownMenuItem(value: 'public', child: AppText('Community prayer wall')),
            ],
            onChanged: (value) => setState(() { if (value != null) { visibility = value; consent = false; } }),
          ),
          if (visibility == 'group') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedGroup,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Group'.tr),
              items: joined.map((group) => DropdownMenuItem(value: group['id'] as String, child: AppText(group['name'] as String))).toList(),
              onChanged: (value) => setState(() => selectedGroup = value),
            ),
          ],
          if (visibility != 'private')
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: consent,
              onChanged: (value) => setState(() => consent = value ?? false),
              title: AppText(visibility == 'public'
                  ? 'I consent to sharing this publicly after moderator review.'
                  : 'I consent to sharing this with my group after leader review.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          if (visibility == 'group' && joined.isEmpty)
            const AppText('Join a group before sharing a group prayer request.'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const AppText('Cancel')),
          FilledButton(
            onPressed: input.text.trim().isEmpty || (visibility != 'private' && !consent) || (visibility == 'group' && selectedGroup == null)
                ? null
                : () => Navigator.pop(dialogContext, (input.text.trim(), visibility, selectedGroup, consent)),
            child: const AppText('Save'),
          ),
        ],
      )),
    );
    input.dispose();
    if (result != null) {
      await controller.createPrayer(body: result.$1, visibility: result.$2, groupId: result.$3, shareConsent: result.$4);
    }
  }

  Widget _empty(BuildContext context, String message) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Panel(
          child: Row(
            children: [
              const IconBadge(icon: AppIcons.inbox, size: 36, filled: false),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: AppText(message, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
        ),
      );
}

/// An expandable directory or group entry on the brand tile.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.children});

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: IconBadge(icon: icon, size: 36, filled: false),
          title: AppText(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: subtitle.isEmpty
              ? null
              : AppText(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          children: children,
        ),
      );
}

/// Day number and weekday as a stamped block, so an event reads like a diary
/// entry. Both come from `MaterialLocalizations`, so neither is hardcoded
/// English.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final weekday = localizations.narrowWeekdays[date.weekday % DateTime.sunday];

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
        boxShadow: AppShadows.glow(AppColors.primaryBlue),
      ),
      child: Column(
        children: [
          AppText(
            '${date.day}',
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 19,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AppText(
              weekday,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
