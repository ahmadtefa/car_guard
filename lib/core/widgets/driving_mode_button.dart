import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/driving_mode_provider.dart';

/// زرار وضع القيادة - يحافظ على الشاشة شغالة أثناء عرض البيانات
class DrivingModeButton extends ConsumerWidget {
  const DrivingModeButton({super.key, this.showLabel = false});

  /// هل يعرض النص بجانب الأيقونة (للفاب أو الشريط الجانبي)
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDrivingMode = ref.watch(drivingModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // تصميم الأيقونة حسب الحالة
    final icon = isDrivingMode
        ? const Icon(Icons.directions_car)
        : const Icon(Icons.directions_car_outlined);

    final tooltip = isDrivingMode
        ? 'إيقاف وضع القيادة - السماح للشاشة بالانطفاء'
        : 'وضع القيادة - إبقاء الشاشة مضاءة';

    if (showLabel) {
      return FilledButton.icon(
        onPressed: () => _toggle(ref, context),
        icon: icon,
        label: Text(isDrivingMode ? 'إيقاف القيادة' : 'وضع القيادة'),
        style: FilledButton.styleFrom(
          backgroundColor:
              isDrivingMode ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          foregroundColor:
              isDrivingMode ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
        ),
      );
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: () => _toggle(ref, context),
      icon: icon,
      isSelected: isDrivingMode,
      selectedIcon: const Icon(Icons.directions_car),
      style: IconButton.styleFrom(
        backgroundColor:
            isDrivingMode ? colorScheme.primaryContainer : null,
        foregroundColor:
            isDrivingMode ? colorScheme.onPrimaryContainer : null,
      ),
    );
  }

  Future<void> _toggle(WidgetRef ref, BuildContext context) async {
    await ref.read(drivingModeProvider.notifier).toggle();
    final isEnabled = ref.read(drivingModeProvider);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isEnabled ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEnabled
                    ? '🚗 وضع القيادة مفعل - الشاشة ستبقى مضاءة'
                    : 'وضع القيادة متوقف - الشاشة ستعمل بشكل طبيعي',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isEnabled ? const Color(0xFF2563EB) : Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// بانر يظهر أعلى الداشبورد عند تفعيل وضع القيادة
class DrivingModeBanner extends ConsumerWidget {
  const DrivingModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDrivingMode = ref.watch(drivingModeProvider);

    if (!isDrivingMode) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.visibility,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وضع القيادة مفعل',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'الشاشة ستبقى مضاءة لعرض البيانات بوضوح',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () =>
                ref.read(drivingModeProvider.notifier).setEnabled(false),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('إيقاف', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
