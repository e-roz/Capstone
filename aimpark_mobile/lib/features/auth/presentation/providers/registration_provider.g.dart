// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registration_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$documentScannerHash() => r'ddda45704ed8db1a6201a76704e7066fff965802';

/// One text recogniser for the whole registration flow.
///
/// The documents are now captured on four separate screens, so a recogniser
/// owned by a screen would load the model four times over. Kept alive across
/// them and closed when the flow's providers go.
///
/// Copied from [documentScanner].
@ProviderFor(documentScanner)
final documentScannerProvider = Provider<DocumentScanner>.internal(
  documentScanner,
  name: r'documentScannerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$documentScannerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DocumentScannerRef = ProviderRef<DocumentScanner>;
String _$documentAgendaHash() => r'a192f740daaf3c10e6b00b167228288fc3209efe';

/// Which documents to ask for: all four, or only the ones sent back.
///
/// Asked of the server rather than inferred, because only the server knows a
/// reviewer has been through the submission. Falling back to the full set on any
/// failure is deliberate — a network error must not silently turn a first
/// registration into a one-document one, and asking for a document already on
/// file costs a photograph while asking for too few costs a rejected
/// application.
///
/// Copied from [documentAgenda].
@ProviderFor(documentAgenda)
final documentAgendaProvider =
    AutoDisposeFutureProvider<DocumentAgenda>.internal(
      documentAgenda,
      name: r'documentAgendaProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$documentAgendaHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DocumentAgendaRef = AutoDisposeFutureProviderRef<DocumentAgenda>;
String _$registrationNotifierHash() =>
    r'351cabd372c6390edf12888ff3224177b1911f6f';

/// See also [RegistrationNotifier].
@ProviderFor(RegistrationNotifier)
final registrationNotifierProvider =
    NotifierProvider<RegistrationNotifier, RegistrationState>.internal(
      RegistrationNotifier.new,
      name: r'registrationNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$registrationNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RegistrationNotifier = Notifier<RegistrationState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
