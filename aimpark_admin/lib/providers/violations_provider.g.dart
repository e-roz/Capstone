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
String _$violationListHash() => r'9524b62a5502711b52572229376d8eb35333933c';

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
String _$policyRuleActionsHash() => r'93b1e4b7c1bdcacf9ad29c9c38f9ad92d452e893';

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
    r'a9c63e94e2eebcc12b9582f6b206b1c19824523c';

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
String _$violationActionsHash() => r'409f0770711cfbc288dddc75e409a47c50da8c94';

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
