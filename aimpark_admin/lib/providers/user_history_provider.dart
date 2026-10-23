import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/user_history.dart';

/// One page of one list for one user. Value equality, so the same question is
/// one request, not one per rebuild. [from] limits sessions to those that
/// overlapped the window; the other lists ignore it.
@immutable
class UserListQuery {
  const UserListQuery(this.userId, {this.page = 1, this.from});

  final String userId;
  final int page;
  final DateTime? from;

  @override
  bool operator ==(Object other) =>
      other is UserListQuery &&
      other.userId == userId &&
      other.page == page &&
      other.from == from;

  @override
  int get hashCode => Object.hash(userId, page, from);
}

const userHistoryPageSize = 15;

String _base(String userId) => '${ApiEndpoints.users}/$userId/history';

final userHistorySummaryProvider = FutureProvider.autoDispose
    .family<UserHistorySummary, String>((ref, userId) async {
  final res = await ref.watch(dioProvider).get('${_base(userId)}/summary');
  return UserHistorySummary.fromJson(res.data as Map<String, dynamic>);
});

final userSessionsProvider = FutureProvider.autoDispose
    .family<HistoryPage<UserSessionItem>, UserListQuery>((ref, q) async {
  final res = await ref.watch(dioProvider).get(
    '${_base(q.userId)}/sessions',
    queryParameters: {
      'page': q.page,
      'pageSize': userHistoryPageSize,
      if (q.from != null) 'from': q.from!.toUtc().toIso8601String(),
    },
  );
  return HistoryPage.fromJson(
      res.data as Map<String, dynamic>, UserSessionItem.fromJson);
});

final userViolationsProvider = FutureProvider.autoDispose
    .family<HistoryPage<UserViolationItem>, UserListQuery>((ref, q) async {
  final res = await ref.watch(dioProvider).get(
    '${_base(q.userId)}/violations',
    queryParameters: {'page': q.page, 'pageSize': userHistoryPageSize},
  );
  return HistoryPage.fromJson(
      res.data as Map<String, dynamic>, UserViolationItem.fromJson);
});

final userIncidentsProvider =
    FutureProvider.autoDispose.family<UserIncidents, String>((ref, userId) async {
  final res = await ref.watch(dioProvider).get('${_base(userId)}/incidents');
  return UserIncidents.fromJson(res.data as Map<String, dynamic>);
});

final userPaymentsProvider = FutureProvider.autoDispose
    .family<HistoryPage<UserPaymentItem>, UserListQuery>((ref, q) async {
  final res = await ref.watch(dioProvider).get(
    '${_base(q.userId)}/payments',
    queryParameters: {'page': q.page, 'pageSize': userHistoryPageSize},
  );
  return HistoryPage.fromJson(
      res.data as Map<String, dynamic>, UserPaymentItem.fromJson);
});
