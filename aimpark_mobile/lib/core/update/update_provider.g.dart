// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$updateDioHash() => r'58676624c2dbb5518a923443a23177c82914b050';

/// A bare [Dio] for the updater, kept deliberately separate from the app's
/// shared `dioProvider` (lib/core/network/dio_client.dart) — that one's
/// interceptor attaches the signed-in user's JWT to every request and signs
/// them out on a 401, neither of which should ever happen against GitHub.
///
/// Copied from [updateDio].
@ProviderFor(updateDio)
final updateDioProvider = Provider<Dio>.internal(
  updateDio,
  name: r'updateDioProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$updateDioHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UpdateDioRef = ProviderRef<Dio>;
String _$updateRepositoryHash() => r'7391278b89c580b3746a889196f7743deaf23423';

/// See also [updateRepository].
@ProviderFor(updateRepository)
final updateRepositoryProvider = Provider<UpdateRepository>.internal(
  updateRepository,
  name: r'updateRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$updateRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UpdateRepositoryRef = ProviderRef<UpdateRepository>;
String _$apkInstallerHash() => r'b2fdea4d79cc75df0b37c2ed35c10bb3ab759fd1';

/// See also [apkInstaller].
@ProviderFor(apkInstaller)
final apkInstallerProvider = Provider<ApkInstaller>.internal(
  apkInstaller,
  name: r'apkInstallerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$apkInstallerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ApkInstallerRef = ProviderRef<ApkInstaller>;
String _$appPackageInfoHash() => r'2dd3515f51fdcb01b51d4a3c5a9c489d86823b82';

/// See also [appPackageInfo].
@ProviderFor(appPackageInfo)
final appPackageInfoProvider = FutureProvider<PackageInfo>.internal(
  appPackageInfo,
  name: r'appPackageInfoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appPackageInfoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppPackageInfoRef = FutureProviderRef<PackageInfo>;
String _$updateCheckerHash() => r'c3399652236ac4df87638ac7a4e9f5b5edd3e928';

/// Runs the update check and owns when the "Update available" dialog gets
/// shown.
///
/// `keepAlive`, like the push-registration notifier it's modelled on
/// (lib/features/notifications/presentation/providers/push_registration_provider.dart):
/// [checkOnLaunch] is fired from the splash screen right before that screen
/// is disposed (`unawaited(...)`, matching the existing push-registration
/// call there), so this notifier has to outlive its caller.
///
/// Copied from [UpdateChecker].
@ProviderFor(UpdateChecker)
final updateCheckerProvider = NotifierProvider<UpdateChecker, void>.internal(
  UpdateChecker.new,
  name: r'updateCheckerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$updateCheckerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UpdateChecker = Notifier<void>;
String _$updateDownloadHash() => r'91d8c208de095224d9060a15c42549b5852f1488';

/// Drives the download → verify → install sequence for one update dialog.
///
/// Auto-dispose, unlike [UpdateChecker]: this state belongs to one dialog's
/// lifetime, not to the app's.
///
/// Copied from [UpdateDownload].
@ProviderFor(UpdateDownload)
final updateDownloadProvider =
    AutoDisposeNotifierProvider<UpdateDownload, UpdateDownloadState>.internal(
      UpdateDownload.new,
      name: r'updateDownloadProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$updateDownloadHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UpdateDownload = AutoDisposeNotifier<UpdateDownloadState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
