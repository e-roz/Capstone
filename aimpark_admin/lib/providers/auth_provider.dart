import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
