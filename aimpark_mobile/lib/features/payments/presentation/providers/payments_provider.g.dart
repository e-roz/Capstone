// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payments_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$paymentsRepositoryHash() =>
    r'1735fbd809247617810876154758e84d8343dea4';

/// See also [paymentsRepository].
@ProviderFor(paymentsRepository)
final paymentsRepositoryProvider =
    AutoDisposeProvider<PaymentsRepository>.internal(
      paymentsRepository,
      name: r'paymentsRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$paymentsRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PaymentsRepositoryRef = AutoDisposeProviderRef<PaymentsRepository>;
String _$paymentDetailHash() => r'84c7202f98c941be477f83e862b0ffa0f27a705b';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [paymentDetail].
@ProviderFor(paymentDetail)
const paymentDetailProvider = PaymentDetailFamily();

/// See also [paymentDetail].
class PaymentDetailFamily extends Family<AsyncValue<Payment>> {
  /// See also [paymentDetail].
  const PaymentDetailFamily();

  /// See also [paymentDetail].
  PaymentDetailProvider call(String paymentId) {
    return PaymentDetailProvider(paymentId);
  }

  @override
  PaymentDetailProvider getProviderOverride(
    covariant PaymentDetailProvider provider,
  ) {
    return call(provider.paymentId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'paymentDetailProvider';
}

/// See also [paymentDetail].
class PaymentDetailProvider extends AutoDisposeFutureProvider<Payment> {
  /// See also [paymentDetail].
  PaymentDetailProvider(String paymentId)
    : this._internal(
        (ref) => paymentDetail(ref as PaymentDetailRef, paymentId),
        from: paymentDetailProvider,
        name: r'paymentDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$paymentDetailHash,
        dependencies: PaymentDetailFamily._dependencies,
        allTransitiveDependencies:
            PaymentDetailFamily._allTransitiveDependencies,
        paymentId: paymentId,
      );

  PaymentDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.paymentId,
  }) : super.internal();

  final String paymentId;

  @override
  Override overrideWith(
    FutureOr<Payment> Function(PaymentDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PaymentDetailProvider._internal(
        (ref) => create(ref as PaymentDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        paymentId: paymentId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Payment> createElement() {
    return _PaymentDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PaymentDetailProvider && other.paymentId == paymentId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, paymentId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PaymentDetailRef on AutoDisposeFutureProviderRef<Payment> {
  /// The parameter `paymentId` of this provider.
  String get paymentId;
}

class _PaymentDetailProviderElement
    extends AutoDisposeFutureProviderElement<Payment>
    with PaymentDetailRef {
  _PaymentDetailProviderElement(super.provider);

  @override
  String get paymentId => (origin as PaymentDetailProvider).paymentId;
}

String _$paymentsNotifierHash() => r'c1941e7773728642bae5c35f6b49486403b7222c';

/// See also [PaymentsNotifier].
@ProviderFor(PaymentsNotifier)
final paymentsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      PaymentsNotifier,
      PaymentListResult
    >.internal(
      PaymentsNotifier.new,
      name: r'paymentsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$paymentsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PaymentsNotifier = AutoDisposeAsyncNotifier<PaymentListResult>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
