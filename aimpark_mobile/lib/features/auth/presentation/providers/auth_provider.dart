import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/auth_repository.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    const FlutterSecureStorage(),
  );
}
