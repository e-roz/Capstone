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
