import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/models/violation.dart';
import '../../data/violations_repository.dart';

part 'violations_provider.g.dart';

@riverpod
ViolationsRepository violationsRepository(Ref ref) {
  return ViolationsRepository(ref.watch(dioProvider));
}

@riverpod
class ViolationsNotifier extends _$ViolationsNotifier {
  @override
  Future<ViolationListResult> build() {
    return ref.read(violationsRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(violationsRepositoryProvider).list());
  }
}

@riverpod
Future<ViolationDetail> violationDetail(Ref ref, String violationId) {
  return ref.watch(violationsRepositoryProvider).getDetail(violationId);
}
