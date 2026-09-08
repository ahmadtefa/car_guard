import 'package:flutter/material.dart';

import '../l10n/app_l10n.dart';
import 'esp8266_repository.dart';

/// Shows the single destructive Factory Reset confirmation and sends the
/// existing `/factoryreset` request after explicit confirmation.
///
/// `null` means the user cancelled or another reset already owns the provider
/// lock. A non-null value is the device-confirmed result; the repository only
/// returns true after the ESP8266 answers `200 OK` for its committed reset
/// transaction. The lifecycle callbacks make every UI entry point use the
/// same provider/repository serialization.
Future<bool?> runFactoryResetAction({
  required BuildContext context,
  required AppL10n l,
  required Esp8266Repository repository,
  required bool Function() beginFactoryReset,
  required void Function(bool success) finishFactoryReset,
}) async {
  if (!beginFactoryReset()) return null;

  bool? result;
  try {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.factoryResetModule),
        content: Text(l.factoryResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.factoryResetModule),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;
    result = await repository.factoryResetModule();
  } catch (_) {
    result = false;
  } finally {
    finishFactoryReset(result == true);
  }

  return result;
}
