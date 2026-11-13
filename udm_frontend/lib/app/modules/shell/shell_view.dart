import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../bible/bible_view.dart';
import '../devotions/devotions_view.dart';
import '../home/home_view.dart';
import '../media/learn_view.dart';
import '../profile/profile_view.dart';
import 'shell_controller.dart';

class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  static const List<Widget> tabs = [
    HomeView(),
    DevotionsView(),
    BibleView(),
    LearnView(),
    ProfileView(),
  ];

  static const List<_Tab> _items = [
    _Tab('Home', AppIcons.home),
    _Tab('Devotions', AppIcons.bookOpen),
    _Tab('Bible', AppIcons.bible),
    _Tab('Learn', AppIcons.learn),
    _Tab('Profile', AppIcons.profile),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() => IndexedStack(index: controller.tab.value, children: tabs)),
      bottomNavigationBar: Obx(
        () => _TabBar(
          key: const Key('udm.tabBar'),
          items: _items,
          index: controller.tab.value,
          onSelect: controller.select,
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The stock `NavigationBar` caps its indicator at a flat tonal blob that
/// appears where you tap. This one slides one brand pill between the tabs, so
/// the bar reads as a single control being moved rather than five buttons, and
/// keeps the labels legible at 320dp — the widest screen a student here does
/// not have.
class _TabBar extends StatelessWidget {
  const _TabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
  });

  final List<_Tab> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;

    return Material(
      color: surfaces.elevated,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surfaces.elevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
              border: Border.all(color: surfaces.hairline),
              boxShadow: AppShadows.raised(surfaces.shadowTint, dark: theme.brightness == Brightness.dark),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  AnimatedPositionedDirectional(
                    duration: AppMotion.quick,
                    curve: AppMotion.standard,
                    top: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    start: constraints.maxWidth / items.length * index,
                    width: constraints.maxWidth / items.length,
                    child: const _ActivePill(),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _TabItem(
                            tab: items[i],
                            selected: i == index,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSelect(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill the selected tab sits in. It is one widget moved by
/// `AnimatedPositionedDirectional`, which is what makes the bar glide instead
/// of flashing a new highlight at each tap.
class _ActivePill extends StatelessWidget {
  const _ActivePill();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          gradient: AppGradients.hero,
          borderRadius: BorderRadius.circular(AppSpacing.radiusField),
          boxShadow: AppShadows.glow(AppColors.primaryBlue),
        ),
      );
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.quick,
                child: Icon(
                  tab.icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected ? AppColors.white : theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AppText(
                  tab.label.tr,
                  // The label sits inside the gradient pill, so it is white
                  // while selected rather than the brand blue it wears outside.
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 0.1,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.white : theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

