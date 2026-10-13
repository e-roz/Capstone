// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userListHash() => r'96838f950f07582a928f8a9136bdc57c08972bc0';

/// See also [userList].
@ProviderFor(userList)
final userListProvider = AutoDisposeFutureProvider<UserListPage>.internal(
  userList,
  name: r'userListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserListRef = AutoDisposeFutureProviderRef<UserListPage>;
String _$rfidCardsHash() => r'c120c907171a13d58060d8074e5248230d597999';

/// Every card at once — the screen filters and counts on the client, so the
/// chip counts always add up to what the table can show.
///
/// Copied from [rfidCards].
@ProviderFor(rfidCards)
final rfidCardsProvider = AutoDisposeFutureProvider<List<RfidCard>>.internal(
  rfidCards,
  name: r'rfidCardsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$rfidCardsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RfidCardsRef = AutoDisposeFutureProviderRef<List<RfidCard>>;
String _$rfidCardHistoryHash() => r'cd030c773d887641714f7a019d8796bc83d91bac';

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

/// See also [rfidCardHistory].
@ProviderFor(rfidCardHistory)
const rfidCardHistoryProvider = RfidCardHistoryFamily();

/// See also [rfidCardHistory].
class RfidCardHistoryFamily
    extends Family<AsyncValue<List<RfidCardHistoryEntry>>> {
  /// See also [rfidCardHistory].
  const RfidCardHistoryFamily();

  /// See also [rfidCardHistory].
  RfidCardHistoryProvider call(String rfidTagId) {
    return RfidCardHistoryProvider(rfidTagId);
  }

  @override
  RfidCardHistoryProvider getProviderOverride(
    covariant RfidCardHistoryProvider provider,
  ) {
    return call(provider.rfidTagId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'rfidCardHistoryProvider';
}

/// See also [rfidCardHistory].
class RfidCardHistoryProvider
    extends AutoDisposeFutureProvider<List<RfidCardHistoryEntry>> {
  /// See also [rfidCardHistory].
  RfidCardHistoryProvider(String rfidTagId)
    : this._internal(
        (ref) => rfidCardHistory(ref as RfidCardHistoryRef, rfidTagId),
        from: rfidCardHistoryProvider,
        name: r'rfidCardHistoryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$rfidCardHistoryHash,
        dependencies: RfidCardHistoryFamily._dependencies,
        allTransitiveDependencies:
            RfidCardHistoryFamily._allTransitiveDependencies,
        rfidTagId: rfidTagId,
      );

  RfidCardHistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.rfidTagId,
  }) : super.internal();

  final String rfidTagId;

  @override
  Override overrideWith(
    FutureOr<List<RfidCardHistoryEntry>> Function(RfidCardHistoryRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RfidCardHistoryProvider._internal(
        (ref) => create(ref as RfidCardHistoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        rfidTagId: rfidTagId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<RfidCardHistoryEntry>> createElement() {
    return _RfidCardHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RfidCardHistoryProvider && other.rfidTagId == rfidTagId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, rfidTagId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RfidCardHistoryRef
    on AutoDisposeFutureProviderRef<List<RfidCardHistoryEntry>> {
  /// The parameter `rfidTagId` of this provider.
  String get rfidTagId;
}

class _RfidCardHistoryProviderElement
    extends AutoDisposeFutureProviderElement<List<RfidCardHistoryEntry>>
    with RfidCardHistoryRef {
  _RfidCardHistoryProviderElement(super.provider);

  @override
  String get rfidTagId => (origin as RfidCardHistoryProvider).rfidTagId;
}

String _$usersQueryNotifierHash() =>
    r'2a892c8f99320676eb5c4194e568b3a1be263e66';

/// See also [UsersQueryNotifier].
@ProviderFor(UsersQueryNotifier)
final usersQueryNotifierProvider =
    AutoDisposeNotifierProvider<UsersQueryNotifier, UsersQuery>.internal(
      UsersQueryNotifier.new,
      name: r'usersQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$usersQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UsersQueryNotifier = AutoDisposeNotifier<UsersQuery>;
String _$userActionsHash() => r'd7bde79faa704ebca1e02e1f865f605a23cdb36b';

/// See also [UserActions].
@ProviderFor(UserActions)
final userActionsProvider =
    AutoDisposeNotifierProvider<UserActions, AsyncValue<void>>.internal(
      UserActions.new,
      name: r'userActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$userActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
