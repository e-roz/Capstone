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

  Future<void> pay(String paymentId) {
    return _dio.post(ApiEndpoints.paymentPay(paymentId));
  }
}
