import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';

/// Dashboard entry to the "التنبيهات والتحليل" page.
class AnalysisEntryCard extends ConsumerWidget {
  const AnalysisEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push('/alerts-analysis'),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.analytics_outlined,
              color: AppColors.primary),
        ),
        title: Text(l.alertsAnalysis),
        subtitle: Text(l.alertsAnalysisSubtitle),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          matchTextDirection: true,
        ),
      ),
    );
  }
}
