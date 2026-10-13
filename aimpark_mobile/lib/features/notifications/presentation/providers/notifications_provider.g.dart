// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationsRepositoryHash() =>
    r'6f7b5caf55e7502f5940e6ea72de850efcb84791';

/// See also [notificationsRepository].
@ProviderFor(notificationsRepository)
final notificationsRepositoryProvider =
    AutoDisposeProvider<NotificationsRepository>.internal(
      notificationsRepository,
      name: r'notificationsRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationsRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationsRepositoryRef =
    AutoDisposeProviderRef<NotificationsRepository>;
String _$notificationsNotifierHash() =>
    r'aaea660700c5f61f85aef8af0420836e4e275832';

/// See also [NotificationsNotifier].
@ProviderFor(NotificationsNotifier)
final notificationsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      NotificationsNotifier,
      NotificationListResult
    >.internal(
      NotificationsNotifier.new,
      name: r'notificationsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NotificationsNotifier =
    AutoDisposeAsyncNotifier<NotificationListResult>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
