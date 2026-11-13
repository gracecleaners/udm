import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import 'bible_controller.dart';

/// Scripture in three motions: look a reference up, choose a book and chapter
/// and read it, and keep what mattered.
///
/// The reading bar is the whole design problem here. A dropdown for the book
/// and another for the chapter hide the size of the library behind two taps; a
/// testament choice, a book rail and a chapter rail show the canon as the
/// student already thinks about it.
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
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: _Header(translation: translation, offline: controller.offline.value),
              ),
              if (controller.offline.value) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  // The full sentence needs the width a pill cannot give it: this
                  // chapter is on the device, not on the network.
                  child: const NoticeBanner(message: 'Offline copy · saved on this device'),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: _ReferenceLookup(controller: controller, theme: theme),
              ),
              if (translation != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _ReadingBar(controller: controller, theme: theme),
              ],
              if (controller.message.value.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: AppText(controller.message.value, style: theme.textTheme.bodySmall),
                ),
              ],
              if (translation == null) ...[
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: AppText(
                    'No translation has been synced into this deployment yet, so '
                    'reading a whole chapter is not possible. Reference lookup '
                    'still works and opens licensed versions on an authorized site.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: verses.isEmpty && controller.busy.value
                      ? const _ReadingSkeleton()
                      : _ScriptureBlock(
                          heading: chapterHeading(controller),
                          translationCode: '${translation['code'] ?? ''}',
                          verses: verses,
                          onSave: controller.bookmark,
                          onNote: controller.note,
                        ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: controller.session.isSignedIn
                    ? _SavedVerses(controller: controller, theme: theme)
                    : _KeepPrompt(theme: theme),
              ),
              if (controller.plans.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const RailHeader(eyebrow: 'Go with a group', title: 'Reading plans'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: Column(
                    children: [
                      for (final plan in controller.plans)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _PlanCard(plan: plan, controller: controller, theme: theme),
                        ),
                    ],
                  ),
                ),
              ],
              if (translation != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: _Licensing(translation: translation, theme: theme),
                ),
              ],
            ],
          ),
        );
      });

  /// The chapter's own name, taken from the response the server sent rather
  /// than from what the pickers currently show.
  static String chapterHeading(BibleController controller) {
    final data = controller.chapterData.value;
    final book = data?['book'] as String? ?? '';
    final number = data?['number'];
    if (book.isEmpty) return controller.selectedBook.value;
    return number == null ? book : '$book $number';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.translation, required this.offline});

  final Map<String, dynamic>? translation;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = translation;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('Licensed Scripture', color: theme.colorScheme.primary, icon: AppIcons.bible),
              const SizedBox(height: 9),
              AppText('Bible', style: AppTypography.editorialTitle(theme.textTheme.bodyLarge!.color!, size: 34)),
              const SizedBox(height: 5),
              AppText(
                row == null
                    ? 'Search any reference, or pick a translation to read through.'
                    : '${row['name']} · ${row['license_name']}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (offline) ...[
          const SizedBox(width: AppSpacing.sm),
          const MetaPill(label: 'Offline', icon: AppIcons.offline),
        ],
      ],
    );
  }
}

/// Translation choice, then the canon itself: a testament, a book, a chapter.
///
/// Each control gets a share of the row rather than a fixed width, so a long
/// book name cannot push a 320dp screen past its edge.
class _ReadingBar extends StatelessWidget {
  const _ReadingBar({required this.controller, required this.theme});

  final BibleController controller;
  final ThemeData theme;

  static const _testaments = ['old', 'new'];
  static const _testamentLabels = ['Old Testament', 'New Testament'];

  @override
  Widget build(BuildContext context) {
    final books = controller.books;
    // The testament is read off the book the student is already on, and the
    // book rail is filtered by it: the pills are a lens on the canon, not a
    // second selection the student has to keep in agreement with the first.
    final present = [
      for (final testament in _testaments)
        if (books.any((b) => b['testament'] == testament)) testament,
    ];
    final selected = _testamentOf(controller.selectedBook.value, books) ??
        (present.isEmpty ? null : present.first);
    final shown = selected == null
        ? books
        : books.where((b) => b['testament'] == selected).toList();

    return Panel(
      gradient: AppGradients.tint(theme.colorScheme.surface, theme.extension<AppSurfaces>()!.scripture),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.translations.length > 20) ...[
            TextField(
              decoration: InputDecoration(
                labelText: 'Find a translation'.tr,
                prefixIcon: const Icon(AppIcons.search),
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
          if (books.isEmpty)
            AppText('This translation has no books released yet.', style: theme.textTheme.bodySmall)
          else ...[
            const Eyebrow('Testament'),
            const SizedBox(height: AppSpacing.sm),
            PillSelector(
              options: [for (final testament in present) _testamentLabels[_testaments.indexOf(testament)]],
              selectedIndex: selected == null ? -1 : present.indexOf(selected),
              onSelect: (index) {
                final wanted = present[index];
                controller.selectBook(
                  controller.bookKey(books.firstWhere((b) => b['testament'] == wanted)),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const Eyebrow('Book'),
            const SizedBox(height: AppSpacing.sm),
            DiscoveryRail(
              height: 78,
              children: [
                for (final book in shown)
                  _BookChip(
                    name: book['name'] as String? ?? '',
                    chapters: (book['chapter_count'] as num?)?.toInt() ?? 0,
                    selected: controller.bookKey(book) == controller.selectedBook.value,
                    onTap: () => controller.selectBook(controller.bookKey(book)),
                  ),
              ],
            ),
            if (controller.chapterNumbers.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              const Eyebrow('Chapter'),
              const SizedBox(height: AppSpacing.sm),
              DiscoveryRail(
                height: 44,
                children: [
                  for (final number in controller.chapterNumbers)
                    _ChapterChip(
                      number: number,
                      selected: number == controller.selectedChapter.value,
                      onTap: () {
                        controller.selectedChapter.value = number;
                        controller.loadChapter();
                      },
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Which testament a chosen book key belongs to, or null when nothing is
  /// chosen yet.
  String? _testamentOf(String bookKey, List<Map<String, dynamic>> books) {
    if (bookKey.isEmpty) return null;
    final book = books.firstWhereOrNull((b) => controller.bookKey(b) == bookKey);
    final testament = book?['testament'] as String?;
    return _testaments.contains(testament) ? testament : null;
  }
}

class _BookChip extends StatelessWidget {
  const _BookChip({
    required this.name,
    required this.chapters,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int chapters;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return SizedBox(
      width: 116,
      child: PressableScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 11),
          decoration: selected
              ? BoxDecoration(
                  gradient: AppGradients.hero,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
                  boxShadow: AppShadows.glow(AppColors.primaryBlue),
                )
              : BoxDecoration(
                  color: surfaces.scripture,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
                  border: Border.all(color: surfaces.hairline),
                ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                name,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? AppColors.white : theme.textTheme.bodyLarge?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              AppText(
                chapters == 0 ? '—' : '$chapters chapters',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: selected ? Colors.white70 : theme.textTheme.bodySmall?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterChip extends StatelessWidget {
  const _ChapterChip({required this.number, required this.selected, required this.onTap});

  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return SizedBox(
      width: 46,
      height: 44,
      child: PressableScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusField),
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.standard,
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  gradient: AppGradients.hero,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusField),
                  boxShadow: AppShadows.glow(AppColors.primaryBlue),
                )
              : BoxDecoration(
                  color: surfaces.scripture,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusField),
                  border: Border.all(color: surfaces.hairline),
                ),
          child: AppText(
            '$number',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.white : theme.textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// The chapter as one passage, not as a stack of cards: a single surface, a
/// verse gutter, and scripture set in the reading serif all the way down.
class _ScriptureBlock extends StatelessWidget {
  const _ScriptureBlock({
    required this.heading,
    required this.translationCode,
    required this.verses,
    required this.onSave,
    required this.onNote,
  });

  final String heading;
  final String translationCode;
  final List<dynamic> verses;
  final ValueChanged<String> onSave;
  final ValueChanged<String> onNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (verses.isEmpty) {
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(heading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 3),
            AppText(
              'This chapter has no text in the copy saved on this device. Pull to refresh, '
              'or look the passage up by reference.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradients.scripture,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
        boxShadow: AppShadows.float,
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(heading, style: AppTypography.scriptureReference(theme.colorScheme.primary)),
              ),
              if (translationCode.isNotEmpty) MetaPill(label: translationCode.toUpperCase()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const GoldRule(),
          const SizedBox(height: AppSpacing.lg),
          for (final raw in verses)
            _VerseLine(
              number: '${(raw as Map<String, dynamic>)['number'] ?? raw['verse']}',
              text: '${raw['text'] ?? ''}',
              verseId: '${raw['id'] ?? ''}',
              onSave: onSave,
              onNote: onNote,
            ),
        ],
      ),
    );
  }
}

class _VerseLine extends StatelessWidget {
  const _VerseLine({
    required this.number,
    required this.text,
    required this.verseId,
    required this.onSave,
    required this.onNote,
  });

  final String number;
  final String text;
  final String verseId;
  final ValueChanged<String> onSave;
  final ValueChanged<String> onNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Private saves need a stored verse, so a row that only exists at a
    // provider carries no menu rather than promising what cannot be kept.
    final savable = verseId.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AppText(number, style: AppTypography.verseNumber(AppColors.gold)),
            ),
          ),
          Expanded(
            child: AppText(
              text,
              style: AppTypography.scriptureBody(theme.textTheme.bodyLarge!.color!).copyWith(fontSize: 17.5),
            ),
          ),
          if (savable)
            PopupMenuButton<String>(
              tooltip: 'Verse actions'.tr,
              offset: const Offset(0, 34),
              icon: Icon(AppIcons.more, size: 18, color: theme.textTheme.bodySmall?.color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              position: PopupMenuPosition.under,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'bookmark', child: AppText('Bookmark')),
                PopupMenuItem(value: 'note', child: AppText('Add private note')),
              ],
              onSelected: (action) => action == 'bookmark' ? onSave(verseId) : onNote(verseId),
            ),
        ],
      ),
    );
  }
}

class _ReadingSkeleton extends StatelessWidget {
  const _ReadingSkeleton();

  @override
  Widget build(BuildContext context) => Column(
        children: const [
          SkeletonBox(height: 20, width: 120),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 15),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 15, width: 240),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 15),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 15, width: 180),
        ],
      );
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
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconBadge(icon: AppIcons.search, size: 40, filled: false),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('Look up any verse', color: theme.colorScheme.primary),
                        const SizedBox(height: 5),
                        AppText(
                          'Any spelling works: a book, a chapter, or a range.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                        prefixIcon: const Icon(AppIcons.search),
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
                AppText(controller.passageMessage.value, style: theme.textTheme.bodySmall),
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
    final verses = (passage['verses'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();
    final link = passage['deep_link_url'] as String? ?? '';
    final alternate = passage['alternate_link_url'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: theme.extension<AppSurfaces>()!.hairline),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppText(
                '$served · ${passage['reference']}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            AppIconButton(
              icon: AppIcons.close,
              onTap: controller.clearPassage,
              tooltip: 'Clear',
              size: 36,
              iconSize: 18,
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
        const SizedBox(height: AppSpacing.md),
        _ScriptureBlock(
          heading: '${passage['reference'] ?? ''}',
          translationCode: '${passage['translation'] ?? ''}',
          verses: verses.toList(),
          onSave: controller.bookmark,
          // A searched verse carries `verse`; the note dialog wants the stored id.
          onNote: (id) => controller.note(id),
        ),
        if ((passage['attribution'] as String? ?? '').isNotEmpty)
          AppText(passage['attribution'] as String, style: theme.textTheme.bodySmall),
        if (link.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
              icon: const Icon(AppIcons.external, size: 16),
              label: AppText('Open $askedFor on Bible Gateway'),
            ),
          ),
        ],
        if (alternate.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(alternate), mode: LaunchMode.externalApplication),
              icon: const Icon(AppIcons.external, size: 16),
              label: AppText('Open $askedFor on YouVersion'),
            ),
          ),
      ],
    );
  }
}

/// The student's own saved rows, behind one honest header: private, and worth
/// syncing when the network comes back.
class _SavedVerses extends StatelessWidget {
  const _SavedVerses({required this.controller, required this.theme});

  final BibleController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          leading: const IconBadge(icon: AppIcons.bookmarks, size: 40, filled: false),
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
              (saved) => _SavedRow(
                icon: AppIcons.bookmark,
                iconColor: AppColors.primaryBlue,
                title: saved['reference'] as String? ?? 'Saved verse',
                body: saved['text'] as String? ?? '',
                tooltip: 'Remove bookmark',
                onDelete: () => controller.removeBookmark(saved['id'] as String),
              ),
            ),
            ...controller.notes.map(
              (note) => _SavedRow(
                icon: AppIcons.note,
                iconColor: AppColors.gold,
                title: note['reference'] as String? ?? 'Private note',
                body: note['body'] as String? ?? '',
                tooltip: 'Delete note',
                onTap: () => controller.editNote(note),
                onDelete: () => controller.removeNote(note['id'] as String),
              ),
            ),
          ],
        ),
      );
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.tooltip,
    required this.onDelete,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String tooltip;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(title, style: theme.textTheme.titleSmall),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      AppText(body, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              AppIconButton(icon: AppIcons.delete, onTap: onDelete, tooltip: tooltip, size: 36, iconSize: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeepPrompt extends StatelessWidget {
  const _KeepPrompt({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Panel(
        child: Row(
          children: [
            const IconBadge(icon: AppIcons.lock, size: 40, filled: false),
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
      );
}

/// A plan opened: its days, and how far through it the student already is.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.controller, required this.theme});

  final Map<String, dynamic> plan;
  final BibleController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final assignments = (plan['assignments'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final done = assignments.where((a) => a['completed'] == true).length;
    final fraction = assignments.isEmpty ? 0.0 : done / assignments.length;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Column(
        children: [
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            leading: ProgressRing(fraction: fraction, size: 42),
            title: AppText(plan['title'] as String, style: theme.textTheme.titleMedium),
            subtitle: AppText(
              '$done of ${assignments.length} days read',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: UdmProgressBar(fraction: fraction),
          ),
          for (final assignment in assignments)
            _PlanDay(
              assignment: assignment,
              onComplete: () => controller.completeAssignment(assignment['id'] as String),
            ),
        ],
      ),
    );
  }
}

class _PlanDay extends StatelessWidget {
  const _PlanDay({required this.assignment, required this.onComplete});

  final Map<String, dynamic> assignment;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = assignment['completed'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            done ? AppIcons.checkCircle : AppIcons.circle,
            color: done ? AppColors.success : AppColors.secondaryText,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Day ${assignment['day']}', style: theme.textTheme.titleSmall),
                AppText(
                  assignment['reference'] as String? ?? '',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (done)
            const MetaPill(label: 'Done', icon: AppIcons.check, tone: AppColors.success)
          else
            AppIconButton(icon: AppIcons.check, onTap: onComplete, tooltip: 'Mark complete', size: 36, iconSize: 18),
        ],
      ),
    );
  }
}

class _Licensing extends StatelessWidget {
  const _Licensing({required this.translation, required this.theme});

  final Map<String, dynamic> translation;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Panel(
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
                  icon: const Icon(AppIcons.external, size: 16),
                  label: const AppText('Translation license and source'),
                ),
              ),
          ],
        ),
      );
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => CenteredSlot(
        child: MessagePanel(
          icon: AppIcons.book,
          title: 'Scripture unavailable',
          message: message,
          actionLabel: 'Try again',
          onAction: retry,
        ),
      );
}
