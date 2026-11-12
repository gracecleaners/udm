import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import 'bible_controller.dart';

class BibleView extends GetView<BibleController> {
  const BibleView({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
        final theme = Theme.of(context);

        // The lookup path needs no synced catalog, so an empty catalog only
        // blocks the tab when the server also told us nothing about versions.
        if (controller.translations.isEmpty && controller.sources.isEmpty) {
          if (controller.busy.value) {
            return const CenteredSlot(child: UdmProgress(label: 'Loading licensed translations…'));
          }
          return _Problem(
            message: controller.message.value.isEmpty
                ? 'No licensed translations are available yet.'
                : controller.message.value,
            retry: controller.load,
          );
        }
        final translation = controller.translations.firstWhereOrNull(
          (t) => t['code'] == controller.selectedTranslation.value,
        );
        final verses = (controller.chapterData.value?['verses'] as List<dynamic>?) ?? const [];

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
            children: [
              SectionHeader(
                eyebrow: 'Licensed Scripture',
                title: 'Bible',
                subtitle: translation == null
                    ? 'Search any reference, or pick a translation to read through.'
                    : '${translation['name']} · ${translation['license_name']}',
                trailing: controller.offline.value ? const MetaPill(label: 'Offline', icon: Icons.cloud_off_rounded) : null,
              ),
              if (controller.offline.value) ...[
                const SizedBox(height: AppSpacing.sm),
                // The full sentence needs the width a pill cannot give it: this
                // chapter is on the device, not on the network.
                const NoticeBanner(message: 'Offline copy · saved on this device'),
              ],
              const SizedBox(height: AppSpacing.md),
              _ReferenceLookup(controller: controller, theme: theme),
              if (translation != null) ...[
                const SizedBox(height: AppSpacing.md),
                _Pickers(
                  controller: controller,
                  translation: translation,
                  theme: theme,
                ),
              ],
              if (controller.message.value.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                AppText(controller.message.value, style: theme.textTheme.bodySmall),
              ],
              if (translation == null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppText(
                  'No translation has been synced into this deployment yet, so '
                  'reading a whole chapter is not possible. Reference lookup '
                  'still works and opens licensed versions on an authorized site.',
                  style: theme.textTheme.bodySmall,
                ),
              ] else ...[
              const SizedBox(height: AppSpacing.lg),
              if (verses.isEmpty && controller.busy.value)
                const Column(
                  children: [
                    SkeletonCard(lines: 1),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonCard(lines: 1),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonCard(lines: 1),
                  ],
                )
              else
                ...verses.map((raw) {
                  final verse = raw as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _VerseRow(
                      number: '${verse['number']}',
                      text: verse['text'] as String,
                      onBookmark: () => controller.bookmark(verse['id'] as String),
                      onNote: () => controller.note(verse['id'] as String),
                    ),
                  );
                }),
              ],
              const SizedBox(height: AppSpacing.md),
              if (controller.session.isSignedIn)
                Panel(
                  padding: EdgeInsets.zero,
                  child: ExpansionTile(
                    shape: const Border(),
                        collapsedShape: const Border(),
                    leading: const IconBadge(icon: Icons.bookmarks_outlined, size: 34, filled: false),
                    title: const AppText('My saved verses and notes'),
                    subtitle: controller.pendingOperations.isEmpty
                        ? null
                        : AppText(
                            '${controller.pendingOperations.length} private change(s) waiting to sync.',
                            style: theme.textTheme.bodySmall,
                          ),
                    onExpansionChanged: (open) {
                      if (open) controller.loadSaved();
                    },
                    children: [
                      if (controller.bookmarks.isEmpty && controller.notes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: AppText('Your saved verses and private notes will appear here.'),
                        ),
                      ...controller.bookmarks.map(
                        (saved) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          leading: const Icon(Icons.bookmark_rounded, color: AppColors.primaryBlue),
                          title: AppText(saved['reference'] as String? ?? 'Saved verse'),
                          subtitle: AppText(saved['text'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            tooltip: 'Remove bookmark'.tr,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => controller.removeBookmark(saved['id'] as String),
                          ),
                        ),
                      ),
                      ...controller.notes.map(
                        (note) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          leading: const Icon(Icons.edit_note_rounded, color: AppColors.gold),
                          title: AppText(note['reference'] as String? ?? 'Private note'),
                          subtitle: AppText(
                            note['body'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => controller.editNote(note),
                          trailing: IconButton(
                            tooltip: 'Delete note'.tr,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => controller.removeNote(note['id'] as String),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Panel(
                  child: Row(
                    children: [
                      const IconBadge(icon: Icons.lock_outline_rounded, size: 38, filled: false),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppText('Keep your bookmarks and notes'),
                            const SizedBox(height: 2),
                            AppText(
                              'Sign in to sync them privately across your devices.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: () => Get.toNamed(AppRoutes.signIn),
                        child: const AppText('Sign in'),
                      ),
                    ],
                  ),
                ),
              if (controller.plans.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  eyebrow: 'Go with a group',
                  title: 'Reading plans',
                ),
                const SizedBox(height: AppSpacing.md),
                ...controller.plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Panel(
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading: const IconBadge(icon: Icons.checklist_rounded, size: 34, filled: false),
                        title: AppText(plan['title'] as String),
                        subtitle: (plan['description'] as String? ?? '').isEmpty
                            ? null
                            : AppText(plan['description'] as String, style: theme.textTheme.bodySmall),
                        children: ((plan['assignments'] as List<dynamic>?) ?? const [])
                            .map((a) {
                              final assignment = a as Map<String, dynamic>;
                              final done = assignment['completed'] == true;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                leading: Icon(
                                  done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                  color: done ? AppColors.success : AppColors.secondaryText,
                                ),
                                title: AppText(
                                  'Day ${assignment['day']}',
                                  style: theme.textTheme.titleSmall,
                                ),
                                subtitle: AppText(assignment['reference'] as String),
                                trailing: done
                                    ? const MetaPill(label: 'Done', icon: Icons.check_rounded, tone: AppColors.success)
                                    : IconButton(
                                        tooltip: 'Mark complete'.tr,
                                        icon: const Icon(Icons.check),
                                        onPressed: () => controller.completeAssignment(assignment['id'] as String),
                                      ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ],
              if (translation != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Panel(
                  radius: AppSpacing.radiusTile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Licensing'),
                      const SizedBox(height: AppSpacing.sm),
                      AppText(translation['attribution'] as String? ?? '', style: theme.textTheme.bodySmall),
                      if ((translation['source_url'] as String? ?? '').startsWith('https://'))
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(translation['source_url'] as String),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const AppText('Translation license and source'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      });
}

/// The translation, book and chapter picks. Each control gets a share of the
/// row rather than a fixed width, so a long book name cannot push a 320dp
/// screen past its edge.
class _Pickers extends StatelessWidget {
  const _Pickers({required this.controller, required this.translation, required this.theme});

  final BibleController controller;
  final Map<String, dynamic>? translation;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Panel(
      gradient: LinearGradient(
        colors: [
          theme.colorScheme.surface,
          theme.extension<AppSurfaces>()!.scripture,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.translations.length > 20) ...[
            TextField(
              decoration: InputDecoration(
                labelText: 'Find a translation'.tr,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (value) => controller.translationQuery.value = value,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (controller.translations.length > 1) ...[
            DropdownButtonFormField<String>(
              key: ValueKey(controller.selectedTranslation.value),
              initialValue: controller.selectedTranslation.value,
              isExpanded: true,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(labelText: 'Translation'.tr),
              // The closed field carries the name alone; the language belongs to
              // the choice, not to the value, and it truncates at 320dp.
              selectedItemBuilder: (_) => controller.visibleTranslations
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t['code'] as String,
                      child: AppText(t['name'] as String, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              items: controller.visibleTranslations
                  .map(
                    (t) => DropdownMenuItem(
                      value: t['code'] as String,
                      child: AppText(
                        '${t['name']} · ${t['language'] ?? 'Unknown language'}',
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  controller.selectedTranslation.value = v;
                  controller.loadBooks();
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(controller.selectedBook.value),
                  initialValue: controller.selectedBook.value.isEmpty ? null : controller.selectedBook.value,
                  isExpanded: true,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(labelText: 'Book'.tr),
                  items: controller.books
                      .map(
                        (b) => DropdownMenuItem(
                          value: (b['provider_id'] as String?)?.isNotEmpty == true
                              ? b['provider_id'] as String
                              : b['name'] as String,
                          child: AppText(b['name'] as String, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) controller.selectBook(v);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('${controller.selectedBook.value}:${controller.selectedChapter.value}'),
                  initialValue: controller.chapterNumbers.isEmpty ? null : controller.selectedChapter.value,
                  isExpanded: true,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(labelText: 'Chapter'.tr),
                  items: controller.chapterNumbers
                      .map((n) => DropdownMenuItem(value: n, child: AppText('$n')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      controller.selectedChapter.value = v;
                      controller.loadChapter();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerseRow extends StatelessWidget {
  const _VerseRow({
    required this.number,
    required this.text,
    this.onBookmark,
    this.onNote,
  });

  final String number;
  final String text;

  /// Null when no stored row stands behind this verse, which is the case for
  /// text that only exists at a provider. Private saves need a stored verse, so
  /// the menu is absent rather than promising what cannot be kept.
  final VoidCallback? onBookmark;
  final VoidCallback? onNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savable = onBookmark != null && onNote != null;
    return Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: AppText(
              number,
              style: TextStyle(
                fontFamily: AppFonts.scripture,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppText(
              text,
              style: AppTypography.scriptureBody(theme.textTheme.bodyLarge!.color!).copyWith(fontSize: 17.5),
            ),
          ),
          if (savable)
            PopupMenuButton<String>(
              tooltip: 'Verse actions'.tr,
              onSelected: (action) =>
                  action == 'bookmark' ? onBookmark!() : onNote!(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'bookmark',
                  child: AppText('Bookmark'),
                ),
                PopupMenuItem(
                  value: 'note',
                  child: AppText('Add private note'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Reference lookup. The backend normalizes the spelling and chooses the source,
/// so typing "1Jn 3:16-18" returns a passage whether or not this deployment has
/// a single verse stored.
class _ReferenceLookup extends StatelessWidget {
  const _ReferenceLookup({required this.controller, required this.theme});

  final BibleController controller;
  final ThemeData theme;

  /// Its own reactive scope: the tab's outer `Obx` cannot see lookups that
  /// happen in a child widget's build, so the panel watches the router state
  /// itself.
  @override
  Widget build(BuildContext context) => Obx(() {
    final sources = controller.sources;
    final passage = controller.passage.value;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('Look up any verse'),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => controller.passageQuery.value = value,
                  onSubmitted: (value) => controller.searchPassage(value),
                  decoration: InputDecoration(
                    labelText: 'Reference'.tr,
                    hintText: 'John 3:16 · 1Jn 3:16-18 · Ps 23'.tr,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: () => controller.searchPassage(),
                child: const AppText('Go'),
              ),
            ],
          ),
          if (sources.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey(controller.passageTranslation.value),
              initialValue: controller.passageTranslation.value,
              isExpanded: true,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(labelText: 'Version'.tr),
              selectedItemBuilder: (_) => sources
                  .map(
                    (row) => DropdownMenuItem<String>(
                      value: row['code'] as String,
                      child: AppText(
                        row['name'] as String,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              items: sources.map(_versionItem).toList(),
              onChanged: (value) {
                if (value != null) controller.selectPassageVersion(value);
              },
            ),
          ],
          if (controller.passageBusy.value) ...[
            const SizedBox(height: AppSpacing.md),
            const UdmProgress(label: 'Finding the passage…'),
          ],
          if (controller.passageMessage.value.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AppText(
              controller.passageMessage.value,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (passage != null) ...[
            const SizedBox(height: AppSpacing.md),
            _PassageResult(
              controller: controller,
              passage: passage,
              theme: theme,
              offline: controller.passageOffline.value,
            ),
          ],
        ],
      ),
    );
  });

  /// A version this app may not print is still offered, because the router
  /// answers it with public-domain text and an authorized link. The suffix says
  /// which way the answer goes, so nothing looks broken when it arrives.
  DropdownMenuItem<String> _versionItem(Map<String, dynamic> row) {
    final name = row['name'] as String? ?? '${row['code']}';
    final note = row['text_available'] != true
        ? 'authorized link only'
        : row['configured'] != true
        ? 'needs a key'
        : null;
    return DropdownMenuItem(
      value: row['code'] as String,
      child: AppText(
        note == null ? name : '$name · $note',
        style: theme.textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _PassageResult extends StatelessWidget {
  const _PassageResult({
    required this.controller,
    required this.passage,
    required this.theme,
    required this.offline,
  });

  final BibleController controller;
  final Map<String, dynamic> passage;
  final ThemeData theme;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final fallback = passage['fallback'] as Map<String, dynamic>?;
    final served = passage['translation_name'] as String? ?? '';
    final askedFor = fallback?['requested_name'] as String? ?? served;
    final verses = (passage['verses'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    final link = passage['deep_link_url'] as String? ?? '';
    final alternate = passage['alternate_link_url'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                '$served · ${passage['reference']}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Clear'.tr,
              onPressed: controller.clearPassage,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        if (offline) ...[
          const SizedBox(height: AppSpacing.xs),
          const NoticeBanner(message: 'Offline copy · saved on this device'),
        ],
        if (fallback != null) ...[
          const SizedBox(height: AppSpacing.xs),
          // The student asked for one version and the app may only lawfully
          // print another; the server explains why, and the header above shows
          // which text actually arrived.
          NoticeBanner(
            message: '${fallback['requested_name']}: ${fallback['reason']}',
            tone: NoticeTone.problem,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        ...verses.map((verse) {
          final id = verse['id'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _VerseRow(
              number: '${verse['verse']}',
              text: verse['text'] as String? ?? '',
              onBookmark: id.isEmpty ? null : () => controller.bookmark(id),
              onNote: id.isEmpty ? null : () => controller.note(id),
            ),
          );
        }),
        if ((passage['attribution'] as String? ?? '').isNotEmpty)
          AppText(
            passage['attribution'] as String,
            style: theme.textTheme.bodySmall,
          ),
        if (link.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: AppText('Open $askedFor on Bible Gateway'),
            ),
          ),
        ],
        if (alternate.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(alternate),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: AppText('Open $askedFor on YouVersion'),
            ),
          ),
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => CenteredSlot(
        child: MessagePanel(
          icon: Icons.menu_book_outlined,
          title: 'Scripture unavailable',
          message: message,
          actionLabel: 'Try again',
          onAction: retry,
        ),
      );
}
