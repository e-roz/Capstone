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
String _$parkingAvailabilityHash() =>
    r'aa029b172b667d0064c4fc1f256f827d352a7625';

/// See also [parkingAvailability].
@ProviderFor(parkingAvailability)
final parkingAvailabilityProvider =
    AutoDisposeFutureProvider<ParkingAvailability>.internal(
      parkingAvailability,
      name: r'parkingAvailabilityProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$parkingAvailabilityHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ParkingAvailabilityRef =
    AutoDisposeFutureProviderRef<ParkingAvailability>;
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
