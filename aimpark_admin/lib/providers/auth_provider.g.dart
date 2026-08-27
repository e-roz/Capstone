// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$staffRoleHash() => r'4fa4e4284130a7b7ccb506a1ed1cf6bef2538b86';

/// Which kind of staff account is signed in.
///
/// Several screens are shared between the two roles and differ only in which
/// tabs or panels they show. Reading the role from one provider keeps that
/// decision in the same shape everywhere, rather than each screen decoding the
/// token for itself.
///
/// Null while the token is still being read, and for anything that is not a
/// staff account - the router sends both cases to the login screen.
///
/// Copied from [staffRole].
@ProviderFor(staffRole)
final staffRoleProvider = AutoDisposeProvider<StaffRole?>.internal(
  staffRole,
  name: r'staffRoleProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$staffRoleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StaffRoleRef = AutoDisposeProviderRef<StaffRole?>;
String _$authNotifierHash() => r'88a62bee387dc0cd1e4abf08d1ba5cd2bad64849';

/// See also [AuthNotifier].
@ProviderFor(AuthNotifier)
final authNotifierProvider =
    AutoDisposeAsyncNotifierProvider<AuthNotifier, String?>.internal(
      AuthNotifier.new,
      name: r'authNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$authNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AuthNotifier = AutoDisposeAsyncNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
