import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/account_repository.dart';
import '../../data/models/my_profile.dart';

part 'account_provider.g.dart';

@riverpod
AccountRepository accountRepository(Ref ref) {
  return AccountRepository(ref.watch(dioProvider));
}

@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<MyProfile> build() {
    return ref.read(accountRepositoryProvider).getProfile();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(accountRepositoryProvider).getProfile());
  }
}

@riverpod
Future<AccessStatus> accessStatus(Ref ref) {
  return ref.watch(accountRepositoryProvider).getAccessStatus();
}
