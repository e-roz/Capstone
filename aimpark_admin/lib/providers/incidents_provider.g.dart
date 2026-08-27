// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incidents_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$incidentListHash() => r'66a62acd8ef7326129bc1e1ea42bb4706c3d3c8e';

/// See also [incidentList].
@ProviderFor(incidentList)
final incidentListProvider =
    AutoDisposeFutureProvider<IncidentListPage>.internal(
      incidentList,
      name: r'incidentListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$incidentListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IncidentListRef = AutoDisposeFutureProviderRef<IncidentListPage>;
String _$openIncidentCountHash() => r'14283fa6f342521698379da3335d9874a0b50230';

/// How many reports nobody has picked up yet.
///
/// Its own request rather than a count off [incidentList], because that list is
/// filtered and paged by whatever the admin last chose — a page showing only
/// resolved reports would report zero waiting, which is the opposite of the
/// truth. `pageSize: 1` because only `totalCount` is read.
///
/// Copied from [openIncidentCount].
@ProviderFor(openIncidentCount)
final openIncidentCountProvider = AutoDisposeFutureProvider<int>.internal(
  openIncidentCount,
  name: r'openIncidentCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$openIncidentCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OpenIncidentCountRef = AutoDisposeFutureProviderRef<int>;
String _$incidentDetailHash() => r'210831150617f514a8aab01fc41fbcfc2026e44e';

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

String _$incidentsQueryNotifierHash() =>
    r'485cb8a72a251a62df1db983deccce565639fdb3';

/// See also [IncidentsQueryNotifier].
@ProviderFor(IncidentsQueryNotifier)
final incidentsQueryNotifierProvider =
    AutoDisposeNotifierProvider<
      IncidentsQueryNotifier,
      IncidentsQuery
    >.internal(
      IncidentsQueryNotifier.new,
      name: r'incidentsQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$incidentsQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$IncidentsQueryNotifier = AutoDisposeNotifier<IncidentsQuery>;
String _$incidentActionsHash() => r'1d145cca6f49426ce19a5023ef4f002c93a253e3';

/// See also [IncidentActions].
@ProviderFor(IncidentActions)
final incidentActionsProvider =
    AutoDisposeNotifierProvider<IncidentActions, AsyncValue<void>>.internal(
      IncidentActions.new,
      name: r'incidentActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$incidentActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$IncidentActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
