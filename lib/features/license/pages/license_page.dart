import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/license_models.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/license_state.dart';
import '../providers/license_provider.dart';

/// License screen shown while the device is LOCKED.
///
/// Purpose is deliberately minimal and non-cryptographic:
///   * show the device serial and that the unit is locked
///   * let the owner paste a Base32 activation code
///   * show a user-friendly activation result
/// It never renders signatures, hashes, keys or any private material, and it
/// never shows vehicle telemetry.
class LicensePage extends ConsumerStatefulWidget {
  const LicensePage({super.key});

  @override
  ConsumerState<LicensePage> createState() => _LicensePageState();
}

class _LicensePageState extends ConsumerState<LicensePage> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = _codeController.text.trim();
    final l = ref.read(l10nProvider);
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.failureCodeEmpty)),
      );
      return;
    }

    final notifier = ref.read(licenseProvider.notifier);
    await notifier.activateLicense(code);

    // If activation succeeded the module re-reported ACTIVE and the home gate
    // already navigated back to the dashboard; a failure keeps us here.
    if (!mounted) return;
    final state = ref.read(licenseProvider);
    if (state.activationState == LicenseActivationState.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.activationSuccess)),
      );
      _codeController.clear();
    }
  }

  String _failureMessage(AppL10n l, LicenseFailureReason? reason) {
    switch (reason) {
      case LicenseFailureReason.invalidCode:
        return l.failureInvalidCode;
      case LicenseFailureReason.invalidSignature:
        return l.failureInvalidSignature;
      case LicenseFailureReason.serialMismatch:
        return l.failureSerialMismatch;
      case LicenseFailureReason.invalidDate:
        return l.failureInvalidDate;
      case LicenseFailureReason.invalidMonths:
        return l.failureInvalidMonths;
      case LicenseFailureReason.ntpUnavailable:
        return l.failureNtpUnavailable;
      case LicenseFailureReason.alreadyUsed:
        return l.failureAlreadyUsed;
      case LicenseFailureReason.permanentAlreadyActive:
        return l.failurePermanentAlreadyActive;
      case LicenseFailureReason.temporaryAlreadyActive:
        return l.failureTemporaryAlreadyActive;
      case LicenseFailureReason.codeEmpty:
        return l.failureCodeEmpty;
      case LicenseFailureReason.publicKeyNotConfigured:
        return l.failurePublicKeyNotConfigured;
      case LicenseFailureReason.eepromCommitFailed:
        return l.failureEepromCommitFailed;
      case LicenseFailureReason.unknown:
      case null:
        return l.failureUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final state = ref.watch(licenseProvider);

    final activating = state.isActivating;

    final failure = state.activationState == LicenseActivationState.failure
        ? _failureMessage(l, state.failureReason)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.licenseTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.padding,
          children: [
            // Locked state header + device serial.
            const SizedBox(height: AppSpacing.lg),
            Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: AppColors.neonAmber,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.licenseLocked,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.licenseLockedInfo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.deviceSerial.isNotEmpty)
              Card(
                child: Padding(
                  padding: AppSpacing.padding,
                  child: Row(
                    children: [
                      const Icon(Icons.tag_rounded, color: AppColors.neonCyan),
                      const SizedBox(width: AppSpacing.md),
                      Text('${l.serialLabel}: '),
                      Expanded(
                        child: Text(
                          state.deviceSerial,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _codeController,
              labelText: l.activationCodeLabel,
              hintText: l.activationCodeHint,
              keyboardType: TextInputType.text,
              enabled: !activating,
              onSubmitted: (_) => activating ? null : _activate(),
            ),

            const SizedBox(height: AppSpacing.lg),

            PrimaryButton(
              onPressed: activating ? null : _activate,
              child: activating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l.activateButton),
            ),

            if (failure != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Card(
                color: AppColors.danger.withAlpha((255 * 0.1).round()),
                child: Padding(
                  padding: AppSpacing.padding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(failure),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
