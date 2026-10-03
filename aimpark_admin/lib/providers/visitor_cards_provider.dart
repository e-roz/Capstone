import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/visitor_card.dart';

part 'visitor_cards_provider.g.dart';

/// Every visitor card and where it is. Admin reads the cloud's list; Security
/// reads the guard post's, which is the same list plus the passes lent there.
@riverpod
Future<List<VisitorCard>> visitorCards(Ref ref, {bool admin = false}) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get(
      admin ? ApiEndpoints.visitorCards : ApiEndpoints.securityVisitorCards);
  return [
    for (final c in res.data as List? ?? const [])
      VisitorCard.fromJson(c as Map<String, dynamic>),
  ];
}

/// Admin's changes to the drawer: register, block, unblock, remove.
@riverpod
class VisitorCardActions extends _$VisitorCardActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> add({required String rfidTagId, required String label}) =>
      _run(() => ref.read(dioProvider).post(ApiEndpoints.visitorCards,
          data: {'rfidTagId': rfidTagId, 'label': label}),
          fallback: 'Visitor card $label added.');

  Future<String?> block(String rfidTagId, {String? note}) => _run(
      () => ref.read(dioProvider).post(ApiEndpoints.blockVisitorCard(rfidTagId),
          data: {'note': ?note}));

  Future<String?> unblock(String rfidTagId) => _run(() =>
      ref.read(dioProvider).post(ApiEndpoints.unblockVisitorCard(rfidTagId)));

  Future<String?> remove(String rfidTagId) => _run(
      () => ref.read(dioProvider).delete(ApiEndpoints.visitorCard(rfidTagId)));

  Future<String?> _run(Future<Response<dynamic>> Function() call,
      {String fallback = 'Done.'}) async {
    state = const AsyncLoading();
    try {
      final res = await call();
      state = const AsyncData(null);
      ref.invalidate(visitorCardsProvider);
      final data = res.data;
      return data is Map ? data['message']?.toString() ?? fallback : fallback;
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      if (data is Map) {
        return data['message']?.toString() ?? e.message ?? 'Error';
      }
      return e.message ?? 'Unknown error';
    }
  }
}

/// The guard's answer to a visitor card tapped at the gate.
@riverpod
class VisitorRegistrationActions extends _$VisitorRegistrationActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Lends the card, logs the entry and opens the barrier. Returns the
  /// server's message and whether it worked.
  Future<(bool, String)> complete(
    String id, {
    required String visitorName,
    required String plateNumber,
    required String vehicleType,
    String? purpose,
  }) =>
      _run(() => ref.read(dioProvider).post(
            ApiEndpoints.visitorRegistration(id),
            data: {
              'visitorName': visitorName,
              'plateNumber': plateNumber,
              'vehicleType': vehicleType,
              if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
            },
          ));

  /// The car was turned away. The barrier stays shut.
  Future<(bool, String)> dismiss(String id) => _run(() =>
      ref.read(dioProvider).delete(ApiEndpoints.visitorRegistration(id)));

  Future<(bool, String)> _run(Future<Response<dynamic>> Function() call) async {
    state = const AsyncLoading();
    try {
      final res = await call();
      state = const AsyncData(null);
      final data = res.data;
      return (
        true,
        data is Map ? data['message']?.toString() ?? 'Done.' : 'Done.'
      );
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      return (
        false,
        data is Map
            ? data['message']?.toString() ?? e.message ?? 'Error'
            : e.message ?? 'Unknown error'
      );
    }
  }
}
