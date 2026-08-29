// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$backupListHash() => r'1de34dadc09bccff50d91896acba819a91e5ca25';

/// See also [backupList].
@ProviderFor(backupList)
final backupListProvider = AutoDisposeFutureProvider<List<BackupFile>>.internal(
  backupList,
  name: r'backupListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$backupListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BackupListRef = AutoDisposeFutureProviderRef<List<BackupFile>>;
String _$backupActionsHash() => r'cf7c8bc43fd397af52186cd515451fe58db38960';

/// See also [BackupActions].
@ProviderFor(BackupActions)
final backupActionsProvider =
    AutoDisposeNotifierProvider<BackupActions, AsyncValue<void>>.internal(
      BackupActions.new,
      name: r'backupActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$backupActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BackupActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
