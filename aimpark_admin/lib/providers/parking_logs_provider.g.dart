// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parking_logs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$parkingLogsHash() => r'79ea81600a36c169b4f7f611dd86a51d94ac28a8';

/// See also [parkingLogs].
@ProviderFor(parkingLogs)
final parkingLogsProvider = AutoDisposeFutureProvider<ParkingLogPage>.internal(
  parkingLogs,
  name: r'parkingLogsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$parkingLogsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ParkingLogsRef = AutoDisposeFutureProviderRef<ParkingLogPage>;
String _$parkingLogsQueryNotifierHash() =>
    r'9b022a7cef83c2cc2fb002a62cba9d5c3f80202e';

/// See also [ParkingLogsQueryNotifier].
@ProviderFor(ParkingLogsQueryNotifier)
final parkingLogsQueryNotifierProvider =
    AutoDisposeNotifierProvider<
      ParkingLogsQueryNotifier,
      ParkingLogsQuery
    >.internal(
      ParkingLogsQueryNotifier.new,
      name: r'parkingLogsQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$parkingLogsQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ParkingLogsQueryNotifier = AutoDisposeNotifier<ParkingLogsQuery>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
