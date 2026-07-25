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
}

@riverpod
Future<Payment> paymentDetail(Ref ref, String paymentId) {
  return ref.watch(paymentsRepositoryProvider).getDetail(paymentId);
}
