// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parking_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$parkingSlotsHash() => r'800a46eb2ea545f9fa4cdd898886ae4ba4be7d3b';

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
    r'acef345bf8a324856b7d43791269692c51c53366';

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
String _$bayOccupantsHash() => r'655208430009f3dd7cf1a57a7501b8f8f585c3a5';

/// Drivers inside who confirmed their bay in the app, for the names on the
/// map. From the cloud even at the guard post, whose own copy of a session
/// never hears of the confirmation.
///
/// Copied from [bayOccupants].
@ProviderFor(bayOccupants)
final bayOccupantsProvider =
    AutoDisposeFutureProvider<List<ActiveParkingSession>>.internal(
      bayOccupants,
      name: r'bayOccupantsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$bayOccupantsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BayOccupantsRef =
    AutoDisposeFutureProviderRef<List<ActiveParkingSession>>;
String _$wrongBayFlagsHash() => r'b65f9ea7aca177e56a7eb10307bab3480f8c4a01';

/// Bays that may hold the wrong kind of vehicle. Read alongside the bays, on
/// the map's own refresh.
///
/// Copied from [wrongBayFlags].
@ProviderFor(wrongBayFlags)
final wrongBayFlagsProvider =
    AutoDisposeFutureProvider<List<WrongBayFlag>>.internal(
      wrongBayFlags,
      name: r'wrongBayFlagsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$wrongBayFlagsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WrongBayFlagsRef = AutoDisposeFutureProviderRef<List<WrongBayFlag>>;
String _$parkingActionsHash() => r'2112dd19058c6b9bc390ef6b7583803429a0aa75';

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
