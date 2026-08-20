import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_l10n.dart';
import 'base_dashboard_card.dart';

class EngineTemperatureCard extends ConsumerWidget {
  const EngineTemperatureCard({
    super.key,
    this.value = '-- °C',
  });

  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    return BaseDashboardCard(
      title: l.engineTemperature,
      value: value,
      subtitle: l.coolantSensorInfo,
      statusText: value == '-- °C' ? l.noData : l.monitoring,
    );
  }
}
