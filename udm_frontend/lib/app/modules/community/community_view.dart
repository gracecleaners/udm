import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/formatted_content.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/prayer_post.dart';
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
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.lg,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.sm,
          ),
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              children: switch (controller.selectedSection.value) {
                0 => _campus(context),
                1 => _groups(context),
                2 => _events(context),
                _ => _wall(context),
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
      final campusRows = controller.campuses
          .where((row) => row['university'] == university['name'])
          .toList();
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _Tile(
            icon: AppIcons.building,
            title: university['name'] as String,
            subtitle: [
              university['city'],
              university['country'],
            ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
            children: campusRows
                .map(
                  (campus) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    leading: const Icon(AppIcons.pin, color: AppColors.primaryBlue),
                    title: AppText(campus['name'] as String),
                    subtitle: AppText(campus['location'] as String? ?? ''),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
    if (controller.fellowships.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: const Eyebrow('Fellowships'),
        ),
      );
      widgets.addAll(
        controller.fellowships.map(
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
        ),
      );
    }
    return widgets;
  }

  List<Widget> _groups(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.groups.isEmpty) {
      return [_empty(context, 'No discoverable groups are available yet.')];
    }
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
                child: FormattedContent(
                  group['description'] as String,
                  style: theme.textTheme.bodyMedium,
                ),
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
              ...requests.map(
                (request) => ListTile(
                  title: AppText(request['member_name'] as String? ?? 'Student'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Approve',
                        icon: const Icon(AppIcons.check, color: AppColors.success),
                        onPressed: () =>
                            controller.decideMembership(id, request['id'] as String, 'approved'),
                      ),
                      IconButton(
                        tooltip: 'Decline',
                        icon: const Icon(AppIcons.close),
                        onPressed: () =>
                            controller.decideMembership(id, request['id'] as String, 'rejected'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (isLeader && prayerQueue.isNotEmpty) ...[
              const Divider(),
              const ListTile(title: AppText('Prayer requests to review')),
              ...prayerQueue.map(
                (prayer) => ListTile(
                  title: AppText(
                    prayer['body'] as String,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Share with group',
                        icon: const Icon(AppIcons.check, color: AppColors.success),
                        onPressed: () =>
                            controller.moderatePrayer(id, prayer['id'] as String, 'approved'),
                      ),
                      IconButton(
                        tooltip: 'Decline',
                        icon: const Icon(AppIcons.close),
                        onPressed: () =>
                            controller.moderatePrayer(id, prayer['id'] as String, 'rejected'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _events(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.events.isEmpty) {
      return [_empty(context, 'No upcoming events have been published yet.')];
    }
    return controller.events.map((event) {
      final start = DateTime.tryParse(event['starts_at'] as String? ?? '')?.toLocal();
      final where = [
        event['campus'],
        event['location'],
      ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
      final full =
          event['capacity'] != null &&
          (event['registration_count'] as int) >= (event['capacity'] as int);
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
                                label:
                                    '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                              ),
                            ],
                            if (where.isNotEmpty) MetaPill(icon: AppIcons.location, label: where),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((event['description'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                FormattedContent(event['description'] as String, style: theme.textTheme.bodyMedium),
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

  /// The wall itself: what the student may add to it, which of its three
  /// shelves is showing, and the cards on it.
  List<Widget> _wall(BuildContext context) {
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
      // The wall's own filter row. `All` is the app's choice; the other tabs
      // are the categories the ministry publishes, so no tab can be offered
      // for a wall the server does not answer for.
      PillSelector(
        key: const Key('wall-tabs'),
        options: CommunityController.wallLabels,
        selectedIndex: controller.selectedWall.value,
        onSelect: controller.selectWallTab,
      ),
      const SizedBox(height: AppSpacing.md),
      if (controller.loadingWall.value && controller.wall.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: SkeletonCard(),
        )
      else if (controller.wall.isEmpty)
        _empty(context, 'Nothing has been shared on this wall yet.'),
      ...controller.wall.map((post) {
        // Both reads happen while the screen's own reaction is being built,
        // which is what lets one card open the words under it without asking
        // the feed again — and without a card rebuilding because a neighbour's
        // thread moved.
        final isOpen = controller.openPost.value == post.id;
        final replies = controller.comments[post.id];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _WallCard(post: post, controller: controller, isOpen: isOpen, replies: replies),
        );
      }),
    ];
  }

  Future<void> _newPrayer(BuildContext context) async {
    var body = '';
    var visibility = 'private';
    var category = 'prayer';
    String? selectedGroup;
    var consent = false;
    final joined = controller.groups
        .where((group) => group['membership_status'] == 'approved')
        .toList();
    final result =
        await showDialog<
          ({String body, String category, String visibility, String? group, bool consent})
        >(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const AppText('Prayer request'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: body,
                      maxLines: 4,
                      onChanged: (value) => setState(() => body = value),
                      decoration: InputDecoration(labelText: 'What would you like prayer for?'),
                    ),
                    const SizedBox(height: 12),
                    // Which wall the request belongs on is the writer's choice, and the
                    // three answers are the server's own categories rather than a list
                    // this screen invented.
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Which wall?'),
                      items: PrayerCategory.values
                          .map(
                            (option) =>
                                DropdownMenuItem(value: option.value, child: AppText(option.label)),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        if (value != null) category = value;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: visibility,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Who can see this?'),
                      items: const [
                        DropdownMenuItem(value: 'private', child: AppText('Only me')),
                        DropdownMenuItem(value: 'group', child: AppText('My group')),
                        DropdownMenuItem(value: 'public', child: AppText('Community prayer wall')),
                      ],
                      onChanged: (value) => setState(() {
                        if (value != null) {
                          visibility = value;
                          consent = false;
                        }
                      }),
                    ),
                    if (visibility == 'group') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedGroup,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: 'Group'),
                        items: joined
                            .map(
                              (group) => DropdownMenuItem(
                                value: group['id'] as String,
                                child: AppText(group['name'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => selectedGroup = value),
                      ),
                    ],
                    if (visibility != 'private')
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: consent,
                        onChanged: (value) => setState(() => consent = value ?? false),
                        title: AppText(
                          visibility == 'public'
                              ? 'I consent to sharing this publicly after moderator review.'
                              : 'I consent to sharing this with my group after leader review.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    if (visibility == 'group' && joined.isEmpty)
                      const AppText('Join a group before sharing a group prayer request.'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const AppText('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      body.trim().isEmpty ||
                          (visibility != 'private' && !consent) ||
                          (visibility == 'group' && selectedGroup == null)
                      ? null
                      : () => Navigator.pop(dialogContext, (
                          body: body.trim(),
                          category: category,
                          visibility: visibility,
                          group: selectedGroup,
                          consent: consent,
                        )),
                  child: const AppText('Save'),
                ),
              ],
            ),
          ),
        );
    if (result != null) {
      await controller.createPrayer(
        body: result.body,
        visibility: result.visibility,
        groupId: result.group,
        shareConsent: result.consent,
        category: result.category,
      );
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

/// One request on the wall, printed the way the ministry prints it: whose it
/// is, what they wrote in their own words, how many are standing with them,
/// and the encouragement underneath.
class _WallCard extends StatelessWidget {
  const _WallCard({
    required this.post,
    required this.controller,
    required this.isOpen,
    required this.replies,
  });

  final PrayerPost post;
  final CommunityController controller;
  final bool isOpen;
  final List<PrayerComment>? replies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrivate = post.visibility == 'private';
    final category = PrayerCategory.tryParse(post.category);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UdmAvatar(initials: post.initials, size: 38, photoUrl: post.ownerPhotoUrl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(post.ownerName, style: theme.textTheme.titleSmall),
                    // The wall is the ministry's diary, so every entry carries
                    // the day it was written in the device's own calendar words.
                    AppText(
                      MaterialLocalizations.of(context).formatMediumDate(post.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (post.isOwner)
                IconButton(
                  tooltip: 'Delete my request',
                  icon: const Icon(AppIcons.delete),
                  onPressed: () => controller.deletePrayer(post.id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppText(
            post.body,
            style: AppTypography.scriptureBody(theme.textTheme.bodyMedium!.color!)
                .copyWith(fontSize: 17, height: 1.55),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (category != null)
                MetaPill(
                  label: category.label,
                  icon: category == PrayerCategory.testimony ? AppIcons.quote : AppIcons.heart,
                ),
              MetaPill(
                label: post.visibility,
                tone: isPrivate ? AppColors.secondaryText : AppColors.success,
              ),
              if (post.moderationState == 'pending')
                const MetaPill(label: 'Waiting for review', icon: AppIcons.clock),
              if (post.moderationState == 'rejected')
                const MetaPill(label: 'Not published', icon: AppIcons.close),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _WallAction(
                icon: AppIcons.heart,
                label: post.affirmationCount > 0 ? '${post.affirmationCount}' : 'Pray for this',
                active: post.affirmed,
                onTap: () => controller.toggleAffirm(post),
              ),
              const SizedBox(width: AppSpacing.lg),
              _WallAction(
                icon: AppIcons.comment,
                label: post.commentCount > 0 ? '${post.commentCount}' : 'Encourage',
                active: isOpen,
                onTap: () => controller.toggleComments(post),
              ),
            ],
          ),
          if (isOpen) _CommentThread(post: post, controller: controller, rows: replies),
        ],
      ),
    );
  }
}

/// A count that is also the verb: tapping a number promises the prayer, or
/// opens the words under it.
class _WallAction extends StatelessWidget {
  const _WallAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? AppColors.success : theme.textTheme.bodySmall?.color;
    return Semantics(
      button: true,
      child: PressableScale(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.xs),
            AppText(label, style: theme.textTheme.labelMedium?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// The words under one request, and the field that adds to them.
class _CommentThread extends StatefulWidget {
  const _CommentThread({required this.post, required this.controller, required this.rows});

  final PrayerPost post;
  final CommunityController controller;

  /// Null while the server is still answering, empty when there is nothing
  /// said yet — the card shows the difference.
  final List<PrayerComment>? rows;

  @override
  State<_CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<_CommentThread> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final words = _input.text.trim();
    if (words.isEmpty) return;
    FocusScope.of(context).unfocus();
    await widget.controller.addComment(widget.post, words);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = widget.rows;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          if (rows == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: UdmProgress()),
            )
          else ...[
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppText(
                  'No words yet. Be the first to encourage.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ...rows.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The same face rule as the card above: the writer's own
                    // picture when they publish one, initials underneath.
                    UdmAvatar(
                      initials: UdmAvatar.initialsFor(comment.authorName),
                      size: 26,
                      photoUrl: comment.authorPhotoUrl,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(comment.authorName, style: theme.textTheme.labelLarge),
                          const SizedBox(height: 2),
                          AppText(
                            comment.body,
                            style: AppTypography.scriptureBody(theme.textTheme.bodyMedium!.color!)
                                .copyWith(fontSize: 15.5, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    // The endpoint only ever accepts the writer's own delete,
                    // so the control appears on exactly those rows.
                    if (comment.isOwner)
                      IconButton(
                        tooltip: 'Remove my word',
                        icon: const Icon(AppIcons.delete, size: 18),
                        onPressed: () => widget.controller.removeComment(widget.post, comment.id),
                      ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(labelText: 'Write a word'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(onPressed: _send, child: AppText('Send')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// An expandable directory or group entry on the brand tile.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

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
          : AppText(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
