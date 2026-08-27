// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registrations_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pendingRegistrationsHash() =>
    r'45ca881c576e83d890fb6af854379a0dcba0a903';

/// See also [pendingRegistrations].
@ProviderFor(pendingRegistrations)
final pendingRegistrationsProvider =
    AutoDisposeFutureProvider<List<PendingRegistration>>.internal(
      pendingRegistrations,
      name: r'pendingRegistrationsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pendingRegistrationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingRegistrationsRef =
    AutoDisposeFutureProviderRef<List<PendingRegistration>>;
String _$registrationDetailHash() =>
    r'ca146bd91a5aef1feaae20b275bce438bca67984';

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

/// See also [registrationDetail].
@ProviderFor(registrationDetail)
const registrationDetailProvider = RegistrationDetailFamily();

/// See also [registrationDetail].
class RegistrationDetailFamily extends Family<AsyncValue<RegistrationDetail>> {
  /// See also [registrationDetail].
  const RegistrationDetailFamily();

  /// See also [registrationDetail].
  RegistrationDetailProvider call(String userId) {
    return RegistrationDetailProvider(userId);
  }

  @override
  RegistrationDetailProvider getProviderOverride(
    covariant RegistrationDetailProvider provider,
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
  String? get name => r'registrationDetailProvider';
}

/// See also [registrationDetail].
class RegistrationDetailProvider
    extends AutoDisposeFutureProvider<RegistrationDetail> {
  /// See also [registrationDetail].
  RegistrationDetailProvider(String userId)
    : this._internal(
        (ref) => registrationDetail(ref as RegistrationDetailRef, userId),
        from: registrationDetailProvider,
        name: r'registrationDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$registrationDetailHash,
        dependencies: RegistrationDetailFamily._dependencies,
        allTransitiveDependencies:
            RegistrationDetailFamily._allTransitiveDependencies,
        userId: userId,
      );

  RegistrationDetailProvider._internal(
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
    FutureOr<RegistrationDetail> Function(RegistrationDetailRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RegistrationDetailProvider._internal(
        (ref) => create(ref as RegistrationDetailRef),
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
  AutoDisposeFutureProviderElement<RegistrationDetail> createElement() {
    return _RegistrationDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RegistrationDetailProvider && other.userId == userId;
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
mixin RegistrationDetailRef
    on AutoDisposeFutureProviderRef<RegistrationDetail> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _RegistrationDetailProviderElement
    extends AutoDisposeFutureProviderElement<RegistrationDetail>
    with RegistrationDetailRef {
  _RegistrationDetailProviderElement(super.provider);

  @override
  String get userId => (origin as RegistrationDetailProvider).userId;
}

String _$registrationActionsHash() =>
    r'ae2bcaae12447c0f980807ae2be917f9c11cb7d7';

/// See also [RegistrationActions].
@ProviderFor(RegistrationActions)
final registrationActionsProvider =
    AutoDisposeNotifierProvider<RegistrationActions, AsyncValue<void>>.internal(
      RegistrationActions.new,
      name: r'registrationActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$registrationActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RegistrationActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
