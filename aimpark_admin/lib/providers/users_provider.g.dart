// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userListHash() => r'a4c288334ba6eec1bf180d1399b4b90cf856f4d5';

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
String _$rfidCardsHash() => r'd228237a52c916b640aa2eae797473c83c3cec4a';

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

/// See also [rfidCards].
@ProviderFor(rfidCards)
const rfidCardsProvider = RfidCardsFamily();

/// See also [rfidCards].
class RfidCardsFamily extends Family<AsyncValue<List<RfidCard>>> {
  /// See also [rfidCards].
  const RfidCardsFamily();

  /// See also [rfidCards].
  RfidCardsProvider call({String? cardState}) {
    return RfidCardsProvider(cardState: cardState);
  }

  @override
  RfidCardsProvider getProviderOverride(covariant RfidCardsProvider provider) {
    return call(cardState: provider.cardState);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'rfidCardsProvider';
}

/// See also [rfidCards].
class RfidCardsProvider extends AutoDisposeFutureProvider<List<RfidCard>> {
  /// See also [rfidCards].
  RfidCardsProvider({String? cardState})
    : this._internal(
        (ref) => rfidCards(ref as RfidCardsRef, cardState: cardState),
        from: rfidCardsProvider,
        name: r'rfidCardsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$rfidCardsHash,
        dependencies: RfidCardsFamily._dependencies,
        allTransitiveDependencies: RfidCardsFamily._allTransitiveDependencies,
        cardState: cardState,
      );

  RfidCardsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.cardState,
  }) : super.internal();

  final String? cardState;

  @override
  Override overrideWith(
    FutureOr<List<RfidCard>> Function(RfidCardsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RfidCardsProvider._internal(
        (ref) => create(ref as RfidCardsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        cardState: cardState,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<RfidCard>> createElement() {
    return _RfidCardsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RfidCardsProvider && other.cardState == cardState;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, cardState.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RfidCardsRef on AutoDisposeFutureProviderRef<List<RfidCard>> {
  /// The parameter `cardState` of this provider.
  String? get cardState;
}

class _RfidCardsProviderElement
    extends AutoDisposeFutureProviderElement<List<RfidCard>>
    with RfidCardsRef {
  _RfidCardsProviderElement(super.provider);

  @override
  String? get cardState => (origin as RfidCardsProvider).cardState;
}

String _$usersQueryNotifierHash() =>
    r'320fd9f0ae889df6ee5befa31891ed328af57876';

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
