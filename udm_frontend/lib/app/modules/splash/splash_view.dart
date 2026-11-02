import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../core/widgets/state_view.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Centered(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const UdmLogo(size: 96, showWordmark: false),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'University Discipleship Mission',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Know Christ. Grow in Christ. Make Disciples.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
                ),
                const SizedBox(height: AppSpacing.xl),
                const UdmProgress(),
              ],
            ),
          ),
        ),
      );
}
