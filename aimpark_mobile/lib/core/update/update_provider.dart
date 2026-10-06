import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../router/app_router.dart';
import 'apk_installer.dart';
import 'app_version.dart';
import 'update_config.dart';
import 'update_dialog.dart';
import 'update_manifest.dart';
import 'update_policy.dart';
import 'update_repository.dart';

part 'update_provider.g.dart';

/// A bare [Dio] for the updater, kept deliberately separate from the app's
/// shared `dioProvider` (lib/core/network/dio_client.dart) — that one's
/// interceptor attaches the signed-in user's JWT to every request and signs
/// them out on a 401, neither of which should ever happen against GitHub.
@Riverpod(keepAlive: true)
Dio updateDio(Ref ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
}

@Riverpod(keepAlive: true)
UpdateRepository updateRepository(Ref ref) {
  return UpdateRepository(ref.watch(updateDioProvider));
}

@Riverpod(keepAlive: true)
ApkInstaller apkInstaller(Ref ref) => const ApkInstaller();

@Riverpod(keepAlive: true)
Future<PackageInfo> appPackageInfo(Ref ref) {
  return PackageInfo.fromPlatform();
}

/// Result of a user-initiated "Check for updates" tap (see the Support
/// screen), as opposed to the silent, best-effort [UpdateChecker.checkOnLaunch].
sealed class ManualCheckResult {
  const ManualCheckResult();
}

class ManualCheckUpToDate extends ManualCheckResult {
  const ManualCheckUpToDate();
}

class ManualCheckOffer extends ManualCheckResult {
  const ManualCheckOffer(this.offer);
  final UpdateOffer offer;
}

class ManualCheckError extends ManualCheckResult {
  const ManualCheckError(this.message);
  final String message;
}

/// Runs the update check and owns when the "Update available" dialog gets
/// shown.
///
/// `keepAlive`, like the push-registration notifier it's modelled on
/// (lib/features/notifications/presentation/providers/push_registration_provider.dart):
/// [checkOnLaunch] is fired from the splash screen right before that screen
/// is disposed (`unawaited(...)`, matching the existing push-registration
/// call there), so this notifier has to outlive its caller.
@Riverpod(keepAlive: true)
class UpdateChecker extends _$UpdateChecker {
  bool _checking = false;
  bool _dialogOpen = false;

  @override
  void build() {}

  /// Best-effort, silent, rate-limited. Called once per app launch from
  /// splash. Never throws, never shows an error to the user — an update
  /// check failing is not something a launching app should interrupt anyone
  /// over.
  Future<void> checkOnLaunch() async {
    if (!kReleaseMode) return;
    if (_checking) return;
    _checking = true;

    try {
      final offer = await _resolveOfferUsingCache();
      if (offer == null) return;
      await _maybeShowDialog(offer);
    } catch (error, stackTrace) {
      debugPrint('UpdateChecker.checkOnLaunch failed: $error\n$stackTrace');
    } finally {
      _checking = false;
    }
  }

  /// Always hits the network, ignores the cooldown and the "already
  /// prompted" snooze, and works in every build mode — this is the "Check
  /// for updates" button on the Support screen, and a tap always deserves a
  /// real answer.
  Future<ManualCheckResult> checkManually() async {
    try {
      final repository = ref.read(updateRepositoryProvider);
      final manifest = await repository.fetchManifest();
      await _cacheManifest(manifest);

      final offer = await _evaluate(manifest);
      if (offer == null) return const ManualCheckUpToDate();
      return ManualCheckOffer(offer);
    } catch (error) {
      return ManualCheckError(_friendlyMessage(error));
    }
  }

  Future<UpdateOffer?> _resolveOfferUsingCache() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckedMillis = prefs.getInt(UpdateConfig.prefLastCheckedAt);
    final withinCooldown = lastCheckedMillis != null &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(lastCheckedMillis),
            ) <
            UpdateConfig.checkCooldown;

    final cachedJson = prefs.getString(UpdateConfig.prefCachedManifest);

    UpdateManifest manifest;
    if (withinCooldown && cachedJson != null) {
      manifest = UpdateManifest.fromJson(_decodeCached(cachedJson));
    } else {
      final repository = ref.read(updateRepositoryProvider);
      manifest = await repository.fetchManifest();
      await _cacheManifest(manifest);
    }

    return _evaluate(manifest);
  }

  Future<UpdateOffer?> _evaluate(UpdateManifest manifest) async {
    final packageInfo = await ref.read(appPackageInfoProvider.future);
    final localVersion = AppVersion.tryParse(packageInfo.version);
    final localBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    if (localVersion == null) return null;

    return evaluateUpdate(
      manifest: manifest,
      localVersion: localVersion,
      localBuild: localBuild,
    );
  }

  Future<void> _maybeShowDialog(UpdateOffer offer) async {
    if (_dialogOpen) return;

    final prefs = await SharedPreferences.getInstance();
    if (!offer.isMandatory) {
      final lastVersion = prefs.getString(UpdateConfig.prefLastPromptedVersion);
      final lastPromptedMillis = prefs.getInt(UpdateConfig.prefLastPromptedAt);
      final sameVersionRecentlySnoozed = lastVersion == offer.manifest.version.toString() &&
          lastPromptedMillis != null &&
          DateTime.now().difference(
                DateTime.fromMillisecondsSinceEpoch(lastPromptedMillis),
              ) <
              UpdateConfig.optionalRemindAfter;

      if (sameVersionRecentlySnoozed) return;
    }

    await prefs.setString(
      UpdateConfig.prefLastPromptedVersion,
      offer.manifest.version.toString(),
    );
    await prefs.setInt(
      UpdateConfig.prefLastPromptedAt,
      DateTime.now().millisecondsSinceEpoch,
    );

    // Fetched after the awaits above (rather than before), so there's no
    // async gap between checking `mounted` and actually using the context.
    final context = ref
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (context == null || !context.mounted) return;

    _dialogOpen = true;
    try {
      await UpdateDialog.show(context, offer);
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _cacheManifest(UpdateManifest manifest) async {
    final prefs = await SharedPreferences.getInstance();
    // Re-serializing the already-parsed manifest, rather than caching the raw
    // response body, keeps the cache in the one shape `fromJson` understands
    // even if a future field is added.
    await prefs.setString(
      UpdateConfig.prefCachedManifest,
      _encodeForCache(manifest),
    );
    await prefs.setInt(
      UpdateConfig.prefLastCheckedAt,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _friendlyMessage(Object error) {
    if (error is FormatException) {
      return "Couldn't read the update information. Please try again later.";
    }
    return "Couldn't check for updates. Check your connection and try again.";
  }
}

// --- Small JSON helpers kept local to this file -----------------------------
//
// The cache only ever round-trips a manifest this app already parsed once
// (via UpdateManifest.fromJson), so this is intentionally the minimal glue to
// get a Map back out of shared_preferences, not a general JSON codec.

String _encodeForCache(UpdateManifest manifest) {
  final map = <String, dynamic>{
    'version': manifest.version.toString(),
    'build': manifest.build,
    'apk_url': manifest.apkUrl,
    if (manifest.apkSha256 != null) 'apk_sha256': manifest.apkSha256,
    if (manifest.apkSizeBytes != null) 'apk_size_bytes': manifest.apkSizeBytes,
    'mandatory': manifest.mandatory,
    if (manifest.minSupportedVersion != null)
      'min_supported_version': manifest.minSupportedVersion.toString(),
    'release_notes': manifest.releaseNotes,
  };
  return jsonEncode(map);
}

Map<String, dynamic> _decodeCached(String json) =>
    Map<String, dynamic>.from(jsonDecode(json) as Map);

// --- Download state, scoped to the lifetime of the update dialog -----------

/// What [UpdateDownload] is doing, for [UpdateDialog] to render.
sealed class UpdateDownloadState {
  const UpdateDownloadState();
}

class UpdateDownloadIdle extends UpdateDownloadState {
  const UpdateDownloadIdle();
}

class UpdateDownloadInProgress extends UpdateDownloadState {
  const UpdateDownloadInProgress({required this.received, required this.total});

  final int received;

  /// -1 when the host didn't send a Content-Length (seen with some Google
  /// Drive responses) — the dialog falls back to an indeterminate indicator.
  final int total;
}

class UpdateDownloadNeedsPermission extends UpdateDownloadState {
  const UpdateDownloadNeedsPermission(this.apkPath);
  final String apkPath;
}

class UpdateDownloadReadyToInstall extends UpdateDownloadState {
  const UpdateDownloadReadyToInstall(this.apkPath);
  final String apkPath;
}

class UpdateDownloadFailed extends UpdateDownloadState {
  const UpdateDownloadFailed(this.message);
  final String message;
}

/// Drives the download → verify → install sequence for one update dialog.
///
/// Auto-dispose, unlike [UpdateChecker]: this state belongs to one dialog's
/// lifetime, not to the app's.
@riverpod
class UpdateDownload extends _$UpdateDownload {
  CancelToken? _cancelToken;

  @override
  UpdateDownloadState build() => const UpdateDownloadIdle();

  Future<void> start(UpdateManifest manifest) async {
    _cancelToken = CancelToken();
    state = const UpdateDownloadInProgress(received: 0, total: -1);

    try {
      final repository = ref.read(updateRepositoryProvider);
      final file = await repository.downloadApk(
        manifest,
        onProgress: (received, total) {
          state = UpdateDownloadInProgress(received: received, total: total);
        },
        cancelToken: _cancelToken,
      );

      await _proceedToInstall(file.path);
    } on UpdateDownloadException catch (e) {
      state = UpdateDownloadFailed(e.message);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        state = const UpdateDownloadIdle();
      } else {
        state = const UpdateDownloadFailed(
          "Couldn't download the update. Check your connection and try again.",
        );
      }
    } catch (_) {
      state = const UpdateDownloadFailed(
        'Something went wrong downloading the update. Please try again.',
      );
    }
  }

  Future<void> _proceedToInstall(String apkPath) async {
    final installer = ref.read(apkInstallerProvider);
    if (!await installer.canInstall()) {
      state = UpdateDownloadNeedsPermission(apkPath);
      return;
    }
    await installer.install(apkPath);
    state = UpdateDownloadReadyToInstall(apkPath);
  }

  Future<void> openPermissionSettings() {
    return ref.read(apkInstallerProvider).openInstallPermissionSettings();
  }

  /// Called when the app resumes while the dialog is showing the
  /// "allow installs from this app" prompt, to pick up on the permission
  /// having just been granted without the user needing to tap anything else.
  Future<void> recheckPermission() async {
    final current = state;
    if (current is! UpdateDownloadNeedsPermission) return;

    final installer = ref.read(apkInstallerProvider);
    if (await installer.canInstall()) {
      await installer.install(current.apkPath);
      state = UpdateDownloadReadyToInstall(current.apkPath);
    }
  }

  /// Re-opens the installer — for when the user cancelled it the first time
  /// but the dialog is still open.
  Future<void> retryInstall() async {
    final current = state;
    if (current is UpdateDownloadReadyToInstall) {
      await ref.read(apkInstallerProvider).install(current.apkPath);
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }

  void reset() {
    state = const UpdateDownloadIdle();
  }
}
