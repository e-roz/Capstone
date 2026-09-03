import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/admin_user.dart';
import '../models/rfid_card.dart';

part 'users_provider.g.dart';

// ── Query params state ───────────────────────────────────────────────────────

class UsersQuery {
  final int page;
  final int pageSize;
  final String? status; // null = all
  final String? search; // null/empty = no search filter

  const UsersQuery({
    this.page = 1,
    this.pageSize = 20,
    this.status,
    this.search,
  });

  UsersQuery copyWith(
          {int? page,
          int? pageSize,
          String? status,
          bool clearStatus = false,
          String? search,
          bool clearSearch = false}) =>
      UsersQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        status: clearStatus ? null : (status ?? this.status),
        search: clearSearch ? null : (search ?? this.search),
      );
}

@riverpod
class UsersQueryNotifier extends _$UsersQueryNotifier {
  @override
  UsersQuery build() => const UsersQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setStatus(String? status) =>
      state = state.copyWith(status: status, clearStatus: status == null, page: 1);
  void setSearch(String? search) => state = state.copyWith(
      search: search,
      clearSearch: search == null || search.isEmpty,
      page: 1);
}

// ── Users list ───────────────────────────────────────────────────────────────

@riverpod
Future<UserListPage> userList(Ref ref) async {
  final query = ref.watch(usersQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = <String, dynamic>{
    'page': query.page,
    'pageSize': query.pageSize,
    if (query.status != null) 'status': query.status,
    if (query.search != null && query.search!.isNotEmpty) 'search': query.search,
  };

  final response = await dio.get(ApiEndpoints.users, queryParameters: params);
  return UserListPage.fromJson(response.data as Map<String, dynamic>);
}

class BulkRevokeResult {
  final int revoked;
  final int skippedCount;
  final String? error;

  const BulkRevokeResult(
      {required this.revoked, required this.skippedCount, this.error});
}

// ── RFID card pool (Free / Blocked) ────────────────────────────────────────

@riverpod
Future<List<RfidCard>> rfidCards(Ref ref, {String? cardState}) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get(ApiEndpoints.rfidCards,
      queryParameters: {'state': ?cardState});
  return (res.data as List<dynamic>)
      .map((c) => RfidCard.fromJson(c as Map<String, dynamic>))
      .toList();
}

// ── User actions ─────────────────────────────────────────────────────────────

@riverpod
class UserActions extends _$UserActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> suspend(String userId, {String? reason}) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.suspendUser(userId),
          data: {'reason': reason});
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  Future<String?> unsuspend(String userId) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.unsuspendUser(userId));
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  Future<String?> archive(String userId, String adminPassword) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.delete(ApiEndpoints.archiveUser(userId),
          data: {'password': adminPassword});
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  /// Deletes the user's uploaded ID images. The account itself stays.
  Future<String?> deleteDocuments(
    String userId,
    String adminPassword, {
    String? reason,
  }) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.delete(
        ApiEndpoints.deleteUserDocuments(userId),
        data: {'password': adminPassword, 'reason': reason},
      );
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  Future<String?> restore(String userId) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.restoreUser(userId));
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  Future<String?> assignRfid(String userId, String rfidTagId) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.assignRfid(userId),
          data: {'rfidTagId': rfidTagId});
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  Future<String?> revokeRfid(String userId, String reason, String? note) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.revokeRfid(userId),
          data: {'reason': reason, 'note': note});
      return (res.data as Map<String, dynamic>)['message']?.toString();
    });
  }

  /// Returns how many were revoked and the reasons any were skipped (e.g.
  /// already had no card) — a partial success, not something to throw on.
  Future<BulkRevokeResult> bulkRevokeRfid(
      List<String> userIds, String reason, String? note) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.bulkRevokeRfid, data: {
        'userIds': userIds,
        'reason': reason,
        'note': note,
      });
      state = const AsyncData(null);
      final data = res.data as Map<String, dynamic>;
      return BulkRevokeResult(
        revoked: (data['revoked'] as num?)?.toInt() ?? 0,
        skippedCount: (data['skipped'] as List<dynamic>? ?? []).length,
      );
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      final message = data is Map
          ? data['message']?.toString() ?? e.message ?? 'Error'
          : e.message ?? 'Unknown error';
      return BulkRevokeResult(revoked: 0, skippedCount: 0, error: message);
    }
  }

  Future<String?> _run(Future<String?> Function() fn) async {
    state = const AsyncLoading();
    try {
      final msg = await fn();
      state = const AsyncData(null);
      return msg;
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
      return e.message ?? 'Unknown error';
    }
  }
}
