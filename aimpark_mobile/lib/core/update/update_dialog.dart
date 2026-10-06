import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme.dart';
import '../widgets/app_progress_bar.dart';
import '../widgets/widgets.dart';
import 'update_manifest.dart';
import 'update_policy.dart';
import 'update_provider.dart';

/// The "Update available" / "Update required" dialog — visually matching
/// [CelebrationDialog] (same rounded container, overlay surface and shadow)
/// but with its own layout: a release-notes list and a state machine across
/// the download/install flow, where [CelebrationDialog] only ever shows one
/// static message and a single button.
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.offer});

  final UpdateOffer offer;

  static Future<void> show(BuildContext context, UpdateOffer offer) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !offer.isMandatory,
      builder: (_) => UpdateDialog(offer: offer),
    );
  }

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Picks up on the "allow installs from this app" permission the moment
    // the user grants it in system settings and returns, without needing a
    // second tap back in the dialog.
    _lifecycleListener = AppLifecycleListener(
      onResume: () =>
          ref.read(updateDownloadProvider.notifier).recheckPermission(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _dismiss() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final manifest = widget.offer.manifest;
    final mandatory = widget.offer.isMandatory;
    final state = ref.watch(updateDownloadProvider);

    return PopScope(
      canPop: !mandatory,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: t.surface.overlay,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: t.border.normal, width: 1.5),
            boxShadow: AppElevation.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Icon(mandatory: mandatory),
              const SizedBox(height: AppSpacing.md),
              Text(
                mandatory ? 'Update required' : 'Update available',
                style: context.text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _subtitle(manifest),
                style: context.text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              _Body(state: state, manifest: manifest),
              const SizedBox(height: AppSpacing.lg),
              ..._actions(context, state, manifest, mandatory),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(UpdateManifest manifest) {
    final sizeMb = manifest.apkSizeBytes != null
        ? ' · ${(manifest.apkSizeBytes! / (1024 * 1024)).toStringAsFixed(0)} MB'
        : '';
    return 'Version ${manifest.version}$sizeMb';
  }

  List<Widget> _actions(
    BuildContext context,
    UpdateDownloadState state,
    UpdateManifest manifest,
    bool mandatory,
  ) {
    final notifier = ref.read(updateDownloadProvider.notifier);

    switch (state) {
      case UpdateDownloadIdle():
        return [
          AppButton(
            label: 'Update now',
            onPressed: () => notifier.start(manifest),
          ),
          if (!mandatory) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Later',
              style: AppButtonStyle.ghost,
              onPressed: _dismiss,
            ),
          ],
        ];

      case UpdateDownloadInProgress():
        return [
          AppButton(
            label: 'Cancel',
            style: AppButtonStyle.ghost,
            onPressed: notifier.cancelDownload,
          ),
        ];

      case UpdateDownloadNeedsPermission():
        return [
          AppButton(
            label: 'Open settings',
            onPressed: notifier.openPermissionSettings,
          ),
          if (!mandatory) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Later',
              style: AppButtonStyle.ghost,
              onPressed: _dismiss,
            ),
          ],
        ];

      case UpdateDownloadReadyToInstall():
        return [
          AppButton(label: 'Install', onPressed: notifier.retryInstall),
          if (!mandatory) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Later',
              style: AppButtonStyle.ghost,
              onPressed: _dismiss,
            ),
          ],
        ];

      case UpdateDownloadFailed():
        return [
          AppButton(
            label: 'Try again',
            onPressed: () => notifier.start(manifest),
          ),
          if (!mandatory) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Later',
              style: AppButtonStyle.ghost,
              onPressed: _dismiss,
            ),
          ],
        ];
    }
  }
}

class _Icon extends StatelessWidget {
  const _Icon({required this.mandatory});

  final bool mandatory;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: t.brand.subtle, shape: BoxShape.circle),
        child: Icon(
          Icons.system_update_rounded,
          color: t.brand.primary,
          size: AppSizes.iconHero,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.manifest});

  final UpdateDownloadState state;
  final UpdateManifest manifest;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case UpdateDownloadIdle():
        if (manifest.releaseNotes.isEmpty) return const SizedBox.shrink();
        return _ReleaseNotes(notes: manifest.releaseNotes);

      case UpdateDownloadInProgress(received: final received, total: final total):
        return _DownloadProgress(received: received, total: total);

      case UpdateDownloadNeedsPermission():
        return Text(
          'To install updates, allow AimPark to install apps. You only have '
          'to do this once.',
          style: context.text.bodyMedium,
          textAlign: TextAlign.center,
        );

      case UpdateDownloadReadyToInstall():
        return Text(
          "If the installer didn't open, tap Install again.",
          style: context.text.bodyMedium,
          textAlign: TextAlign.center,
        );

      case UpdateDownloadFailed(message: final message):
        return Text(
          message,
          style: context.text.bodyMedium?.copyWith(
            color: context.tokens.status.danger.fg,
          ),
          textAlign: TextAlign.center,
        );
    }
  }
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("What's new", style: context.text.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: context.text.bodyMedium),
                      Expanded(
                        child: Text(note, style: context.text.bodyMedium),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.received, required this.total});

  final int received;
  final int total;

  @override
  Widget build(BuildContext context) {
    final knownTotal = total > 0;
    final receivedMb = received / (1024 * 1024);

    if (!knownTotal) {
      final t = context.tokens;
      return Column(
        children: [
          AppLoadingBar(color: t.brand.primary, trackColor: t.surface.muted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Downloading… ${receivedMb.toStringAsFixed(1)} MB',
            style: context.text.bodySmall,
          ),
        ],
      );
    }

    final totalMb = total / (1024 * 1024);
    final fraction = received / total;
    final percent = (fraction * 100).round();

    return Column(
      children: [
        AppProgressBar(value: fraction),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '$percent% · ${receivedMb.toStringAsFixed(1)} of '
          '${totalMb.toStringAsFixed(1)} MB',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}
