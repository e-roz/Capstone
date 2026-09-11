// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gate_device_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gateDeviceListHash() => r'39c66f679e9fc814af4aea9f414d3a766c473ec2';

/// Every reader and camera ever registered, revoked ones included — a
/// revoked row stays as the record of what used to talk to this gate.
///
/// Copied from [gateDeviceList].
@ProviderFor(gateDeviceList)
final gateDeviceListProvider =
    AutoDisposeFutureProvider<List<GateDevice>>.internal(
      gateDeviceList,
      name: r'gateDeviceListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$gateDeviceListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GateDeviceListRef = AutoDisposeFutureProviderRef<List<GateDevice>>;
String _$gateDeviceActionsHash() => r'b97832884c6e0c8483fc009415bc70ccfd516dac';

/// See also [GateDeviceActions].
@ProviderFor(GateDeviceActions)
final gateDeviceActionsProvider =
    AutoDisposeNotifierProvider<GateDeviceActions, AsyncValue<void>>.internal(
      GateDeviceActions.new,
      name: r'gateDeviceActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$gateDeviceActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GateDeviceActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
