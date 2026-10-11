import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'models/payment.dart';

class PaymentsRepository {
  PaymentsRepository(this._dio);

  final Dio _dio;

  Future<PaymentListResult> list({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get(
      ApiEndpoints.payments,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PaymentListResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Payment> getDetail(String paymentId) async {
    final response = await _dio.get(ApiEndpoints.paymentDetail(paymentId));
    return Payment.fromJson(response.data as Map<String, dynamic>);
  }

  /// Opens a checkout and returns where to send the payer.
  ///
  /// This replaced a `pay` call that told the server the bill was settled. The
  /// phone is not in a position to know that: it can say the payer was sent to
  /// GCash, and nothing more. Whether money arrived comes back to the server
  /// from the provider, on its own connection.
  Future<Checkout> startCheckout(String paymentId) async {
    final response = await _dio.post(ApiEndpoints.paymentCheckout(paymentId));
    return Checkout.fromJson(response.data as Map<String, dynamic>);
  }

  /// Opens ONE checkout covering every bill the caller can pay right now, and
  /// returns where to send the payer. The server decides which bills those are
  /// and what they total — the phone never sends a list or an amount.
  ///
  /// Only called when `kPayAllAvailable` is true. The server endpoint is a
  /// separate piece of work, and its contract is written down in
  /// `payments_capabilities.dart`.
  Future<Checkout> startCheckoutAll() async {
    final response = await _dio.post(ApiEndpoints.paymentsCheckoutAll);
    return Checkout.fromJson(response.data as Map<String, dynamic>);
  }
}
