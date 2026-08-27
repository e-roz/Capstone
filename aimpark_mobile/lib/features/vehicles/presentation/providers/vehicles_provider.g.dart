// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicles_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$myVehiclesHash() => r'e16878f22cb59f2ef5edb8cd4a184310a48264fd';

/// See also [myVehicles].
@ProviderFor(myVehicles)
final myVehiclesProvider = AutoDisposeFutureProvider<List<Vehicle>>.internal(
  myVehicles,
  name: r'myVehiclesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myVehiclesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyVehiclesRef = AutoDisposeFutureProviderRef<List<Vehicle>>;
String _$vehiclesRepositoryHash() =>
    r'83418f095e780df7f46dc0550e5b9460cb3c14f0';

/// The two calls that add a vehicle: read the documents, then commit what the
/// user agreed to.
///
/// Split for the same reason registration is split — the plate comes off the
/// receipt and is shown back before anything is stored, so the user confirms a
/// reading rather than supplying one.
///
/// Copied from [vehiclesRepository].
@ProviderFor(vehiclesRepository)
final vehiclesRepositoryProvider =
    AutoDisposeProvider<VehiclesRepository>.internal(
      vehiclesRepository,
      name: r'vehiclesRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$vehiclesRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VehiclesRepositoryRef = AutoDisposeProviderRef<VehiclesRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
