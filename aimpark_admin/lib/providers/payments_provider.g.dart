// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payments_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$paymentListHash() => r'f6f66b3366d4538f96addbc9c9e2bfa8f42e755d';

/// See also [paymentList].
@ProviderFor(paymentList)
final paymentListProvider = AutoDisposeFutureProvider<PaymentListPage>.internal(
  paymentList,
  name: r'paymentListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$paymentListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PaymentListRef = AutoDisposeFutureProviderRef<PaymentListPage>;
String _$parkingRatesHash() => r'c7197a5185752fe4e2d19f0d120c5aacb1d51588';

/// See also [parkingRates].
@ProviderFor(parkingRates)
final parkingRatesProvider =
    AutoDisposeFutureProvider<List<ParkingRate>>.internal(
      parkingRates,
      name: r'parkingRatesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$parkingRatesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ParkingRatesRef = AutoDisposeFutureProviderRef<List<ParkingRate>>;
String _$paymentsQueryNotifierHash() =>
    r'f2d10fe0eeb2dd200eec8aac0c3b6d125c238c56';

/// See also [PaymentsQueryNotifier].
@ProviderFor(PaymentsQueryNotifier)
final paymentsQueryNotifierProvider =
    AutoDisposeNotifierProvider<PaymentsQueryNotifier, PaymentsQuery>.internal(
      PaymentsQueryNotifier.new,
      name: r'paymentsQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$paymentsQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PaymentsQueryNotifier = AutoDisposeNotifier<PaymentsQuery>;
String _$paymentActionsHash() => r'9d35647aa548d88c48fdbe13777d940d0e6b5294';

/// See also [PaymentActions].
@ProviderFor(PaymentActions)
final paymentActionsProvider =
    AutoDisposeNotifierProvider<PaymentActions, AsyncValue<void>>.internal(
      PaymentActions.new,
      name: r'paymentActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$paymentActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PaymentActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
