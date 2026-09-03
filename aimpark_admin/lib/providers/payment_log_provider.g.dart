// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_log_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$paymentLogListHash() => r'ee315f1f53338e26bfca62b8c5b5fd48c4b28c60';

/// See also [paymentLogList].
@ProviderFor(paymentLogList)
final paymentLogListProvider =
    AutoDisposeFutureProvider<PaymentListPage>.internal(
      paymentLogList,
      name: r'paymentLogListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$paymentLogListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PaymentLogListRef = AutoDisposeFutureProviderRef<PaymentListPage>;
String _$paymentLogQueryNotifierHash() =>
    r'b8d169d0ab0f83622c2e9431dc00cd2d90effd06';

/// See also [PaymentLogQueryNotifier].
@ProviderFor(PaymentLogQueryNotifier)
final paymentLogQueryNotifierProvider =
    AutoDisposeNotifierProvider<
      PaymentLogQueryNotifier,
      PaymentLogQuery
    >.internal(
      PaymentLogQueryNotifier.new,
      name: r'paymentLogQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$paymentLogQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PaymentLogQueryNotifier = AutoDisposeNotifier<PaymentLogQuery>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
