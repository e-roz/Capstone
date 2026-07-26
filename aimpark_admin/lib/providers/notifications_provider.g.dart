// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationListHash() => r'bc072dee5520eed5e3f50d8a6396c15c0450f590';

/// See also [notificationList].
@ProviderFor(notificationList)
final notificationListProvider =
    AutoDisposeFutureProvider<NotificationListPage>.internal(
      notificationList,
      name: r'notificationListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationListRef =
    AutoDisposeFutureProviderRef<NotificationListPage>;
String _$notificationsQueryNotifierHash() =>
    r'ddc871f79820fc3f791f7b31671a1c8a02555628';

/// See also [NotificationsQueryNotifier].
@ProviderFor(NotificationsQueryNotifier)
final notificationsQueryNotifierProvider =
    AutoDisposeNotifierProvider<
      NotificationsQueryNotifier,
      NotificationsQuery
    >.internal(
      NotificationsQueryNotifier.new,
      name: r'notificationsQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationsQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NotificationsQueryNotifier = AutoDisposeNotifier<NotificationsQuery>;
String _$notificationActionsHash() =>
    r'23978d15c18a70173dfcbabd268b8044359d7338';

/// See also [NotificationActions].
@ProviderFor(NotificationActions)
final notificationActionsProvider =
    AutoDisposeNotifierProvider<NotificationActions, AsyncValue<void>>.internal(
      NotificationActions.new,
      name: r'notificationActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NotificationActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
