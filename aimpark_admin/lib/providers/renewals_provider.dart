import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/admin_renewal.dart';
import 'queue_counts_provider.dart';

/// Renewals waiting on a decision, oldest first.
///
/// Written by hand rather than generated: it is a plain list with no
/// parameters, and a generated file here would mean running the code generator
/// for one line.
final pendingRenewalsProvider =
    FutureProvider.autoDispose<List<AdminRenewal>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    ApiEndpoints.adminRenewals,
    queryParameters: {'status': 'Pending'},
  );
  return (response.data as List<dynamic>)
      .map((e) => AdminRenewal.fromJson(e as Map<String, dynamic>))
      .toList();
});

final renewalActionsProvider = Provider<RenewalActions>(RenewalActions.new);

class RenewalActions {
  RenewalActions(this._ref);

  final Ref _ref;

  /// Both return what to tell the admin, whichever way it went.
  Future<String> approve(String id) async {
    try {
      final res = await _ref.read(dioProvider).post(ApiEndpoints.approveRenewal(id));
      _refresh();
      return (res.data as Map<String, dynamic>)['message']?.toString() ??
          'Renewal approved.';
    } on DioException catch (e) {
      return _message(e);
    }
  }

  Future<String> reject(String id, String reason) async {
    try {
      final res = await _ref.read(dioProvider).post(
        ApiEndpoints.rejectRenewal(id),
        data: {'reason': reason},
      );
      _refresh();
      return (res.data as Map<String, dynamic>)['message']?.toString() ??
          'Renewal rejected.';
    } on DioException catch (e) {
      return _message(e);
    }
  }

  void _refresh() {
    _ref.invalidate(pendingRenewalsProvider);
    _ref.invalidate(pendingQueueCountProvider);
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
    return e.message ?? 'Unknown error';
  }
}
