// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'violations_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$violationsRepositoryHash() =>
    r'3a2c86393a1bd92840f5b0555e261cb662381a64';

/// See also [violationsRepository].
@ProviderFor(violationsRepository)
final violationsRepositoryProvider =
    AutoDisposeProvider<ViolationsRepository>.internal(
      violationsRepository,
      name: r'violationsRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$violationsRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ViolationsRepositoryRef = AutoDisposeProviderRef<ViolationsRepository>;
String _$violationDetailHash() => r'a807938639f270195ef39851bea9a7f7f9a6c416';

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

/// See also [violationDetail].
@ProviderFor(violationDetail)
const violationDetailProvider = ViolationDetailFamily();

/// See also [violationDetail].
class ViolationDetailFamily extends Family<AsyncValue<ViolationDetail>> {
  /// See also [violationDetail].
  const ViolationDetailFamily();

  /// See also [violationDetail].
  ViolationDetailProvider call(String violationId) {
    return ViolationDetailProvider(violationId);
  }

  @override
  ViolationDetailProvider getProviderOverride(
    covariant ViolationDetailProvider provider,
  ) {
    return call(provider.violationId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'violationDetailProvider';
}

/// See also [violationDetail].
class ViolationDetailProvider
    extends AutoDisposeFutureProvider<ViolationDetail> {
  /// See also [violationDetail].
  ViolationDetailProvider(String violationId)
    : this._internal(
        (ref) => violationDetail(ref as ViolationDetailRef, violationId),
        from: violationDetailProvider,
        name: r'violationDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$violationDetailHash,
        dependencies: ViolationDetailFamily._dependencies,
        allTransitiveDependencies:
            ViolationDetailFamily._allTransitiveDependencies,
        violationId: violationId,
      );

  ViolationDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.violationId,
  }) : super.internal();

  final String violationId;

  @override
  Override overrideWith(
    FutureOr<ViolationDetail> Function(ViolationDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ViolationDetailProvider._internal(
        (ref) => create(ref as ViolationDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        violationId: violationId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ViolationDetail> createElement() {
    return _ViolationDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ViolationDetailProvider && other.violationId == violationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, violationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ViolationDetailRef on AutoDisposeFutureProviderRef<ViolationDetail> {
  /// The parameter `violationId` of this provider.
  String get violationId;
}

class _ViolationDetailProviderElement
    extends AutoDisposeFutureProviderElement<ViolationDetail>
    with ViolationDetailRef {
  _ViolationDetailProviderElement(super.provider);

  @override
  String get violationId => (origin as ViolationDetailProvider).violationId;
}

String _$violationsNotifierHash() =>
    r'4a1a7a66c1b66435b9640c23d033c70d60de00de';

/// See also [ViolationsNotifier].
@ProviderFor(ViolationsNotifier)
final violationsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      ViolationsNotifier,
      ViolationListResult
    >.internal(
      ViolationsNotifier.new,
      name: r'violationsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$violationsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ViolationsNotifier = AutoDisposeAsyncNotifier<ViolationListResult>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
