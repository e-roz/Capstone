import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/payment.dart';

part 'payments_provider.g.dart';

class PaymentsQuery {
  final int page;
  final int pageSize;
  final String? status;

  const PaymentsQuery({this.page = 1, this.pageSize = 20, this.status});

  PaymentsQuery copyWith(
          {int? page, int? pageSize, String? status, bool clearStatus = false}) =>
      PaymentsQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        status: clearStatus ? null : (status ?? this.status),
      );
}

@riverpod
class PaymentsQueryNotifier extends _$PaymentsQueryNotifier {
  @override
  PaymentsQuery build() => const PaymentsQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setStatus(String? status) => state = state.copyWith(
      status: status, clearStatus: status == null, page: 1);
}

@riverpod
Future<PaymentListPage> paymentList(Ref ref) async {
  final query = ref.watch(paymentsQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = <String, dynamic>{
    'page': query.page,
    'pageSize': query.pageSize,
    if (query.status != null) 'status': query.status,
  };

  final response = await dio.get(ApiEndpoints.payments, queryParameters: params);
  return PaymentListPage.fromJson(response.data as Map<String, dynamic>);
}

@riverpod
Future<List<ParkingRate>> parkingRates(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.paymentRates);
  return (response.data as List<dynamic>)
      .map((r) => ParkingRate.fromJson(r as Map<String, dynamic>))
      .toList();
}

@riverpod
class PaymentActions extends _$PaymentActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> upsertRate(String? vehicleType, double ratePerHour) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.put(ApiEndpoints.paymentRates, data: {
        'vehicleType': vehicleType,
        'ratePerHour': ratePerHour,
      });
      state = const AsyncData(null);
      return (res.data as Map<String, dynamic>)['message']?.toString();
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
      return e.message ?? 'Unknown error';
    }
  }
}
