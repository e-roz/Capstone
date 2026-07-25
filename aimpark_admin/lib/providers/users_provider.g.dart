// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userListHash() => r'744aa973b20cbdc7709ebc71e96b88a9df7f7a37';

/// See also [userList].
@ProviderFor(userList)
final userListProvider = AutoDisposeFutureProvider<UserListPage>.internal(
  userList,
  name: r'userListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserListRef = AutoDisposeFutureProviderRef<UserListPage>;
String _$usersQueryNotifierHash() =>
    r'f9b113e7b48d505ca6d32160d15d1d0623485cf7';

/// See also [UsersQueryNotifier].
@ProviderFor(UsersQueryNotifier)
final usersQueryNotifierProvider =
    AutoDisposeNotifierProvider<UsersQueryNotifier, UsersQuery>.internal(
      UsersQueryNotifier.new,
      name: r'usersQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$usersQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UsersQueryNotifier = AutoDisposeNotifier<UsersQuery>;
String _$userActionsHash() => r'ec0b9aacf3e4bb2bd31727d4426e499cbb4cfac5';

/// See also [UserActions].
@ProviderFor(UserActions)
final userActionsProvider =
    AutoDisposeNotifierProvider<UserActions, AsyncValue<void>>.internal(
      UserActions.new,
      name: r'userActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$userActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
