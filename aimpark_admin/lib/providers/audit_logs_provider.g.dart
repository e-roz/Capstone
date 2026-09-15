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
String _$userAuditLogsHash() => r'0b1c2742d1ac60a2b175de03593c0ceee5090720';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// One account's admin history, for the registration detail screen.
///
/// Deliberately its own request rather than a filtered read of
/// [auditLogsProvider] — that provider's query is shared, paged state driven
/// by the System Logs screen, and watching it here would tie a detail
/// screen's history strip to whatever page a reviewer happened to leave the
/// log list on.
///
/// Copied from [userAuditLogs].
@ProviderFor(userAuditLogs)
const userAuditLogsProvider = UserAuditLogsFamily();

/// One account's admin history, for the registration detail screen.
///
/// Deliberately its own request rather than a filtered read of
/// [auditLogsProvider] — that provider's query is shared, paged state driven
/// by the System Logs screen, and watching it here would tie a detail
/// screen's history strip to whatever page a reviewer happened to leave the
/// log list on.
///
/// Copied from [userAuditLogs].
class UserAuditLogsFamily extends Family<AsyncValue<AuditLogPage>> {
  /// One account's admin history, for the registration detail screen.
  ///
  /// Deliberately its own request rather than a filtered read of
  /// [auditLogsProvider] — that provider's query is shared, paged state driven
  /// by the System Logs screen, and watching it here would tie a detail
  /// screen's history strip to whatever page a reviewer happened to leave the
  /// log list on.
  ///
  /// Copied from [userAuditLogs].
  const UserAuditLogsFamily();

  /// One account's admin history, for the registration detail screen.
  ///
  /// Deliberately its own request rather than a filtered read of
  /// [auditLogsProvider] — that provider's query is shared, paged state driven
  /// by the System Logs screen, and watching it here would tie a detail
  /// screen's history strip to whatever page a reviewer happened to leave the
  /// log list on.
  ///
  /// Copied from [userAuditLogs].
  UserAuditLogsProvider call(String userId) {
    return UserAuditLogsProvider(userId);
  }

  @override
  UserAuditLogsProvider getProviderOverride(
    covariant UserAuditLogsProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userAuditLogsProvider';
}

/// One account's admin history, for the registration detail screen.
///
/// Deliberately its own request rather than a filtered read of
/// [auditLogsProvider] — that provider's query is shared, paged state driven
/// by the System Logs screen, and watching it here would tie a detail
/// screen's history strip to whatever page a reviewer happened to leave the
/// log list on.
///
/// Copied from [userAuditLogs].
class UserAuditLogsProvider extends AutoDisposeFutureProvider<AuditLogPage> {
  /// One account's admin history, for the registration detail screen.
  ///
  /// Deliberately its own request rather than a filtered read of
  /// [auditLogsProvider] — that provider's query is shared, paged state driven
  /// by the System Logs screen, and watching it here would tie a detail
  /// screen's history strip to whatever page a reviewer happened to leave the
  /// log list on.
  ///
  /// Copied from [userAuditLogs].
  UserAuditLogsProvider(String userId)
    : this._internal(
        (ref) => userAuditLogs(ref as UserAuditLogsRef, userId),
        from: userAuditLogsProvider,
        name: r'userAuditLogsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$userAuditLogsHash,
        dependencies: UserAuditLogsFamily._dependencies,
        allTransitiveDependencies:
            UserAuditLogsFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserAuditLogsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<AuditLogPage> Function(UserAuditLogsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserAuditLogsProvider._internal(
        (ref) => create(ref as UserAuditLogsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<AuditLogPage> createElement() {
    return _UserAuditLogsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserAuditLogsProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserAuditLogsRef on AutoDisposeFutureProviderRef<AuditLogPage> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserAuditLogsProviderElement
    extends AutoDisposeFutureProviderElement<AuditLogPage>
    with UserAuditLogsRef {
  _UserAuditLogsProviderElement(super.provider);

  @override
  String get userId => (origin as UserAuditLogsProvider).userId;
}

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
