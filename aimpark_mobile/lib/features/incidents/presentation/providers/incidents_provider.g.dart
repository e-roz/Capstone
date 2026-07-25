// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incidents_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$incidentsRepositoryHash() =>
    r'6478e40f7ced4a023aa9c006c1bb2d87f8095bbf';

/// See also [incidentsRepository].
@ProviderFor(incidentsRepository)
final incidentsRepositoryProvider =
    AutoDisposeProvider<IncidentsRepository>.internal(
      incidentsRepository,
      name: r'incidentsRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$incidentsRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IncidentsRepositoryRef = AutoDisposeProviderRef<IncidentsRepository>;
String _$incidentDetailHash() => r'0e1726744783509ae14a7fc206a52a78570274a4';

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

/// See also [incidentDetail].
@ProviderFor(incidentDetail)
const incidentDetailProvider = IncidentDetailFamily();

/// See also [incidentDetail].
class IncidentDetailFamily extends Family<AsyncValue<IncidentDetail>> {
  /// See also [incidentDetail].
  const IncidentDetailFamily();

  /// See also [incidentDetail].
  IncidentDetailProvider call(String incidentId) {
    return IncidentDetailProvider(incidentId);
  }

  @override
  IncidentDetailProvider getProviderOverride(
    covariant IncidentDetailProvider provider,
  ) {
    return call(provider.incidentId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'incidentDetailProvider';
}

/// See also [incidentDetail].
class IncidentDetailProvider extends AutoDisposeFutureProvider<IncidentDetail> {
  /// See also [incidentDetail].
  IncidentDetailProvider(String incidentId)
    : this._internal(
        (ref) => incidentDetail(ref as IncidentDetailRef, incidentId),
        from: incidentDetailProvider,
        name: r'incidentDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$incidentDetailHash,
        dependencies: IncidentDetailFamily._dependencies,
        allTransitiveDependencies:
            IncidentDetailFamily._allTransitiveDependencies,
        incidentId: incidentId,
      );

  IncidentDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.incidentId,
  }) : super.internal();

  final String incidentId;

  @override
  Override overrideWith(
    FutureOr<IncidentDetail> Function(IncidentDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IncidentDetailProvider._internal(
        (ref) => create(ref as IncidentDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        incidentId: incidentId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<IncidentDetail> createElement() {
    return _IncidentDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IncidentDetailProvider && other.incidentId == incidentId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, incidentId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IncidentDetailRef on AutoDisposeFutureProviderRef<IncidentDetail> {
  /// The parameter `incidentId` of this provider.
  String get incidentId;
}

class _IncidentDetailProviderElement
    extends AutoDisposeFutureProviderElement<IncidentDetail>
    with IncidentDetailRef {
  _IncidentDetailProviderElement(super.provider);

  @override
  String get incidentId => (origin as IncidentDetailProvider).incidentId;
}

String _$incidentsNotifierHash() => r'6f6712d883cb82f5ae4f1eb13b6ac2ecba97eba7';

/// See also [IncidentsNotifier].
@ProviderFor(IncidentsNotifier)
final incidentsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      IncidentsNotifier,
      IncidentListResult
    >.internal(
      IncidentsNotifier.new,
      name: r'incidentsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$incidentsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$IncidentsNotifier = AutoDisposeAsyncNotifier<IncidentListResult>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
