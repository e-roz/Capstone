import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/utils/jwt_utils.dart';
import '../router/destinations.dart';

part 'auth_provider.g.dart';

const _storage = FlutterSecureStorage();
const adminTokenKey = 'admin_auth_token';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<String?> build() async {
    return _storage.read(key: adminTokenKey);
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: adminTokenKey, value: token);
    state = AsyncData(token);
  }

  Future<void> logout() async {
    await _storage.delete(key: adminTokenKey);
    state = const AsyncData(null);
  }
}

/// Which kind of staff account is signed in.
///
/// Several screens are shared between the two roles and differ only in which
/// tabs or panels they show. Reading the role from one provider keeps that
/// decision in the same shape everywhere, rather than each screen decoding the
/// token for itself.
///
/// Null while the token is still being read, and for anything that is not a
/// staff account - the router sends both cases to the login screen.
@riverpod
StaffRole? staffRole(Ref ref) {
  final token = ref.watch(authNotifierProvider).valueOrNull;
  return token == null ? null : JwtUtils.staffRole(token);
}
