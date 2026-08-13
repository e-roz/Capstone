// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_registration_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pushRegistrationHash() => r'b524334ef39a8855b182dcc2bbe627f93e828a15';

/// Owns the FCM token lifecycle: registers this device with the backend after
/// login, keeps it current when FCM rotates the token, and tears it down on logout.
///
/// Every call is best-effort — a user who denies notification permission, or a
/// device without Play Services, must still be able to use the whole app.
///
/// Copied from [PushRegistration].
@ProviderFor(PushRegistration)
final pushRegistrationProvider =
    NotifierProvider<PushRegistration, void>.internal(
      PushRegistration.new,
      name: r'pushRegistrationProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pushRegistrationHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PushRegistration = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
