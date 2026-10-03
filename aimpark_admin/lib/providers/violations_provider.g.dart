// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'violations_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$policyRulesHash() => r'cf2b7a883374cba03cf618e586e585b3cc220706';

/// See also [policyRules].
@ProviderFor(policyRules)
final policyRulesProvider =
    AutoDisposeFutureProvider<List<PolicyRule>>.internal(
      policyRules,
      name: r'policyRulesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$policyRulesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PolicyRulesRef = AutoDisposeFutureProviderRef<List<PolicyRule>>;
String _$violationListHash() => r'351c7bd3e5d151fe6ac0d5a28a4da24ee3d56e71';

/// See also [violationList].
@ProviderFor(violationList)
final violationListProvider =
    AutoDisposeFutureProvider<ViolationListPage>.internal(
      violationList,
      name: r'violationListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$violationListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ViolationListRef = AutoDisposeFutureProviderRef<ViolationListPage>;
String _$violationDetailHash() => r'4d7e47a5bada1ba0cee9d99dc770c84f391560c3';

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

/// One violation with everything the View dialog needs: the user, the full
/// rule, the appeal and the timeline.
///
/// Copied from [violationDetail].
@ProviderFor(violationDetail)
const violationDetailProvider = ViolationDetailFamily();

/// One violation with everything the View dialog needs: the user, the full
/// rule, the appeal and the timeline.
///
/// Copied from [violationDetail].
class ViolationDetailFamily extends Family<AsyncValue<ViolationDetail>> {
  /// One violation with everything the View dialog needs: the user, the full
  /// rule, the appeal and the timeline.
  ///
  /// Copied from [violationDetail].
  const ViolationDetailFamily();

  /// One violation with everything the View dialog needs: the user, the full
  /// rule, the appeal and the timeline.
  ///
  /// Copied from [violationDetail].
  ViolationDetailProvider call(String violationId) {
    return ViolationDetailProvider(violationId);
  }

  @override
  ViolationDetailProvider getProviderOverride(
    covariant ViolationDetailProvider provider,
  ) {
    return call(provider.violationId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'violationDetailProvider';
}

/// One violation with everything the View dialog needs: the user, the full
/// rule, the appeal and the timeline.
///
/// Copied from [violationDetail].
class ViolationDetailProvider
    extends AutoDisposeFutureProvider<ViolationDetail> {
  /// One violation with everything the View dialog needs: the user, the full
  /// rule, the appeal and the timeline.
  ///
  /// Copied from [violationDetail].
  ViolationDetailProvider(String violationId)
    : this._internal(
        (ref) => violationDetail(ref as ViolationDetailRef, violationId),
        from: violationDetailProvider,
        name: r'violationDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$violationDetailHash,
        dependencies: ViolationDetailFamily._dependencies,
        allTransitiveDependencies:
            ViolationDetailFamily._allTransitiveDependencies,
        violationId: violationId,
      );

  ViolationDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.violationId,
  }) : super.internal();

  final String violationId;

  @override
  Override overrideWith(
    FutureOr<ViolationDetail> Function(ViolationDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ViolationDetailProvider._internal(
        (ref) => create(ref as ViolationDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        violationId: violationId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ViolationDetail> createElement() {
    return _ViolationDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ViolationDetailProvider && other.violationId == violationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, violationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ViolationDetailRef on AutoDisposeFutureProviderRef<ViolationDetail> {
  /// The parameter `violationId` of this provider.
  String get violationId;
}

class _ViolationDetailProviderElement
    extends AutoDisposeFutureProviderElement<ViolationDetail>
    with ViolationDetailRef {
  _ViolationDetailProviderElement(super.provider);

  @override
  String get violationId => (origin as ViolationDetailProvider).violationId;
}

String _$violationLogListHash() => r'55231a23e1711f8a4b54d8e57a6e1c467756efd7';

/// See also [violationLogList].
@ProviderFor(violationLogList)
final violationLogListProvider =
    AutoDisposeFutureProvider<ViolationListPage>.internal(
      violationLogList,
      name: r'violationLogListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$violationLogListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ViolationLogListRef = AutoDisposeFutureProviderRef<ViolationListPage>;
String _$appealListHash() => r'6ad3dadbd547e358885dfec0d763f9614f1957b6';

/// See also [appealList].
@ProviderFor(appealList)
final appealListProvider =
    AutoDisposeFutureProvider<ViolationAppealListPage>.internal(
      appealList,
      name: r'appealListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$appealListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppealListRef = AutoDisposeFutureProviderRef<ViolationAppealListPage>;
String _$pendingAppealCountHash() =>
    r'f7be473b027a09979f4d1cca0f60623929e42b41';

/// How many appeals are still waiting on a decision. See [openIncidentCount]
/// for why this is a request of its own rather than a count off the list.
///
/// Copied from [pendingAppealCount].
@ProviderFor(pendingAppealCount)
final pendingAppealCountProvider = AutoDisposeFutureProvider<int>.internal(
  pendingAppealCount,
  name: r'pendingAppealCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pendingAppealCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingAppealCountRef = AutoDisposeFutureProviderRef<int>;
String _$policyRuleActionsHash() => r'e7b356ef827e971a45434ce81edee597d4caa75c';

/// See also [PolicyRuleActions].
@ProviderFor(PolicyRuleActions)
final policyRuleActionsProvider =
    AutoDisposeNotifierProvider<PolicyRuleActions, AsyncValue<void>>.internal(
      PolicyRuleActions.new,
      name: r'policyRuleActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$policyRuleActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PolicyRuleActions = AutoDisposeNotifier<AsyncValue<void>>;
String _$violationsQueryNotifierHash() =>
    r'4345802f4327df180055350523e64a44ab913bd3';

/// See also [ViolationsQueryNotifier].
@ProviderFor(ViolationsQueryNotifier)
final violationsQueryNotifierProvider =
    AutoDisposeNotifierProvider<
      ViolationsQueryNotifier,
      ViolationsQuery
    >.internal(
      ViolationsQueryNotifier.new,
      name: r'violationsQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$violationsQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ViolationsQueryNotifier = AutoDisposeNotifier<ViolationsQuery>;
String _$violationLogsQueryNotifierHash() =>
    r'a00059fa5216ceb7326d6be01ef6876f1a4974f0';

/// The same endpoint as [violationList], behind its own query state.
///
/// System Logs shows violations as an audit trail while Violation Tracking
/// shows them as a work queue. Sharing one notifier between the two would mean
/// filtering the log silently re-filtered the queue you left behind on the
/// other screen, and paging one paged the other.
///
/// Copied from [ViolationLogsQueryNotifier].
@ProviderFor(ViolationLogsQueryNotifier)
final violationLogsQueryNotifierProvider =
    AutoDisposeNotifierProvider<
      ViolationLogsQueryNotifier,
      ViolationsQuery
    >.internal(
      ViolationLogsQueryNotifier.new,
      name: r'violationLogsQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$violationLogsQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ViolationLogsQueryNotifier = AutoDisposeNotifier<ViolationsQuery>;
String _$appealsQueryNotifierHash() =>
    r'bdba963767734d4edbf144c4d9ab510dc2029be9';

/// See also [AppealsQueryNotifier].
@ProviderFor(AppealsQueryNotifier)
final appealsQueryNotifierProvider =
    AutoDisposeNotifierProvider<AppealsQueryNotifier, AppealsQuery>.internal(
      AppealsQueryNotifier.new,
      name: r'appealsQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$appealsQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AppealsQueryNotifier = AutoDisposeNotifier<AppealsQuery>;
String _$violationActionsHash() => r'081cadbab58781fcb8402d928922d0da133a5cdf';

/// See also [ViolationActions].
@ProviderFor(ViolationActions)
final violationActionsProvider =
    AutoDisposeNotifierProvider<ViolationActions, AsyncValue<void>>.internal(
      ViolationActions.new,
      name: r'violationActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$violationActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ViolationActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
