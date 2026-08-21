// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reports_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reportsSummaryHash() => r'8671b9e8a4724f691913d76cc2bb791872678f44';

/// See also [reportsSummary].
@ProviderFor(reportsSummary)
final reportsSummaryProvider =
    AutoDisposeFutureProvider<ReportsSummary>.internal(
      reportsSummary,
      name: r'reportsSummaryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$reportsSummaryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReportsSummaryRef = AutoDisposeFutureProviderRef<ReportsSummary>;
String _$occupancyTrendHash() => r'8d006271244e13798eece751c17a7a1e8b2dc08a';

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

/// See also [occupancyTrend].
@ProviderFor(occupancyTrend)
const occupancyTrendProvider = OccupancyTrendFamily();

/// See also [occupancyTrend].
class OccupancyTrendFamily extends Family<AsyncValue<List<DailyCountPoint>>> {
  /// See also [occupancyTrend].
  const OccupancyTrendFamily();

  /// See also [occupancyTrend].
  OccupancyTrendProvider call({int days = 14}) {
    return OccupancyTrendProvider(days: days);
  }

  @override
  OccupancyTrendProvider getProviderOverride(
    covariant OccupancyTrendProvider provider,
  ) {
    return call(days: provider.days);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'occupancyTrendProvider';
}

/// See also [occupancyTrend].
class OccupancyTrendProvider
    extends AutoDisposeFutureProvider<List<DailyCountPoint>> {
  /// See also [occupancyTrend].
  OccupancyTrendProvider({int days = 14})
    : this._internal(
        (ref) => occupancyTrend(ref as OccupancyTrendRef, days: days),
        from: occupancyTrendProvider,
        name: r'occupancyTrendProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$occupancyTrendHash,
        dependencies: OccupancyTrendFamily._dependencies,
        allTransitiveDependencies:
            OccupancyTrendFamily._allTransitiveDependencies,
        days: days,
      );

  OccupancyTrendProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.days,
  }) : super.internal();

  final int days;

  @override
  Override overrideWith(
    FutureOr<List<DailyCountPoint>> Function(OccupancyTrendRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: OccupancyTrendProvider._internal(
        (ref) => create(ref as OccupancyTrendRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        days: days,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<DailyCountPoint>> createElement() {
    return _OccupancyTrendProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OccupancyTrendProvider && other.days == days;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, days.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OccupancyTrendRef on AutoDisposeFutureProviderRef<List<DailyCountPoint>> {
  /// The parameter `days` of this provider.
  int get days;
}

class _OccupancyTrendProviderElement
    extends AutoDisposeFutureProviderElement<List<DailyCountPoint>>
    with OccupancyTrendRef {
  _OccupancyTrendProviderElement(super.provider);

  @override
  int get days => (origin as OccupancyTrendProvider).days;
}

String _$peakHoursHash() => r'3daa2a29812d08099dc2abd6b71ddb52ae394415';

/// See also [peakHours].
@ProviderFor(peakHours)
const peakHoursProvider = PeakHoursFamily();

/// See also [peakHours].
class PeakHoursFamily extends Family<AsyncValue<List<PeakHourPoint>>> {
  /// See also [peakHours].
  const PeakHoursFamily();

  /// See also [peakHours].
  PeakHoursProvider call({int days = 30}) {
    return PeakHoursProvider(days: days);
  }

  @override
  PeakHoursProvider getProviderOverride(covariant PeakHoursProvider provider) {
    return call(days: provider.days);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'peakHoursProvider';
}

/// See also [peakHours].
class PeakHoursProvider extends AutoDisposeFutureProvider<List<PeakHourPoint>> {
  /// See also [peakHours].
  PeakHoursProvider({int days = 30})
    : this._internal(
        (ref) => peakHours(ref as PeakHoursRef, days: days),
        from: peakHoursProvider,
        name: r'peakHoursProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$peakHoursHash,
        dependencies: PeakHoursFamily._dependencies,
        allTransitiveDependencies: PeakHoursFamily._allTransitiveDependencies,
        days: days,
      );

  PeakHoursProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.days,
  }) : super.internal();

  final int days;

  @override
  Override overrideWith(
    FutureOr<List<PeakHourPoint>> Function(PeakHoursRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PeakHoursProvider._internal(
        (ref) => create(ref as PeakHoursRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        days: days,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<PeakHourPoint>> createElement() {
    return _PeakHoursProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PeakHoursProvider && other.days == days;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, days.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PeakHoursRef on AutoDisposeFutureProviderRef<List<PeakHourPoint>> {
  /// The parameter `days` of this provider.
  int get days;
}

class _PeakHoursProviderElement
    extends AutoDisposeFutureProviderElement<List<PeakHourPoint>>
    with PeakHoursRef {
  _PeakHoursProviderElement(super.provider);

  @override
  int get days => (origin as PeakHoursProvider).days;
}

String _$violationsBreakdownHash() =>
    r'fef23d61891f045609b132b22832c17cbfedaffc';

/// See also [violationsBreakdown].
@ProviderFor(violationsBreakdown)
final violationsBreakdownProvider =
    AutoDisposeFutureProvider<ViolationBreakdown>.internal(
      violationsBreakdown,
      name: r'violationsBreakdownProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$violationsBreakdownHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ViolationsBreakdownRef =
    AutoDisposeFutureProviderRef<ViolationBreakdown>;
String _$revenueTrendHash() => r'e5eed4fbcb5189197942e08029da1fbcb5c044ac';

/// See also [revenueTrend].
@ProviderFor(revenueTrend)
const revenueTrendProvider = RevenueTrendFamily();

/// See also [revenueTrend].
class RevenueTrendFamily extends Family<AsyncValue<List<RevenuePoint>>> {
  /// See also [revenueTrend].
  const RevenueTrendFamily();

  /// See also [revenueTrend].
  RevenueTrendProvider call({int days = 14}) {
    return RevenueTrendProvider(days: days);
  }

  @override
  RevenueTrendProvider getProviderOverride(
    covariant RevenueTrendProvider provider,
  ) {
    return call(days: provider.days);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'revenueTrendProvider';
}

/// See also [revenueTrend].
class RevenueTrendProvider
    extends AutoDisposeFutureProvider<List<RevenuePoint>> {
  /// See also [revenueTrend].
  RevenueTrendProvider({int days = 14})
    : this._internal(
        (ref) => revenueTrend(ref as RevenueTrendRef, days: days),
        from: revenueTrendProvider,
        name: r'revenueTrendProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$revenueTrendHash,
        dependencies: RevenueTrendFamily._dependencies,
        allTransitiveDependencies:
            RevenueTrendFamily._allTransitiveDependencies,
        days: days,
      );

  RevenueTrendProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.days,
  }) : super.internal();

  final int days;

  @override
  Override overrideWith(
    FutureOr<List<RevenuePoint>> Function(RevenueTrendRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RevenueTrendProvider._internal(
        (ref) => create(ref as RevenueTrendRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        days: days,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<RevenuePoint>> createElement() {
    return _RevenueTrendProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RevenueTrendProvider && other.days == days;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, days.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RevenueTrendRef on AutoDisposeFutureProviderRef<List<RevenuePoint>> {
  /// The parameter `days` of this provider.
  int get days;
}

class _RevenueTrendProviderElement
    extends AutoDisposeFutureProviderElement<List<RevenuePoint>>
    with RevenueTrendRef {
  _RevenueTrendProviderElement(super.provider);

  @override
  int get days => (origin as RevenueTrendProvider).days;
}

String _$reportWindowHash() => r'e31e113c116dc60f026f81073343bd0d40e56465';

/// How many days back every trend on Reports looks.
///
/// One window shared by all the charts, rather than each provider carrying its
/// own default, so "last 30 days" means the same thing on the sessions chart as
/// on the revenue chart — and so an exported CSV can name the period it covers.
///
/// Copied from [ReportWindow].
@ProviderFor(ReportWindow)
final reportWindowProvider =
    AutoDisposeNotifierProvider<ReportWindow, int>.internal(
      ReportWindow.new,
      name: r'reportWindowProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$reportWindowHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReportWindow = AutoDisposeNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
