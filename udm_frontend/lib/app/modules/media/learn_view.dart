import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/formatted_content.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/media_collection.dart';
import '../../data/models/resume_item.dart';
import 'learn_controller.dart';

/// Teaching library arranged like a visual learning dashboard.
class LearnView extends GetView<LearnController> {
  const LearnView({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final shelves = controller.shelves.toList();
    final featured =
        controller.featuredShelf.value ??
        (shelves.isEmpty ? null : shelves.first);

    return StateView(
      state: controller.state.value,
      failureMessage: controller.failureMessage.value,
      onRetry: controller.load,
      emptyTitle: 'No recordings published yet',
      emptyMessage: 'When the ministry team publishes a teaching series, it will appear here.',
      child: ColoredBox(
        color: const Color(0xFFF7FAFF),
        child: RefreshIndicator(
          color: AppColors.primaryBlue,
          onRefresh: controller.load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (featured != null)
                SliverToBoxAdapter(
                  child: _LearnFeatureHero(
                    shelf: featured,
                    offline: controller.isOfflineCopy,
                    onWatch: controller.openFeatured,
                  ),
                ),
              const SliverToBoxAdapter(child: _ContinueWatching()),
              if (shelves.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _BrowseHeading(
                    onSeeAll: () => _showAllSeries(context, shelves),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(17, 0, 17, 26),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: coverColumns(
                        MediaQuery.sizeOf(context).width,
                      ),
                      mainAxisSpacing: 13,
                      crossAxisSpacing: 13,
                      childAspectRatio: 1.25,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final shelf = shelves[index];
                      return _SeriesCard(
                        shelf: shelf,
                        onOpen: () => controller.openShelf(shelf),
                      );
                    }, childCount: shelves.length),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  });
}

class _LearnFeatureHero extends StatelessWidget {
  const _LearnFeatureHero({
    required this.shelf,
    required this.offline,
    required this.onWatch,
  });

  final MediaCollection shelf;
  final bool offline;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(17, 8, 17, 0),
      child: Container(
        height: 355,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF073A83),
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.float,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverArt(
              url: shelf.imageUrl,
              monogram: shelf.monogram,
              radius: 0,
              monogramSize: 48,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xC40739A0),
                    Color(0x27144A83),
                    Color(0xF500173F),
                  ],
                  stops: [0, .38, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(21, 20, 21, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Learn',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: AppFonts.scripture,
                                fontSize: 41,
                                height: 1.03,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Grow in God’s Word',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: .92),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (offline) const OfflineChip(onDark: true),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .17),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .32),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'FEATURED TEACHING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: .7,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FormattedContent(
                    shelf.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: AppFonts.scripture,
                      fontSize: 29,
                      height: 1.04,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    shelf.description.isEmpty
                        ? 'Discover the beauty and purpose of God’s Word.'
                        : shelf.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .88),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: onWatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.deepBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 17),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      icon: const Icon(AppIcons.play, size: 17),
                      label: const Text(
                        'Watch Now',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ContinueWatching extends GetView<LearnController> {
  const _ContinueWatching();

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.resume.isEmpty) return const SizedBox.shrink();
    final items = controller.resume.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'Continue Watching',
          icon: AppIcons.playCircle,
          onSeeAll: () => _showResume(context, controller, items),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: _ResumeCard(
            item: items.first,
            onTap: () => controller.openRecording(items.first),
          ),
        ),
      ],
    );
  });
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.item, required this.onTap});

  final ResumeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(21),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: Container(
        height: 126,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: AppColors.mist.withValues(alpha: .8)),
          boxShadow: AppShadows.card(AppColors.mist),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverArt(
                    url: item.imageUrl,
                    monogram: UdmAvatar.initialsFor(item.title),
                    radius: 12,
                    icon: AppIcons.play,
                  ),
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        AppIcons.play,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontFamily: AppFonts.scripture,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Series: ${item.collectionTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: LinearProgressIndicator(
                            value: item.progress,
                            minHeight: 6,
                            backgroundColor: AppColors.mist,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(item.progress * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 36, color: AppColors.mist),
                      const SizedBox(width: 8),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBlue,
                        ),
                        child: const Icon(
                          AppIcons.play,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BrowseHeading extends StatelessWidget {
  const _BrowseHeading({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => _SectionHeading(
    title: 'Browse Series',
    icon: Icons.grid_view_rounded,
    onSeeAll: onSeeAll,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.icon,
    required this.onSeeAll,
  });

  final String title;
  final IconData icon;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 17, 11),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.deepBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
            ),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.deepBlue,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: const Row(
            children: [
              Text('See All', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(width: 2),
              Icon(AppIcons.next, size: 18, color: AppColors.primaryBlue),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.shelf, required this.onOpen});

  final MediaCollection shelf;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(19),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppColors.mist),
          boxShadow: AppShadows.card(AppColors.mist),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverArt(url: shelf.imageUrl, monogram: shelf.monogram, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xD900183F)],
                  stops: [.28, 1],
                ),
              ),
            ),
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${shelf.itemCount} ${shelf.itemCount == 1 ? 'lesson' : 'lessons'}',
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 11,
              right: 8,
              bottom: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shelf.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.scripture,
                        fontSize: 15,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.chevron,
                      color: AppColors.deepBlue,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showAllSeries(
  BuildContext context,
  List<MediaCollection> shelves,
) async {
  final controller = Get.find<LearnController>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(
              'Browse Series',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          for (final shelf in shelves)
            ListTile(
              leading: CoverArt(
                url: shelf.imageUrl,
                monogram: shelf.monogram,
                width: 60,
                height: 48,
                radius: 8,
              ),
              title: Text(shelf.title),
              subtitle: Text('${shelf.itemCount} lessons'),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.openShelf(shelf);
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> _showResume(
  BuildContext context,
  LearnController controller,
  List<ResumeItem> items,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(
              'Continue Watching',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          for (final item in items)
            ListTile(
              leading: CoverArt(
                url: item.imageUrl,
                monogram: UdmAvatar.initialsFor(item.title),
                width: 64,
                height: 48,
                radius: 8,
                icon: AppIcons.play,
              ),
              title: Text(item.title),
              subtitle: Text(
                '${item.collectionTitle} · ${item.remainingLabel}',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.openRecording(item);
              },
            ),
        ],
      ),
    ),
  );
}
