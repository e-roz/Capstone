import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';

/// Registrations and renewals waiting on an administrator, for the sidebar.
///
/// Its own request rather than the length of the two lists: the Registrations
/// page shows those lists, and refreshing them under it every half minute would
/// blank the table. Written by hand for the same reason as the renewals
/// provider — one parameterless value is not worth running the generator.
final pendingQueueCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  final dio = ref.watch(dioProvider);
  final results = await Future.wait([
    dio.get(ApiEndpoints.pendingRegistrations),
    dio.get(ApiEndpoints.adminRenewals, queryParameters: {'status': 'Pending'}),
  ]);
  return results.fold<int>(0, (sum, r) => sum + ((r.data as List).length));
});
