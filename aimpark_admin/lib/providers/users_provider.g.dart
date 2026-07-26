// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userListHash() => r'a4c288334ba6eec1bf180d1399b4b90cf856f4d5';

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
    r'320fd9f0ae889df6ee5befa31891ed328af57876';

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
String _$userActionsHash() => r'881feef0e4d2460613a0f76d67d795e687d499ca';

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
