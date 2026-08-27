// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parking_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$parkingSlotsHash() => r'4b1d6dfcb4e25c84d55dfa33bbcc5d20be591616';

/// See also [parkingSlots].
@ProviderFor(parkingSlots)
final parkingSlotsProvider =
    AutoDisposeFutureProvider<ParkingAvailability>.internal(
      parkingSlots,
      name: r'parkingSlotsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$parkingSlotsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ParkingSlotsRef = AutoDisposeFutureProviderRef<ParkingAvailability>;
String _$activeParkingSessionsHash() =>
    r'c145dd9a59be5b319d518639a52a8e3d3c984808';

/// See also [activeParkingSessions].
@ProviderFor(activeParkingSessions)
final activeParkingSessionsProvider =
    AutoDisposeFutureProvider<List<ActiveParkingSession>>.internal(
      activeParkingSessions,
      name: r'activeParkingSessionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$activeParkingSessionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveParkingSessionsRef =
    AutoDisposeFutureProviderRef<List<ActiveParkingSession>>;
String _$parkingActionsHash() => r'91a193033b4185a789154978e45c3e29d4b0c520';

/// See also [ParkingActions].
@ProviderFor(ParkingActions)
final parkingActionsProvider =
    AutoDisposeNotifierProvider<ParkingActions, AsyncValue<void>>.internal(
      ParkingActions.new,
      name: r'parkingActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$parkingActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ParkingActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
