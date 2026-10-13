import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/models/payment.dart';
import '../../data/payments_repository.dart';

part 'payments_provider.g.dart';

@riverpod
PaymentsRepository paymentsRepository(Ref ref) {
  return PaymentsRepository(ref.watch(dioProvider));
}

@riverpod
class PaymentsNotifier extends _$PaymentsNotifier {
  @override
  Future<PaymentListResult> build() {
    return ref.read(paymentsRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(paymentsRepositoryProvider).list());
  }

  /// Fetches again without blanking the list first — for coming back from a
  /// payment page, where the person is looking at the screen and a flash of
  /// skeleton rows would read as the app having lost their bills. If the request
  /// fails the list they were already looking at stays.
  Future<void> refreshQuietly() async {
    final fresh = await AsyncValue.guard(
      () => ref.read(paymentsRepositoryProvider).list(),
    );
    if (fresh.hasValue) state = fresh;
  }
}

@riverpod
Future<Payment> paymentDetail(Ref ref, String paymentId) {
  return ref.watch(paymentsRepositoryProvider).getDetail(paymentId);
}
