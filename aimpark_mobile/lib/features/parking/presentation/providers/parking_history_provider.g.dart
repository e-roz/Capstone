// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parking_history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$parkingRepositoryHash() => r'ebf3c841de26319875d78e1fe12b4baff034ebf7';

/// See also [parkingRepository].
@ProviderFor(parkingRepository)
final parkingRepositoryProvider =
    AutoDisposeProvider<ParkingRepository>.internal(
      parkingRepository,
      name: r'parkingRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$parkingRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ParkingRepositoryRef = AutoDisposeProviderRef<ParkingRepository>;
String _$vehicleLatestSessionHash() =>
    r'338c0be057e27ad2b177c86e040f6bfc43e30218';

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

/// One vehicle's most recent session, for the Home screen's vehicle card.
///
/// Deliberately its own request rather than reading off
/// [parkingHistoryNotifierProvider]'s page of the 20 most recent
/// *account-wide* logs — a second vehicle's last visit can easily be older
/// than that, which would make its "last seen" come back empty even though a
/// session exists.
///
/// Copied from [vehicleLatestSession].
@ProviderFor(vehicleLatestSession)
const vehicleLatestSessionProvider = VehicleLatestSessionFamily();

/// One vehicle's most recent session, for the Home screen's vehicle card.
///
/// Deliberately its own request rather than reading off
/// [parkingHistoryNotifierProvider]'s page of the 20 most recent
/// *account-wide* logs — a second vehicle's last visit can easily be older
/// than that, which would make its "last seen" come back empty even though a
/// session exists.
///
/// Copied from [vehicleLatestSession].
class VehicleLatestSessionFamily
    extends Family<AsyncValue<ParkingHistoryEntry?>> {
  /// One vehicle's most recent session, for the Home screen's vehicle card.
  ///
  /// Deliberately its own request rather than reading off
  /// [parkingHistoryNotifierProvider]'s page of the 20 most recent
  /// *account-wide* logs — a second vehicle's last visit can easily be older
  /// than that, which would make its "last seen" come back empty even though a
  /// session exists.
  ///
  /// Copied from [vehicleLatestSession].
  const VehicleLatestSessionFamily();

  /// One vehicle's most recent session, for the Home screen's vehicle card.
  ///
  /// Deliberately its own request rather than reading off
  /// [parkingHistoryNotifierProvider]'s page of the 20 most recent
  /// *account-wide* logs — a second vehicle's last visit can easily be older
  /// than that, which would make its "last seen" come back empty even though a
  /// session exists.
  ///
  /// Copied from [vehicleLatestSession].
  VehicleLatestSessionProvider call(String vehicleId) {
    return VehicleLatestSessionProvider(vehicleId);
  }

  @override
  VehicleLatestSessionProvider getProviderOverride(
    covariant VehicleLatestSessionProvider provider,
  ) {
    return call(provider.vehicleId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'vehicleLatestSessionProvider';
}

/// One vehicle's most recent session, for the Home screen's vehicle card.
///
/// Deliberately its own request rather than reading off
/// [parkingHistoryNotifierProvider]'s page of the 20 most recent
/// *account-wide* logs — a second vehicle's last visit can easily be older
/// than that, which would make its "last seen" come back empty even though a
/// session exists.
///
/// Copied from [vehicleLatestSession].
class VehicleLatestSessionProvider
    extends AutoDisposeFutureProvider<ParkingHistoryEntry?> {
  /// One vehicle's most recent session, for the Home screen's vehicle card.
  ///
  /// Deliberately its own request rather than reading off
  /// [parkingHistoryNotifierProvider]'s page of the 20 most recent
  /// *account-wide* logs — a second vehicle's last visit can easily be older
  /// than that, which would make its "last seen" come back empty even though a
  /// session exists.
  ///
  /// Copied from [vehicleLatestSession].
  VehicleLatestSessionProvider(String vehicleId)
    : this._internal(
        (ref) =>
            vehicleLatestSession(ref as VehicleLatestSessionRef, vehicleId),
        from: vehicleLatestSessionProvider,
        name: r'vehicleLatestSessionProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$vehicleLatestSessionHash,
        dependencies: VehicleLatestSessionFamily._dependencies,
        allTransitiveDependencies:
            VehicleLatestSessionFamily._allTransitiveDependencies,
        vehicleId: vehicleId,
      );

  VehicleLatestSessionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.vehicleId,
  }) : super.internal();

  final String vehicleId;

  @override
  Override overrideWith(
    FutureOr<ParkingHistoryEntry?> Function(VehicleLatestSessionRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VehicleLatestSessionProvider._internal(
        (ref) => create(ref as VehicleLatestSessionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        vehicleId: vehicleId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ParkingHistoryEntry?> createElement() {
    return _VehicleLatestSessionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleLatestSessionProvider &&
        other.vehicleId == vehicleId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, vehicleId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VehicleLatestSessionRef
    on AutoDisposeFutureProviderRef<ParkingHistoryEntry?> {
  /// The parameter `vehicleId` of this provider.
  String get vehicleId;
}

class _VehicleLatestSessionProviderElement
    extends AutoDisposeFutureProviderElement<ParkingHistoryEntry?>
    with VehicleLatestSessionRef {
  _VehicleLatestSessionProviderElement(super.provider);

  @override
  String get vehicleId => (origin as VehicleLatestSessionProvider).vehicleId;
}

String _$vehicleHistoryHash() => r'fbb3f8fd985b52af53599a491e9438f404a99b38';

/// The parking-history screen, filtered to one vehicle.
///
/// Copied from [vehicleHistory].
@ProviderFor(vehicleHistory)
const vehicleHistoryProvider = VehicleHistoryFamily();

/// The parking-history screen, filtered to one vehicle.
///
/// Copied from [vehicleHistory].
class VehicleHistoryFamily extends Family<AsyncValue<ParkingHistoryResult>> {
  /// The parking-history screen, filtered to one vehicle.
  ///
  /// Copied from [vehicleHistory].
  const VehicleHistoryFamily();

  /// The parking-history screen, filtered to one vehicle.
  ///
  /// Copied from [vehicleHistory].
  VehicleHistoryProvider call(String vehicleId) {
    return VehicleHistoryProvider(vehicleId);
  }

  @override
  VehicleHistoryProvider getProviderOverride(
    covariant VehicleHistoryProvider provider,
  ) {
    return call(provider.vehicleId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'vehicleHistoryProvider';
}

/// The parking-history screen, filtered to one vehicle.
///
/// Copied from [vehicleHistory].
class VehicleHistoryProvider
    extends AutoDisposeFutureProvider<ParkingHistoryResult> {
  /// The parking-history screen, filtered to one vehicle.
  ///
  /// Copied from [vehicleHistory].
  VehicleHistoryProvider(String vehicleId)
    : this._internal(
        (ref) => vehicleHistory(ref as VehicleHistoryRef, vehicleId),
        from: vehicleHistoryProvider,
        name: r'vehicleHistoryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$vehicleHistoryHash,
        dependencies: VehicleHistoryFamily._dependencies,
        allTransitiveDependencies:
            VehicleHistoryFamily._allTransitiveDependencies,
        vehicleId: vehicleId,
      );

  VehicleHistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.vehicleId,
  }) : super.internal();

  final String vehicleId;

  @override
  Override overrideWith(
    FutureOr<ParkingHistoryResult> Function(VehicleHistoryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VehicleHistoryProvider._internal(
        (ref) => create(ref as VehicleHistoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        vehicleId: vehicleId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ParkingHistoryResult> createElement() {
    return _VehicleHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleHistoryProvider && other.vehicleId == vehicleId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, vehicleId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VehicleHistoryRef on AutoDisposeFutureProviderRef<ParkingHistoryResult> {
  /// The parameter `vehicleId` of this provider.
  String get vehicleId;
}

class _VehicleHistoryProviderElement
    extends AutoDisposeFutureProviderElement<ParkingHistoryResult>
    with VehicleHistoryRef {
  _VehicleHistoryProviderElement(super.provider);

  @override
  String get vehicleId => (origin as VehicleHistoryProvider).vehicleId;
}

String _$parkingAvailabilityNotifierHash() =>
    r'f4aee40b9bc0ad1315bad893e60766c1fae968f1';

/// The lot's free count, kept live while anything on screen watches it.
///
/// Re-fetched every [pollEvery] while the app is in the foreground, so a bay
/// filling or emptying shows up without a pull-to-refresh. A poll that fails
/// keeps the last count on screen rather than swapping it for an error — the
/// freshness chip turns amber once that count is old enough to doubt.
///
/// Copied from [ParkingAvailabilityNotifier].
@ProviderFor(ParkingAvailabilityNotifier)
final parkingAvailabilityNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      ParkingAvailabilityNotifier,
      ParkingAvailability
    >.internal(
      ParkingAvailabilityNotifier.new,
      name: r'parkingAvailabilityNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$parkingAvailabilityNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ParkingAvailabilityNotifier =
    AutoDisposeAsyncNotifier<ParkingAvailability>;
String _$parkingHistoryNotifierHash() =>
    r'de1a2a68146a34a444c9ae863dc935443d844d6f';

/// See also [ParkingHistoryNotifier].
@ProviderFor(ParkingHistoryNotifier)
final parkingHistoryNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      ParkingHistoryNotifier,
      ParkingHistoryResult
    >.internal(
      ParkingHistoryNotifier.new,
      name: r'parkingHistoryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$parkingHistoryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ParkingHistoryNotifier =
    AutoDisposeAsyncNotifier<ParkingHistoryResult>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
