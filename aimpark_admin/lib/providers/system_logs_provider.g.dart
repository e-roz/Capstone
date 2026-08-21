// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_logs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userActivityLogsHash() => r'e159afe8f121e5bd58337f0429949f8ba9984a43';

/// See also [userActivityLogs].
@ProviderFor(userActivityLogs)
final userActivityLogsProvider =
    AutoDisposeFutureProvider<UserActivityLogPage>.internal(
      userActivityLogs,
      name: r'userActivityLogsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$userActivityLogsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserActivityLogsRef = AutoDisposeFutureProviderRef<UserActivityLogPage>;
String _$systemErrorLogsHash() => r'56a7fe84f1e9ac2aa826ac681cd8d74235ebb7b3';

/// See also [systemErrorLogs].
@ProviderFor(systemErrorLogs)
final systemErrorLogsProvider =
    AutoDisposeFutureProvider<SystemErrorLogPage>.internal(
      systemErrorLogs,
      name: r'systemErrorLogsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$systemErrorLogsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SystemErrorLogsRef = AutoDisposeFutureProviderRef<SystemErrorLogPage>;
String _$userActivityQueryNotifierHash() =>
    r'9d32851191a33aaa42c3efe8c31f81923b5b9087';

/// See also [UserActivityQueryNotifier].
@ProviderFor(UserActivityQueryNotifier)
final userActivityQueryNotifierProvider =
    AutoDisposeNotifierProvider<
      UserActivityQueryNotifier,
      UserActivityQuery
    >.internal(
      UserActivityQueryNotifier.new,
      name: r'userActivityQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$userActivityQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserActivityQueryNotifier = AutoDisposeNotifier<UserActivityQuery>;
String _$errorLogsPageNotifierHash() =>
    r'5b019ad9ea3e4c80acaaadd1a755a459fa67c7ed';

/// See also [ErrorLogsPageNotifier].
@ProviderFor(ErrorLogsPageNotifier)
final errorLogsPageNotifierProvider =
    AutoDisposeNotifierProvider<ErrorLogsPageNotifier, int>.internal(
      ErrorLogsPageNotifier.new,
      name: r'errorLogsPageNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$errorLogsPageNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ErrorLogsPageNotifier = AutoDisposeNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
