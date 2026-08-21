import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_l10n.dart';
import 'base_dashboard_card.dart';

class CoolantLevelCard extends ConsumerWidget {
  const CoolantLevelCard({
    super.key,
    this.value = '--',
    this.statusText = 'Unknown',
  });

  final String value;

  final String statusText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    // The provider stores English tokens; map them to the active language.
    final localizedValue = switch (value) {
      'Available' => l.available,
      'Low' => l.low,
      '--' => '--',
      _ => value,
    };

    final localizedStatus = switch (statusText) {
      'Needs attention' => l.needsAttention,
      'Normal' => l.normal,
      'Unknown' => l.unknown,
      _ => statusText,
    };

    return BaseDashboardCard(
      title: l.coolantLevel,
      value: localizedValue,
      subtitle: l.coolantReservoirInfo,
      statusText: localizedStatus,
    );
  }
}
