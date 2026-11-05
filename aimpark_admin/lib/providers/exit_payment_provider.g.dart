// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exit_payment_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$waitingToLeaveHash() => r'59a3e72eb245d0c096db12a32d6d28d50a528a19';

/// Drivers who tapped out, owe this session's fee, and are held at the barrier
/// until it is settled, oldest first since they have waited longest. Followed in
/// the same list by drivers still inside whose bill is paid, so the guard can see
/// that a payment arrived (the card tells the two apart by `waitingToLeave`).
///
/// Copied from [waitingToLeave].
@ProviderFor(waitingToLeave)
final waitingToLeaveProvider =
    AutoDisposeFutureProvider<List<ActiveParkingSession>>.internal(
      waitingToLeave,
      name: r'waitingToLeaveProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$waitingToLeaveHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WaitingToLeaveRef =
    AutoDisposeFutureProviderRef<List<ActiveParkingSession>>;
String _$cashSummaryHash() => r'50ec458400eaa9765447b330508edcb30f018286';

/// See also [cashSummary].
@ProviderFor(cashSummary)
final cashSummaryProvider = AutoDisposeFutureProvider<CashSummary>.internal(
  cashSummary,
  name: r'cashSummaryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cashSummaryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CashSummaryRef = AutoDisposeFutureProviderRef<CashSummary>;
String _$exitPaymentActionsHash() =>
    r'aa87cc0fa302d7b486dc257d74ceca2115e5a4a3';

/// See also [ExitPaymentActions].
@ProviderFor(ExitPaymentActions)
final exitPaymentActionsProvider =
    AutoDisposeNotifierProvider<ExitPaymentActions, AsyncValue<void>>.internal(
      ExitPaymentActions.new,
      name: r'exitPaymentActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$exitPaymentActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ExitPaymentActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
