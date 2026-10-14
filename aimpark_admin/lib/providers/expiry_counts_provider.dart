import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/admin_user.dart';

// Written by hand rather than generated: two one-line counts, and a generated
// file would mean running the code generator for them.

/// Active users with a licence or a registration that has already run out.
final expiredUsersCountProvider =
    FutureProvider.autoDispose<int>((ref) => _count(ref, 'expired'));

/// Active users with nothing expired yet, but something running out within 60
/// days. Someone with one expired document counts under "expired", not here.
final expiringUsersCountProvider =
    FutureProvider.autoDispose<int>((ref) => _count(ref, 'expiring'));

/// Counted by the Users list's own filter with a page size of one, so the
/// Overview and the list it links to can never disagree about who is in it.
Future<int> _count(Ref ref, String expiry) async {
  final response = await ref.watch(dioProvider).get(
    ApiEndpoints.users,
    queryParameters: {'page': 1, 'pageSize': 1, 'expiry': expiry},
  );
  return UserListPage.fromJson(response.data as Map<String, dynamic>).totalCount;
}
