import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportsSummaryProvider);
    final occupancyAsync = ref.watch(occupancyTrendProvider(days: 14));
    final peakHoursAsync = ref.watch(peakHoursProvider(days: 30));
    final revenueAsync = ref.watch(revenueTrendProvider(days: 14));
    final violationsAsync = ref.watch(violationsBreakdownProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Reports & Analytics',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    ref.invalidate(reportsSummaryProvider);
                    ref.invalidate(occupancyTrendProvider);
                    ref.invalidate(peakHoursProvider);
                    ref.invalidate(revenueTrendProvider);
                    ref.invalidate(violationsBreakdownProvider);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summaryAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Failed to load summary: $e'),
                      data: (s) => _SummaryTiles(summary: s),
                    ),
                    const SizedBox(height: 24),
                    _ChartCard(
                      title: 'Parking Sessions — Last 14 Days',
                      child: occupancyAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Failed to load: $e'),
                        data: (points) => _SimpleBarChart(
                          bars: points
                              .map((p) => _Bar(
                                  label: DateFormat('M/d').format(p.date.toLocal()),
                                  value: p.count.toDouble(),
                                  tooltip: '${p.count} sessions'))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ChartCard(
                      title: 'Peak Hours — Last 30 Days',
                      child: peakHoursAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Failed to load: $e'),
                        data: (points) => _SimpleBarChart(
                          bars: points
                              .map((p) => _Bar(
                                  label: p.hour.toString(),
                                  value: p.count.toDouble(),
                                  tooltip: '${p.count} entries at ${p.hour}:00'))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ChartCard(
                      title: 'Revenue Collected — Last 14 Days',
                      child: revenueAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Failed to load: $e'),
                        data: (points) => _SimpleBarChart(
                          bars: points
                              .map((p) => _Bar(
                                  label: DateFormat('M/d').format(p.date.toLocal()),
                                  value: p.amount,
                                  tooltip: '₱${p.amount.toStringAsFixed(2)}'))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    violationsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Failed to load violation breakdown: $e'),
                      data: (breakdown) => _ViolationBreakdownSection(breakdown: breakdown),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary tiles ─────────────────────────────────────────────────────────

class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile('Total Users', '${summary.totalUsers}', Icons.people, Colors.blue),
      _Tile('Active Users', '${summary.activeUsers}', Icons.person, Colors.green),
      _Tile('Slots Occupied', '${summary.occupiedSlots}/${summary.totalSlots}',
          Icons.local_parking, Colors.orange),
      _Tile('Sessions Today', '${summary.sessionsToday}', Icons.directions_car,
          Colors.purple),
      _Tile('Revenue Collected', '₱${summary.revenueCollected.toStringAsFixed(2)}',
          Icons.payments, Colors.teal),
      _Tile('Revenue Pending', '₱${summary.revenuePending.toStringAsFixed(2)}',
          Icons.hourglass_bottom, Colors.amber),
      _Tile('Violations Issued', '${summary.violationsIssued}', Icons.gavel,
          Colors.red),
      _Tile('Open Incidents', '${summary.openIncidents}', Icons.report,
          Colors.deepOrange),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: tiles,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart card + simple bar chart (no external chart dependency) ──────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(height: 160, child: child),
        ],
      ),
    );
  }
}

class _Bar {
  const _Bar({required this.label, required this.value, required this.tooltip});

  final String label;
  final double value;
  final String tooltip;
}

class _SimpleBarChart extends StatelessWidget {
  const _SimpleBarChart({required this.bars});

  final List<_Bar> bars;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const Center(child: Text('No data yet.'));
    }
    final maxValue = bars.map((b) => b.value).fold<double>(0, (a, b) => b > a ? b : a);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars
          .map((b) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Tooltip(
                    message: b.tooltip,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: maxValue == 0 ? 2 : 4 + (b.value / maxValue) * 110,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(b.label,
                            style: const TextStyle(fontSize: 9, color: Colors.black54),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ── Violation breakdown ─────────────────────────────────────────────────────

class _ViolationBreakdownSection extends StatelessWidget {
  const _ViolationBreakdownSection({required this.breakdown});

  final ViolationBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _BreakdownCard(
          title: 'Violations by Status',
          rows: breakdown.byStatus.isEmpty
              ? [const Text('No violations yet.')]
              : breakdown.byStatus
                  .map((s) => _breakdownRow(s.status, s.count))
                  .toList(),
        )),
        const SizedBox(width: 16),
        Expanded(child: _BreakdownCard(
          title: 'Top Violated Rules',
          rows: breakdown.byRule.isEmpty
              ? [const Text('No violations yet.')]
              : breakdown.byRule
                  .map((r) => _breakdownRow(r.ruleTitle, r.count))
                  .toList(),
        )),
      ],
    );
  }

  Widget _breakdownRow(String label, int count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}
