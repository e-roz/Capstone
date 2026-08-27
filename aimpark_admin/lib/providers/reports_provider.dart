import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/report.dart';

part 'reports_provider.g.dart';

/// How many days back every trend on Reports looks.
///
/// One window shared by all the charts, rather than each provider carrying its
/// own default, so "last 30 days" means the same thing on the sessions chart as
/// on the revenue chart — and so an exported CSV can name the period it covers.
@riverpod
class ReportWindow extends _$ReportWindow {
  @override
  int build() => 14;

  void setDays(int days) => state = days;
}

/// The windows offered in the picker. Kept short: every extra option is another
/// thing to explain, and nobody has asked for "last 3 days".
const reportWindowOptions = <int>[7, 14, 30, 90];

@riverpod
Future<ReportsSummary> reportsSummary(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.reportsSummary);
  return ReportsSummary.fromJson(response.data as Map<String, dynamic>);
}

@riverpod
Future<List<DailyCountPoint>> occupancyTrend(Ref ref, {int days = 14}) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.reportsOccupancyTrend,
      queryParameters: {'days': days});
  final data = response.data as Map<String, dynamic>;
  return (data['points'] as List<dynamic>? ?? [])
      .map((p) => DailyCountPoint.fromJson(p as Map<String, dynamic>))
      .toList();
}

@riverpod
Future<List<PeakHourPoint>> peakHours(Ref ref, {int days = 30}) async {
  final dio = ref.watch(dioProvider);
  final response =
      await dio.get(ApiEndpoints.reportsPeakHours, queryParameters: {'days': days});
  final data = response.data as Map<String, dynamic>;
  return (data['points'] as List<dynamic>? ?? [])
      .map((p) => PeakHourPoint.fromJson(p as Map<String, dynamic>))
      .toList();
}

@riverpod
Future<EntryExitReport> entryExitReport(Ref ref, {int days = 14}) async {
  final dio = ref.watch(dioProvider);
  final response = await dio
      .get(ApiEndpoints.reportsEntryExit, queryParameters: {'days': days});
  return EntryExitReport.fromJson(response.data as Map<String, dynamic>);
}

@riverpod
Future<ViolationBreakdown> violationsBreakdown(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiEndpoints.reportsViolationsBreakdown);
  return ViolationBreakdown.fromJson(response.data as Map<String, dynamic>);
}

@riverpod
Future<List<RevenuePoint>> revenueTrend(Ref ref, {int days = 14}) async {
  final dio = ref.watch(dioProvider);
  final response =
      await dio.get(ApiEndpoints.reportsRevenueTrend, queryParameters: {'days': days});
  final data = response.data as Map<String, dynamic>;
  return (data['points'] as List<dynamic>? ?? [])
      .map((p) => RevenuePoint.fromJson(p as Map<String, dynamic>))
      .toList();
}
