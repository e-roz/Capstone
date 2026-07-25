// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_logs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$auditLogsHash() => r'95b70e9d28094301dbc9e8751f81f0a46f4d9327';

/// See also [auditLogs].
@ProviderFor(auditLogs)
final auditLogsProvider = AutoDisposeFutureProvider<AuditLogPage>.internal(
  auditLogs,
  name: r'auditLogsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$auditLogsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuditLogsRef = AutoDisposeFutureProviderRef<AuditLogPage>;
String _$auditLogsQueryNotifierHash() =>
    r'634b3fd8d738cc6cde5662c13b621ef8d2d59316';

/// See also [AuditLogsQueryNotifier].
@ProviderFor(AuditLogsQueryNotifier)
final auditLogsQueryNotifierProvider =
    AutoDisposeNotifierProvider<
      AuditLogsQueryNotifier,
      AuditLogsQuery
    >.internal(
      AuditLogsQueryNotifier.new,
      name: r'auditLogsQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$auditLogsQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AuditLogsQueryNotifier = AutoDisposeNotifier<AuditLogsQuery>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
