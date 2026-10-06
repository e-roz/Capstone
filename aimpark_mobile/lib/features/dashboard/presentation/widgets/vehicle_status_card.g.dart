// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_status_card.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$selectedVehicleIdHash() => r'c845ffb1572cef1494432978a82fbda0a5d07e5b';

/// Which vehicle the card shows. There's no "primary vehicle" concept on the
/// account (see vehicle_status.dart), so this is a local, session-scoped
/// convenience — it resets on logout along with everything else Home reads,
/// and [VehicleStatusResolver.pickVehicle] already supplies a sensible
/// default (whichever car was driven most recently) when nothing's selected.
///
/// Copied from [SelectedVehicleId].
@ProviderFor(SelectedVehicleId)
final selectedVehicleIdProvider =
    AutoDisposeNotifierProvider<SelectedVehicleId, String?>.internal(
      SelectedVehicleId.new,
      name: r'selectedVehicleIdProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedVehicleIdHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedVehicleId = AutoDisposeNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
