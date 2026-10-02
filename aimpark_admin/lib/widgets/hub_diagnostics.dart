import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/gate_reader.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// The result of a connection test, one card per board: did it answer, how
/// fast, how strong the signal is both ways, and what on it needs a look.
Future<void> showHubDiagnostics(BuildContext context, List<HubDiagnosis> results) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connection test'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in results) ...[
                  _DiagnosisCard(result: r),
                  const SizedBox(height: AppSpacing.x3),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );

/// The status pill for a board's last connection test.
(String, StatusIntent) diagnosisStatus(HubDiagnosis d) => switch (d) {
      HubDiagnosis(ok: false) => ('No answer', StatusIntent.danger),
      HubDiagnosis(healthy: false) => ('Needs a look', StatusIntent.warning),
      _ => ('OK', StatusIntent.success),
    };

/// "OK · 14 ms · −52 dBm" for the board's row.
String diagnosisSummary(HubDiagnosis d) {
  if (!d.ok) return 'No answer';
  return [
    '${d.airMs ?? d.roundTripMs} ms',
    if (d.rssi != null) '${d.rssi} dBm',
  ].join(' · ');
}

class _DiagnosisCard extends StatelessWidget {
  const _DiagnosisCard({required this.result});

  final HubDiagnosis result;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final r = result;
    final (label, intent) = diagnosisStatus(r);
    final v = r.values;

    final rows = <(String, String)>[
      ('Round trip', r.airMs == null
          ? '${r.roundTripMs} ms'
          : '${r.airMs} ms over the air · ${r.roundTripMs} ms with USB'),
      if (r.rssi != null) ('Board heard at the hub', '${r.rssi} dBm (${signalLabel(r.rssi!)})'),
      if (r.boardRssi != null) ('Hub heard at the board', '${r.boardRssi} dBm (${signalLabel(r.boardRssi!)})'),
      if (r.uptime != null) ('Running for', _duration(r.uptime!)),
      if (v['reset'] != null) ('Last restart', _resetLabel(v['reset']!)),
      if (v['fails'] != null) ('Messages not delivered', '${v['fails']} since it started'),
      if (v['drops'] != null) ('Times it went offline', '${v['drops']} since the hub started'),
      if (v['rc522'] != null) ('Card reader', _rc522Label(v['rc522']!)),
      if (v['sensors'] != null) ('Sensors', _sensorsLabel(r.node, v['sensors']!, v['noecho'])),
      if (v['nodes'] != null) ('Boards paired', v['nodes']!),
      if (v['id'] != null) ('Hub id', v['id']!),
      if (v['heap'] != null) ('Free memory', '${v['heap']} KB'),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        border: Border.all(color: t.border.subtle),
        borderRadius: AppRadii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_icon(r.node), size: AppSizes.iconSm, color: t.text.secondary),
              const SizedBox(width: AppSpacing.x2),
              Expanded(child: Text(r.isHub ? 'Hub (USB)' : r.node, style: text.titleSmall)),
              StatusPill(label: label, intent: intent, dense: true),
            ],
          ),
          if (r.problem != null) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(r.problem!,
                style: text.bodySmall?.copyWith(
                    color: (r.ok ? t.status.warning : t.status.danger).fg)),
          ],
          if (r.ok) ...[
            const SizedBox(height: AppSpacing.x2),
            for (final (name, value) in rows)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.x1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 190,
                      child: Text(name, style: text.bodySmall?.copyWith(color: t.text.secondary)),
                    ),
                    Expanded(child: Text(value, style: AppTypography.tabular(text.bodySmall!))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static IconData _icon(String node) => switch (node) {
        'HUB' => Icons.hub_outlined,
        _ when node.startsWith('G') => Icons.door_sliding_outlined,
        _ => Icons.sensors,
      };

  static String _duration(Duration d) => switch (d) {
        Duration(inDays: > 0) => '${d.inDays} d ${d.inHours % 24} h',
        Duration(inHours: > 0) => '${d.inHours} h ${d.inMinutes % 60} min',
        Duration(inMinutes: > 0) => '${d.inMinutes} min',
        _ => '${d.inSeconds} s',
      };

  static String _resetLabel(String reason) => switch (reason) {
        'POWERON' => 'Powered on',
        'EXTERNAL' => 'Reset button',
        'SOFTWARE' => 'Restarted itself',
        'CRASH' => 'Crashed',
        'WATCHDOG' => 'Froze and was restarted',
        'BROWNOUT' => 'Power dip (brownout)',
        'DEEPSLEEP' => 'Woke from sleep',
        _ => 'Unknown',
      };

  static String _rc522Label(String version) => switch (version) {
        '00' || 'FF' => 'Not answering (0x$version): check its wiring',
        _ => 'OK (version 0x$version)',
      };

  static String _sensorsLabel(String board, String count, String? noEcho) {
    final mask = int.tryParse(noEcho ?? '', radix: 16) ?? 0;
    final silent = [for (var i = 0; i < 16; i++) if (mask & (1 << i) != 0) '$board/${i + 1}'];
    return silent.isEmpty
        ? 'All $count answering'
        : '${int.parse(count) - silent.length} of $count answering · no echo from ${silent.join(', ')}';
  }
}

/// Every line over the hub's USB cable, both ways, as it happens: what the
/// hub printed and what the server wrote back. For working out why a board
/// misbehaves without a laptop and a Serial Monitor.
class HubConsole extends ConsumerStatefulWidget {
  const HubConsole({super.key, required this.port});

  final String port;

  @override
  ConsumerState<HubConsole> createState() => _HubConsoleState();
}

class _HubConsoleState extends ConsumerState<HubConsole> {
  static const _refreshEvery = Duration(seconds: 1);
  static const _kept = 300;

  final _filter = TextEditingController();
  final _scroll = ScrollController();
  final List<HubTrafficLine> _lines = [];
  int _lastSeq = 0;
  Timer? _timer;
  bool _paused = false;
  bool _hideStatus = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_refreshEvery, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _filter.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_paused) return;
    try {
      final res = await ref.read(dioProvider).get(ApiEndpoints.hubTraffic(widget.port, _lastSeq));
      final fresh = [
        for (final l in (res.data as Map)['lines'] as List<dynamic>? ?? const [])
          HubTrafficLine.fromJson(l as Map<String, dynamic>),
      ];
      if (!mounted) return;
      // A restarted server counts from 1 again.
      if (fresh.isNotEmpty && fresh.first.seq <= _lastSeq) _lines.clear();
      if (fresh.isNotEmpty) _lastSeq = fresh.last.seq;
      final atBottom = !_scroll.hasClients || _scroll.offset >= _scroll.position.maxScrollExtent - 24;
      setState(() {
        _error = null;
        _lines.addAll(fresh);
        if (_lines.length > _kept) _lines.removeRange(0, _lines.length - _kept);
      });
      if (atBottom && fresh.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      setState(() => _error = data is Map ? '${data['message']}' : 'Could not reach the server.');
    }
  }

  /// The STATUS poll every 10 s and its echo of every board: true, but noise
  /// when looking for what just went wrong.
  static bool _isPolling(HubTrafficLine l) =>
      l.line == 'STATUS' ||
      l.line.startsWith('PAIRED ') ||
      RegExp(r'^[GS]\d+(/\d+)? (ONLINE|SLOT:)').hasMatch(l.line);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final mono = AppTypography.tabular(text.bodySmall!).copyWith(fontFamily: 'monospace');
    final filter = _filter.text.trim().toUpperCase();

    // A STATUS reply repeats every board's state in a burst right after it.
    // Only that burst is hidden, not a real change that looks the same.
    DateTime? lastStatus;
    final shown = <HubTrafficLine>[];
    for (final l in _lines) {
      if (l.out && l.line == 'STATUS') lastStatus = l.at;
      final burst = lastStatus != null && l.at.difference(lastStatus) < const Duration(seconds: 1);
      if (_hideStatus && _isPolling(l) && (l.line == 'STATUS' || burst)) continue;
      if (filter.isNotEmpty && !l.line.toUpperCase().contains(filter)) continue;
      shown.add(l);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _filter,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.filter_list, size: 18),
                  hintText: 'Filter, e.g. G1 or DIAG',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            FilterChip(
              label: const Text('Hide STATUS polling'),
              selected: _hideStatus,
              onSelected: (v) => setState(() => _hideStatus = v),
            ),
            const SizedBox(width: AppSpacing.x2),
            IconButton(
              tooltip: _paused ? 'Resume' : 'Pause',
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              onPressed: () => setState(() => _paused = !_paused),
            ),
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(_lines.clear),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(_error!, style: text.bodySmall?.copyWith(color: t.status.danger.fg)),
        ],
        const SizedBox(height: AppSpacing.x2),
        Container(
          height: 280,
          padding: const EdgeInsets.all(AppSpacing.x2),
          decoration: BoxDecoration(color: t.surface.muted, borderRadius: AppRadii.mdAll),
          child: shown.isEmpty
              ? Center(
                  child: Text(_lines.isEmpty ? 'Nothing over the cable yet.' : 'No lines match.',
                      style: text.bodySmall?.copyWith(color: t.text.secondary)),
                )
              : ListView.builder(
                  controller: _scroll,
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final l = shown[i];
                    return Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${DateFormat('HH:mm:ss').format(l.at.toLocal())}  ',
                          style: mono.copyWith(color: t.text.tertiary),
                        ),
                        TextSpan(
                          text: l.out ? '→ ' : '← ',
                          style: mono.copyWith(color: l.out ? t.status.info.fg : t.status.success.fg),
                        ),
                        TextSpan(text: l.line, style: mono),
                      ]),
                    );
                  },
                ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text('→ the server wrote it · ← the hub printed it. The last $_kept lines.',
            style: text.labelSmall?.copyWith(color: t.text.secondary)),
      ],
    );
  }
}
