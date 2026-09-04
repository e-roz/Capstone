import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/payment.dart';

part 'payment_log_provider.g.dart';

/// Kept separate from [PaymentsQuery] (in `payments_provider.dart`) rather
/// than extending it — the live Payments screen and this log are two
/// different views with two different filter sets, and folding a date range
/// into the live table's query would put it in scope there too.
class PaymentLogQuery {
  final int page;
  final int pageSize;
  final String? status;
  final DateTime? from;
  final DateTime? to;

  const PaymentLogQuery({
    this.page = 1,
    this.pageSize = 20,
    this.status,
    this.from,
    this.to,
  });

  PaymentLogQuery copyWith({
    int? page,
    int? pageSize,
    String? status,
    bool clearStatus = false,
    DateTime? from,
    DateTime? to,
    bool clearDateRange = false,
  }) =>
      PaymentLogQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        status: clearStatus ? null : (status ?? this.status),
        from: clearDateRange ? null : (from ?? this.from),
        to: clearDateRange ? null : (to ?? this.to),
      );
}

@riverpod
class PaymentLogQueryNotifier extends _$PaymentLogQueryNotifier {
  @override
  PaymentLogQuery build() => const PaymentLogQuery();

  void setPage(int page) => state = state.copyWith(page: page);

  void setStatus(String? status) =>
      state = state.copyWith(status: status, clearStatus: status == null, page: 1);

  void setDateRange(DateTime? from, DateTime? to) => state = from == null && to == null
      ? state.copyWith(clearDateRange: true, page: 1)
      : state.copyWith(from: from, to: to, page: 1);
}

@riverpod
Future<PaymentListPage> paymentLogList(Ref ref) async {
  final query = ref.watch(paymentLogQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final response = await dio.get(
    ApiEndpoints.payments,
    queryParameters: {
      'page': query.page,
      'pageSize': query.pageSize,
      if (query.status != null) 'status': query.status,
      if (query.from != null) 'from': query.from!.toIso8601String(),
      if (query.to != null) 'to': query.to!.toIso8601String(),
    },
  );
  return PaymentListPage.fromJson(response.data as Map<String, dynamic>);
}

/// A one-shot pull of everything matching the current filters, for the
/// Export button. Not a watched provider — nothing on screen depends on its
/// result outside of the moment the button is pressed.
Future<PaymentExportResult> fetchPaymentExport(
  Dio dio, {
  String? status,
  DateTime? from,
  DateTime? to,
}) async {
  final response = await dio.get(
    ApiEndpoints.paymentsExport,
    queryParameters: {
      'status': ?status,
      'from': ?from?.toIso8601String(),
      'to': ?to?.toIso8601String(),
    },
  );
  return PaymentExportResult.fromJson(response.data as Map<String, dynamic>);
}
