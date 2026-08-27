// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gateTagLookupHash() => r'6a1de0eb0e953c80f872716497d2aab696f1f068';

/// See also [gateTagLookup].
@ProviderFor(gateTagLookup)
final gateTagLookupProvider = AutoDisposeFutureProvider<TagLookup?>.internal(
  gateTagLookup,
  name: r'gateTagLookupProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$gateTagLookupHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GateTagLookupRef = AutoDisposeFutureProviderRef<TagLookup?>;
String _$visitorPassListHash() => r'4c7a1ed5ac72f765d065b93c093c7e8c14605743';

/// See also [visitorPassList].
@ProviderFor(visitorPassList)
final visitorPassListProvider =
    AutoDisposeFutureProvider<VisitorPassListPage>.internal(
      visitorPassList,
      name: r'visitorPassListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$visitorPassListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VisitorPassListRef = AutoDisposeFutureProviderRef<VisitorPassListPage>;
String _$visitorsOnSiteCountHash() =>
    r'8451bccfbb7679f5b87fce473f3e325f48a70d65';

/// How many cards are out right now — for the sidebar badge and the dashboard.
///
/// Copied from [visitorsOnSiteCount].
@ProviderFor(visitorsOnSiteCount)
final visitorsOnSiteCountProvider = AutoDisposeFutureProvider<int>.internal(
  visitorsOnSiteCount,
  name: r'visitorsOnSiteCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$visitorsOnSiteCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VisitorsOnSiteCountRef = AutoDisposeFutureProviderRef<int>;
String _$gateTagQueryHash() => r'029ea1de9d78d47590690b73611d73d5032a67bc';

/// The card the guard is currently looking at, or null when the box is empty.
///
/// Held in a provider rather than in the screen so the lookup result and the
/// entry/exit buttons that act on it cannot disagree about which card is in
/// hand — they read the same value.
///
/// Copied from [GateTagQuery].
@ProviderFor(GateTagQuery)
final gateTagQueryProvider =
    AutoDisposeNotifierProvider<GateTagQuery, String?>.internal(
      GateTagQuery.new,
      name: r'gateTagQueryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$gateTagQueryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GateTagQuery = AutoDisposeNotifier<String?>;
String _$visitorPassQueryNotifierHash() =>
    r'60d1fb17da1e642d70b0b32f456ddeaf8886ca23';

/// See also [VisitorPassQueryNotifier].
@ProviderFor(VisitorPassQueryNotifier)
final visitorPassQueryNotifierProvider =
    AutoDisposeNotifierProvider<
      VisitorPassQueryNotifier,
      VisitorPassQuery
    >.internal(
      VisitorPassQueryNotifier.new,
      name: r'visitorPassQueryNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$visitorPassQueryNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$VisitorPassQueryNotifier = AutoDisposeNotifier<VisitorPassQuery>;
String _$visitorPassActionsHash() =>
    r'd136c4e0b82532ee36e07ecfa94d2f97e179e57e';

/// See also [VisitorPassActions].
@ProviderFor(VisitorPassActions)
final visitorPassActionsProvider =
    AutoDisposeNotifierProvider<VisitorPassActions, AsyncValue<void>>.internal(
      VisitorPassActions.new,
      name: r'visitorPassActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$visitorPassActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$VisitorPassActions = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
