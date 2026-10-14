import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/report.dart';
import 'overview_provider.dart';

/// The period the Reports page covers. Its own state, not the Overview's: the
/// two pages are looked at for different reasons, but they offer the same
/// choices and read days the same way (Philippine days, inclusive).
final reportPeriodProvider = StateProvider<OverviewPeriod>(
  (ref) => const OverviewPeriod(OverviewPreset.last7),
);

Future<Map<String, dynamic>> _get(Ref ref, String path) async {
  final period = ref.watch(reportPeriodProvider);
  final response = await ref
      .watch(dioProvider)
      .get(path, queryParameters: period.query);
  return response.data as Map<String, dynamic>;
}

List<T> _points<T>(Map<String, dynamic> data, T Function(Map<String, dynamic>) read) => [
      for (final p in data['points'] as List<dynamic>? ?? const [])
        read(p as Map<String, dynamic>),
    ];

String _granularity(Map<String, dynamic> data) =>
    (data['period'] as Map?)?['granularity']?.toString() ?? 'day';

/// The headline figures, with the period before it for comparison.
final reportSummaryProvider = FutureProvider.autoDispose<ReportsSummary>((ref) async {
  return ReportsSummary.fromJson(await _get(ref, ApiEndpoints.reportsSummary));
});

final reportEntryExitProvider = FutureProvider.autoDispose<EntryExitReport>((ref) async {
  return EntryExitReport.fromJson(await _get(ref, ApiEndpoints.reportsEntryExit));
});

final reportHoursProvider = FutureProvider.autoDispose<List<PeakHourPoint>>((ref) async {
  return _points(await _get(ref, ApiEndpoints.reportsPeakHours), PeakHourPoint.fromJson);
});

final reportRevenueProvider =
    FutureProvider.autoDispose<ReportSeries<RevenuePoint>>((ref) async {
  final data = await _get(ref, ApiEndpoints.reportsRevenueTrend);
  return ReportSeries(
    granularity: _granularity(data),
    points: _points(data, RevenuePoint.fromJson),
  );
});

final reportGateOutcomesProvider = FutureProvider.autoDispose<GateOutcomes>((ref) async {
  return GateOutcomes.fromJson(await _get(ref, ApiEndpoints.reportsGateOutcomes));
});

final reportPeakOccupancyProvider = FutureProvider.autoDispose<PeakOccupancy>((ref) async {
  return PeakOccupancy.fromJson(await _get(ref, ApiEndpoints.reportsPeakOccupancy));
});

/// Violations issued in the period, by their current status and by rule.
final reportViolationsProvider = FutureProvider.autoDispose<ViolationBreakdown>((ref) async {
  return ViolationBreakdown.fromJson(
    await _get(ref, ApiEndpoints.reportsViolationsBreakdown),
  );
});
