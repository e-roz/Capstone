// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visitor_cards_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$visitorCardsHash() => r'b39ecad4f2750465dd2801bad3e59283865764ee';

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

/// Every visitor card and where it is. Admin reads the cloud's list; Security
/// reads the guard post's, which is the same list plus the passes lent there.
///
/// Copied from [visitorCards].
@ProviderFor(visitorCards)
const visitorCardsProvider = VisitorCardsFamily();

/// Every visitor card and where it is. Admin reads the cloud's list; Security
/// reads the guard post's, which is the same list plus the passes lent there.
///
/// Copied from [visitorCards].
class VisitorCardsFamily extends Family<AsyncValue<List<VisitorCard>>> {
  /// Every visitor card and where it is. Admin reads the cloud's list; Security
  /// reads the guard post's, which is the same list plus the passes lent there.
  ///
  /// Copied from [visitorCards].
  const VisitorCardsFamily();

  /// Every visitor card and where it is. Admin reads the cloud's list; Security
  /// reads the guard post's, which is the same list plus the passes lent there.
  ///
  /// Copied from [visitorCards].
  VisitorCardsProvider call({bool admin = false}) {
    return VisitorCardsProvider(admin: admin);
  }

  @override
  VisitorCardsProvider getProviderOverride(
    covariant VisitorCardsProvider provider,
  ) {
    return call(admin: provider.admin);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'visitorCardsProvider';
}

/// Every visitor card and where it is. Admin reads the cloud's list; Security
/// reads the guard post's, which is the same list plus the passes lent there.
///
/// Copied from [visitorCards].
class VisitorCardsProvider
    extends AutoDisposeFutureProvider<List<VisitorCard>> {
  /// Every visitor card and where it is. Admin reads the cloud's list; Security
  /// reads the guard post's, which is the same list plus the passes lent there.
  ///
  /// Copied from [visitorCards].
  VisitorCardsProvider({bool admin = false})
    : this._internal(
        (ref) => visitorCards(ref as VisitorCardsRef, admin: admin),
        from: visitorCardsProvider,
        name: r'visitorCardsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$visitorCardsHash,
        dependencies: VisitorCardsFamily._dependencies,
        allTransitiveDependencies:
            VisitorCardsFamily._allTransitiveDependencies,
        admin: admin,
      );

  VisitorCardsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.admin,
  }) : super.internal();

  final bool admin;

  @override
  Override overrideWith(
    FutureOr<List<VisitorCard>> Function(VisitorCardsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VisitorCardsProvider._internal(
        (ref) => create(ref as VisitorCardsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        admin: admin,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<VisitorCard>> createElement() {
    return _VisitorCardsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VisitorCardsProvider && other.admin == admin;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, admin.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VisitorCardsRef on AutoDisposeFutureProviderRef<List<VisitorCard>> {
  /// The parameter `admin` of this provider.
  bool get admin;
}

class _VisitorCardsProviderElement
    extends AutoDisposeFutureProviderElement<List<VisitorCard>>
    with VisitorCardsRef {
  _VisitorCardsProviderElement(super.provider);

  @override
  bool get admin => (origin as VisitorCardsProvider).admin;
}

String _$visitorCardActionsHash() =>
    r'42278de3e43afccbfaf03902d1d94a0fcdd3004c';

/// Admin's changes to the drawer: register, block, unblock, remove.
///
/// Copied from [VisitorCardActions].
@ProviderFor(VisitorCardActions)
final visitorCardActionsProvider =
    AutoDisposeNotifierProvider<VisitorCardActions, AsyncValue<void>>.internal(
      VisitorCardActions.new,
      name: r'visitorCardActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$visitorCardActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$VisitorCardActions = AutoDisposeNotifier<AsyncValue<void>>;
String _$visitorRegistrationActionsHash() =>
    r'408dad71bdc51e003274b4ae620236bcd2af204d';

/// The guard's answer to a visitor card tapped at the gate.
///
/// Copied from [VisitorRegistrationActions].
@ProviderFor(VisitorRegistrationActions)
final visitorRegistrationActionsProvider =
    AutoDisposeNotifierProvider<
      VisitorRegistrationActions,
      AsyncValue<void>
    >.internal(
      VisitorRegistrationActions.new,
      name: r'visitorRegistrationActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$visitorRegistrationActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$VisitorRegistrationActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
