import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/spinning_icon.dart';
import 'base_dashboard_card.dart';

/// Fan status card whose blade icon spins while the fan is running.
class FanStatusCard extends StatelessWidget {
  const FanStatusCard({
    super.key,
    this.value = 'OFF',
    this.statusText = 'Unknown',
  });

  final String value;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final running = value == 'ON';

    return BaseDashboardCard(
      title: 'Radiator Fan',
      value: value,
      subtitle: 'Cooling system fan status',
      statusText: statusText,
      child: Row(
        children: [
          SpinningIcon(
            icon: Icons.air,
            spinning: running,
            size: 32,
            color: running ? AppColors.neonGreen : AppColors.neonAmber,
          ),
        ],
      ),
    );
  }
}
