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
String _$registrationNotifierHash() =>
    r'eb84e81942ab1558a2ad602e833acf76cc6ae606';

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
