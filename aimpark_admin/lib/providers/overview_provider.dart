import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/ph_time.dart';
import '../models/gate_tap_event.dart';
import '../models/incident.dart';
import '../models/report.dart';
import '../models/violation.dart';

/// How often the Overview re-reads its live figures (free bays, what needs
/// attention). The period's own figures ride along: it is one request.
const overviewRefreshEvery = Duration(seconds: 15);

enum OverviewPreset { today, yesterday, last7, last30, allTime, day, range }

/// The stretch of days the Overview's history figures cover: the trend, the
/// period totals and the activity feed. What is happening right now (free
/// bays, who is inside, what is waiting on the admin) never depends on it.
///
/// Days are Philippine calendar days, however the PC showing the panel is set,
/// and the API is asked in the same terms (`yyyy-MM-dd`, inclusive).
class OverviewPeriod {
  const OverviewPeriod(this.preset, {this.from, this.to});

  static const today = OverviewPeriod(OverviewPreset.today);

  final OverviewPreset preset;

  /// First and last day of a picked [OverviewPreset.day] or
  /// [OverviewPreset.range], as plain dates.
  final DateTime? from;
  final DateTime? to;

  bool get allTime => preset == OverviewPreset.allTime;

  static final _iso = DateFormat('yyyy-MM-dd');
  static final _short = DateFormat('MMM d');
  static final _full = DateFormat('MMM d, yyyy');

  static DateTime get _today {
    final m = manilaNow();
    return DateTime(m.year, m.month, m.day);
  }

  /// The first and last day covered, or null for all time.
  ({DateTime from, DateTime to})? get days {
    final today = _today;
    switch (preset) {
      case OverviewPreset.today:
        return (from: today, to: today);
      case OverviewPreset.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return (from: y, to: y);
      case OverviewPreset.last7:
        return (from: today.subtract(const Duration(days: 6)), to: today);
      case OverviewPreset.last30:
        return (from: today.subtract(const Duration(days: 29)), to: today);
      case OverviewPreset.allTime:
        return null;
      case OverviewPreset.day:
      case OverviewPreset.range:
        final a = from ?? today;
        final b = to ?? a;
        return b.isBefore(a) ? (from: b, to: a) : (from: a, to: b);
    }
  }

  /// What the reports endpoints are asked.
  Map<String, dynamic> get query {
    final d = days;
    return d == null
        ? const {'allTime': true}
        : {'from': _iso.format(d.from), 'to': _iso.format(d.to)};
  }

  /// The UTC moment the first day begins, for endpoints that take instants.
  DateTime? get fromUtc {
    final d = days;
    return d == null
        ? null
        : DateTime.utc(d.from.year, d.from.month, d.from.day).subtract(_manilaOffset);
  }

  /// The UTC moment the last day ends.
  DateTime? get toUtc {
    final d = days;
    return d == null
        ? null
        : DateTime.utc(d.to.year, d.to.month, d.to.day, 23, 59, 59).subtract(_manilaOffset);
  }

  static const _manilaOffset = Duration(hours: 8);

  /// Whether a moment falls inside the period. Always true for all time.
  bool contains(DateTime moment) {
    final a = fromUtc;
    final b = toUtc;
    if (a == null || b == null) return true;
    final utc = moment.toUtc();
    return !utc.isBefore(a) && !utc.isAfter(b);
  }

  String get label {
    final d = days;
    return switch (preset) {
      OverviewPreset.today => 'Today · ${_short.format(d!.from)}',
      OverviewPreset.yesterday => 'Yesterday · ${_short.format(d!.from)}',
      OverviewPreset.last7 => 'Last 7 days',
      OverviewPreset.last30 => 'Last 30 days',
      OverviewPreset.allTime => 'All time',
      OverviewPreset.day => _full.format(d!.from),
      OverviewPreset.range => d!.from == d.to
          ? _full.format(d.from)
          : '${_short.format(d.from)} – ${_full.format(d.to)}',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is OverviewPeriod &&
      other.preset == preset &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(preset, from, to);
}

final overviewPeriodProvider =
    StateProvider<OverviewPeriod>((ref) => OverviewPeriod.today);

/// The summary for the period, kept fresh while the Overview is open.
///
/// One request feeds the whole page: free bays and what is owed are live, the
/// session, money and violation totals follow the period.
final overviewSummaryProvider =
    FutureProvider.autoDispose<ReportsSummary>((ref) async {
  final period = ref.watch(overviewPeriodProvider);
  final timer = Timer(overviewRefreshEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  final response = await ref
      .watch(dioProvider)
      .get(ApiEndpoints.reportsSummary, queryParameters: period.query);
  return ReportsSummary.fromJson(response.data as Map<String, dynamic>);
});

/// Entries by hour of the (Philippine) day, over the period.
final overviewHoursProvider =
    FutureProvider.autoDispose<List<PeakHourPoint>>((ref) async {
  final period = ref.watch(overviewPeriodProvider);
  final response = await ref
      .watch(dioProvider)
      .get(ApiEndpoints.reportsPeakHours, queryParameters: period.query);
  final data = response.data as Map<String, dynamic>;
  return [
    for (final p in data['points'] as List<dynamic>? ?? [])
      PeakHourPoint.fromJson(p as Map<String, dynamic>),
  ];
});

enum FeedKind { denial, incident, violation }

/// One thing that needs a look, from any of the three places it can come from.
class FeedItem {
  const FeedItem({
    required this.kind,
    required this.at,
    required this.title,
    required this.detail,
    required this.route,
  });

  final FeedKind kind;
  final DateTime at;
  final String title;
  final String detail;

  /// Where the full list lives.
  final String route;
}

/// How many things the feed shows. It is a nudge to go and look, not a log.
const _feedLength = 8;

/// The refusals, incidents and violations worth a look in the period, newest
/// first.
///
/// Normal entries and exits, and routine refusals (a full lot, a double tap,
/// no camera reading), stay on the Gate Taps page.
final overviewFeedProvider =
    FutureProvider.autoDispose<List<FeedItem>>((ref) async {
  final period = ref.watch(overviewPeriodProvider);
  final dio = ref.watch(dioProvider);

  final from = period.fromUtc;
  final to = period.toUtc;

  final results = await Future.wait([
    dio.get(ApiEndpoints.liveGateHistory, queryParameters: {
      'page': 1,
      'pageSize': _feedLength,
      'result': 'denied',
      'serious': true,
      'from': ?from?.toIso8601String(),
      'to': ?to?.toIso8601String(),
    }),
    dio.get(ApiEndpoints.incidents,
        queryParameters: {'page': 1, 'pageSize': 20}),
    dio.get(ApiEndpoints.violations,
        queryParameters: {'page': 1, 'pageSize': 20}),
  ]);

  final taps =
      GateTapPage.fromJson(results[0].data as Map<String, dynamic>).taps;
  final incidents =
      IncidentListPage.fromJson(results[1].data as Map<String, dynamic>)
          .incidents;
  final violations =
      ViolationListPage.fromJson(results[2].data as Map<String, dynamic>)
          .violations;

  final items = <FeedItem>[
    for (final t in taps)
      FeedItem(
        kind: FeedKind.denial,
        at: t.at,
        title: t.plateMatches == false
            ? 'Plate mismatch, Gate ${t.gate}'
            : 'Unknown card, Gate ${t.gate}',
        detail: t.plateMatches == false
            ? '${t.cameraPlate ?? 'A plate'} on the card of ${t.personName ?? 'its holder'}'
            : t.rfidTagId ?? 'No card id',
        route: '/gate-taps',
      ),
    for (final i in incidents)
      if (period.contains(i.createdAt))
        FeedItem(
          kind: FeedKind.incident,
          at: i.createdAt,
          title: 'New incident: ${_words(i.category)}',
          detail: '${i.reportedByName} · ${_words(i.status)}',
          route: '/incidents',
        ),
    for (final v in violations)
      if (period.contains(v.createdAt))
        FeedItem(
          kind: FeedKind.violation,
          at: v.createdAt,
          title: 'Violation issued: ${v.policyRuleTitle}',
          detail: '${v.userFullName} · ${_words(v.status)}',
          route: '/violations',
        ),
  ]..sort((a, b) => b.at.compareTo(a.at));

  return items.take(_feedLength).toList();
});

/// "WrongBay" → "wrong bay", "UnderReview" → "under review".
String _words(String pascal) => pascal
    .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
    .toLowerCase();
