import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../license/providers/license_provider.dart';
import '../../settings/providers/settings_provider.dart';

/// Password-protected OTA firmware update for the module.
///
/// The code gate keeps casual users away; the file picker accepts a .bin
/// firmware image and uploads it straight to the module's `/update` page.
class OtaUpdatePage extends ConsumerStatefulWidget {
  const OtaUpdatePage({super.key});

  @override
  ConsumerState<OtaUpdatePage> createState() => _OtaUpdatePageState();
}

class _OtaUpdatePageState extends ConsumerState<OtaUpdatePage> {
  static const String _updateCode = '1234';

  final _password = TextEditingController();

  bool _unlocked = false;
  bool _uploading = false;
  String? _passwordError;

  String? _filePath;
  String? _fileName;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _unlock() {
    if (_password.text.trim() == _updateCode) {
      setState(() {
        _unlocked = true;
        _passwordError = null;
      });
    } else {
      setState(() {
        _passwordError = ref.read(l10nProvider).wrongCode;
      });
    }
  }

  Future<void> _pickFile() async {
    final l = ref.read(l10nProvider);

    final result = await FilePicker.platform.pickFiles();

    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final name = result.files.single.name;

    if (!name.toLowerCase().endsWith('.bin')) {
      _snack(l.otaInvalidFile);
      return;
    }

    setState(() {
      _filePath = path;
      _fileName = name;
    });
  }

  Future<void> _upload() async {
    final l = ref.read(l10nProvider);

    if (_filePath == null) {
      _snack(l.otaPickFirst);
      return;
    }

    setState(() => _uploading = true);

    final ok = await ref
        .read(esp8266RepositoryProvider)
        .updateFirmware(_filePath!);

    if (!mounted) return;

    setState(() => _uploading = false);

    if (ok) {
      _snack(l.otaSuccess);
      setState(() {
        _filePath = null;
        _fileName = null;
      });
    } else {
      _snack(l.otaFailed);
    }
  }

  Widget _buildLockScreen(AppL10n l) {
    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update_tv_rounded, size: 56),
            const SizedBox(height: AppSpacing.lg),
            Text(l.otaUpdate, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.enterOtaCode,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _password,
              labelText: l.otaCodeLabel,
              hintText: '••••',
              obscureText: true,
              onSubmitted: (_) => _unlock(),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              onPressed: _unlock,
              child: Text(l.unlock),
            ),
            if (_passwordError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _passwordError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final settingsState = ref.watch(settingsProvider);
    final demoEnabled = settingsState.value?.demoModeEnabled ?? false;
    final moduleLicensed =
        settingsState.value != null &&
        !demoEnabled &&
        ref.watch(licenseAuthorizationProvider);

    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(title: Text(l.otaUpdate)),
        body: _buildLockScreen(l),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.otaUpdate)),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.padding,
          children: [
            if (!moduleLicensed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  l.licenseControlsUnavailable,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            SectionTitle(title: l.otaUpdate, subtitle: l.otaInfo),

            Card(
              child: Padding(
                padding: AppSpacing.padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.memory_rounded),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _fileName ?? l.noFileSelected,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _fileName == null
                                  ? Theme.of(context).colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      onPressed:
                          !_uploading && moduleLicensed ? _pickFile : null,
                      child: Text(l.selectFirmware),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            if (_uploading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              PrimaryButton(
                onPressed: _fileName == null || !moduleLicensed ? null : _upload,
                child: Text(l.uploadAndFlash),
              ),

            if (_uploading)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  l.uploading,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
