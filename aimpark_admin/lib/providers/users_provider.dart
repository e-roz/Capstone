import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/admin_user.dart';

part 'users_provider.g.dart';

// ── Query params state ───────────────────────────────────────────────────────

class UsersQuery {
  final int page;
  final int pageSize;
  final String? status; // null = all

  const UsersQuery({
    this.page = 1,
    this.pageSize = 20,
    this.status,
  });

  UsersQuery copyWith({int? page, int? pageSize, String? status, bool clearStatus = false}) =>
      UsersQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        status: clearStatus ? null : (status ?? this.status),
      );
}

@riverpod
class UsersQueryNotifier extends _$UsersQueryNotifier {
  @override
  UsersQuery build() => const UsersQuery();

  void setPage(int page) => state = state.copyWith(page: page);
  void setStatus(String? status) =>
      state = state.copyWith(status: status, clearStatus: status == null, page: 1);
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
  };

  final response = await dio.get(ApiEndpoints.users, queryParameters: params);
  return UserListPage.fromJson(response.data as Map<String, dynamic>);
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

  Future<String?> delete(String userId) async {
    return _run(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.delete(ApiEndpoints.deleteUser(userId));
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
