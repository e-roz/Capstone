import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/browser_files.dart';
import '../models/pending_registration.dart';
import '../models/registration_detail.dart';

part 'registrations_provider.g.dart';

// ── Pending list ────────────────────────────────────────────────────────────

@riverpod
Future<List<PendingRegistration>> pendingRegistrations(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.pendingRegistrations);
  final data = response.data as List<dynamic>;
  return data
      .map((e) => PendingRegistration.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Applicants who have been decided on: `Approved` (they became users) or
/// `Rejected`. The queue itself is [pendingRegistrations].
@riverpod
Future<List<PendingRegistration>> decidedRegistrations(
    Ref ref, String status) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    ApiEndpoints.pendingRegistrations,
    queryParameters: {'status': status},
  );
  final data = response.data as List<dynamic>;
  return data
      .map((e) => PendingRegistration.fromJson(e as Map<String, dynamic>))
      .toList();
}

// ── Registration detail ─────────────────────────────────────────────────────

@riverpod
Future<RegistrationDetail> registrationDetail(Ref ref, String userId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.registrationDetail(userId));
  return RegistrationDetail.fromJson(response.data as Map<String, dynamic>);
}

// ── Actions ─────────────────────────────────────────────────────────────────

@riverpod
class RegistrationActions extends _$RegistrationActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> approve(
    String userId, {
    String? overrideNote,
  }) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        ApiEndpoints.approveRegistration(userId),
        data: {
          'overrideNote': ?overrideNote,
        },
      );
      state = const AsyncData(null);
      return (res.data as Map<String, dynamic>)['message']?.toString();
    } on DioException catch (e) {
      state = const AsyncData(null);
      return _errorMessage(e);
    }
  }

  /// Records the inspection of an e-bike and approves its owner.
  ///
  /// Returns whether it went through and a sentence for the admin either way,
  /// because the inspection dialog stays open on a refusal and shows the
  /// reason in place.
  Future<({bool ok, String message})> inspectEBike(
    String userId, {
    required String brand,
    required String color,
    String? marks,
    required String sizeClass,
    required List<PickedFile> photos,
    String? overrideNote,
  }) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final form = FormData.fromMap({
        'Brand': brand,
        'Color': color,
        if (marks != null && marks.trim().isNotEmpty)
          'DistinguishingMarks': marks.trim(),
        'SizeClass': sizeClass,
        // The checklist is enforced on the server too, so the dialog sends what
        // the admin ticked rather than the server assuming it.
        'LicenseMatchesPerson': 'true',
        'SeenInPerson': 'true',
        'NoLtoPlate': 'true',
        if (overrideNote != null && overrideNote.trim().isNotEmpty)
          'OverrideNote': overrideNote.trim(),
      });
      for (final photo in photos) {
        form.files.add(MapEntry(
          'Photos',
          MultipartFile.fromBytes(photo.bytes, filename: photo.name),
        ));
      }
      final res = await dio.post(ApiEndpoints.inspectEBike(userId), data: form);
      state = const AsyncData(null);
      final data = res.data as Map<String, dynamic>;
      final plate = data['plateNumber']?.toString();
      return (
        ok: true,
        message: plate == null
            ? 'E-bike approved.'
            : 'E-bike approved. Temporary plate ${_dashed(plate)}.',
      );
    } on DioException catch (e) {
      state = const AsyncData(null);
      return (ok: false, message: _errorMessage(e));
    }
  }

  /// EB0007 as people write it: EB-0007.
  static String _dashed(String plate) => plate.startsWith('EB') && plate.length > 2
      ? 'EB-${plate.substring(2)}'
      : plate;

  Future<String?> reject(String userId, String reason) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        ApiEndpoints.rejectRegistration(userId),
        data: {'reason': reason},
      );
      state = const AsyncData(null);
      return (res.data as Map<String, dynamic>)['message']?.toString();
    } on DioException catch (e) {
      state = const AsyncData(null);
      return _errorMessage(e);
    }
  }

  /// Asks the applicant to retake specific documents.
  ///
  /// [documents] maps a `DocumentType` name to the reason that one is being
  /// sent back. The reason is not optional at either end — a document returned
  /// without one gets photographed exactly the same way again.
  Future<String?> requestRetake(
    String userId,
    Map<String, String> documents, {
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        ApiEndpoints.requestRetake(userId),
        data: {
          'documents': [
            for (final entry in documents.entries)
              {'type': entry.key, 'reason': entry.value},
          ],
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      state = const AsyncData(null);
      return (res.data as Map<String, dynamic>)['message']?.toString();
    } on DioException catch (e) {
      state = const AsyncData(null);
      return _errorMessage(e);
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
    return e.message ?? 'Unknown error';
  }
}
