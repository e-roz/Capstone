import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/slot_history.dart';

/// Which bay, and which stretch of time. Leave [from] and [to] null for every
/// session the bay has had. Value equality, so the same question is one
/// request, not one per rebuild.
@immutable
class SlotHistoryQuery {
  const SlotHistoryQuery(this.slotId, {this.from, this.to});

  final String slotId;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) =>
      other is SlotHistoryQuery &&
      other.slotId == slotId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(slotId, from, to);
}

final slotHistoryProvider = FutureProvider.autoDispose
    .family<SlotHistory, SlotHistoryQuery>((ref, query) async {
  final response = await ref.watch(dioProvider).get(
    ApiEndpoints.slotHistory(query.slotId),
    queryParameters: {
      if (query.from != null) 'from': query.from!.toUtc().toIso8601String(),
      if (query.to != null) 'to': query.to!.toUtc().toIso8601String(),
    },
  );
  return SlotHistory.fromJson(response.data as Map<String, dynamic>);
});
