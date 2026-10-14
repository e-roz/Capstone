import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../account/presentation/providers/account_provider.dart';
import '../../../vehicles/presentation/providers/vehicles_provider.dart';
import '../../data/expiry.dart';
import '../../data/renewal.dart';

// Written by hand rather than generated: three small providers, and a generated
// file would mean running the code generator for them.

final renewalsRepositoryProvider = Provider<RenewalsRepository>(
  (ref) => RenewalsRepository(ref.watch(dioProvider)),
);

class RenewalsRepository {
  RenewalsRepository(this._dio);

  final Dio _dio;

  Future<Response<dynamic>> scan(FormData formData) =>
      _dio.post('/api/renewals/scan', data: formData);

  Future<Response<dynamic>> submit(String renewalId, DateTime expiry) =>
      _dio.post(
        '/api/renewals/$renewalId/submit',
        data: {'expiry': expiry.toIso8601String()},
      );

  Future<Response<dynamic>> mine() => _dio.get('/api/renewals/mine');
}

/// Renewals the user has sent that are still waiting, or were turned down.
final myRenewalsProvider = FutureProvider.autoDispose<List<Renewal>>((ref) async {
  final response = await ref.watch(renewalsRepositoryProvider).mine();
  return [
    for (final entry in (response.data as List<dynamic>))
      ?Renewal.fromJson(entry as Map<String, dynamic>),
  ];
});

/// One licence or registration, with how long it has left and whether a
/// renewal is already on its way.
class DocumentItem {
  const DocumentItem({
    required this.target,
    required this.expiry,
    this.renewal,
  });

  final RenewalTarget target;
  final DateTime? expiry;
  final Renewal? renewal;

  ExpiryInfo get info => ExpiryInfo.of(expiry);

  bool get isPending => renewal?.isPending ?? false;
  bool get isRejected => renewal?.isRejected ?? false;

  /// Worth showing on Home: running out or gone, or a renewal that came back.
  bool get needsAttention => isPending || isRejected || info.needsAttention;

  /// An upload is welcome unless one is already waiting.
  bool get canRenew => !isPending;
}

/// The user's licence and each vehicle's registration, in one list.
///
/// E-bikes are left out: they are not registered with the LTO, so there is no
/// registration to run out. Only the licence is tracked for them.
final documentItemsProvider = Provider.autoDispose<List<DocumentItem>>((ref) {
  final profile = ref.watch(profileNotifierProvider).valueOrNull;
  final vehicles = ref.watch(myVehiclesProvider).valueOrNull ?? const [];
  final renewals = ref.watch(myRenewalsProvider).valueOrNull ?? const [];

  // Nothing to say until the account is known; an empty list is shown as
  // nothing rather than as a list of "no date on file".
  if (profile == null) return const [];

  Renewal? renewalFor(RenewalKind kind, String? vehicleId) {
    for (final r in renewals) {
      if (r.kind == kind && r.vehicleId == vehicleId) return r;
    }
    return null;
  }

  return [
    DocumentItem(
      target: const RenewalTarget(kind: RenewalKind.license),
      expiry: profile.licenseValidThrough,
      renewal: renewalFor(RenewalKind.license, null),
    ),
    for (final v in vehicles.where((v) => !v.isEBike))
      DocumentItem(
        target: RenewalTarget(
          kind: RenewalKind.registration,
          vehicleId: v.id,
          plateNumber: v.plateNumber,
        ),
        expiry: v.registrationValidThrough,
        renewal: renewalFor(RenewalKind.registration, v.id),
      ),
  ];
});
