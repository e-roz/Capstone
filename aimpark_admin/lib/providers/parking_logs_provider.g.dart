// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parking_logs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$parkingLogsHash() => r'566767471322f2a0d4c4699dcebee75c3a514fea';

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
    r'03fc1f57f6d34b4df3054a0c0d9b1fa600b5eda0';

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
