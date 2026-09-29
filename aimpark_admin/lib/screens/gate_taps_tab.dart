import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/csv_export.dart';
import '../models/gate_tap_event.dart';
import '../theme/theme.dart';
import '../widgets/live_gate_log.dart';
import '../widgets/ui/ui.dart';

/// Access Monitoring's "Gate taps" tab: every tap at a gate reader, newest
/// first — entered, exited, denied, and opened by a guard.
///
/// RFID Access lists only real entries and exits, so a card that was turned
/// away never appears there. This is where the refusals are. The taps are
/// kept on the guard post's server, so the tab only fills in on its panel.
class GateTapsTab extends ConsumerStatefulWidget {
  const GateTapsTab({super.key});

  @override
  ConsumerState<GateTapsTab> createState() => _GateTapsTabState();
}

class _GateTapsTabState extends ConsumerState<GateTapsTab> {
  static const _pageSize = 25;
  static final _stamp = DateFormat('MMM d, yyyy HH:mm:ss');

  int _page = 1;
  int _total = 0;
  List<GateTapEvent>? _taps;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await ref
          .read(dioProvider)
          .get(
            ApiEndpoints.liveGateHistory,
            queryParameters: {'page': _page, 'pageSize': _pageSize},
          );
      final data = res.data as Map;
      if (!mounted) return;
      setState(() {
        _total = (data['totalCount'] as num?)?.toInt() ?? 0;
        _taps = [
          for (final t in data['taps'] as List? ?? const [])
            GateTapEvent.fromJson(t as Map<String, dynamic>),
        ];
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      setState(() {
        _error = data is Map
            ? data['message']?.toString() ?? 'Could not load the gate taps.'
            : 'Could not reach the server.';
      });
    }
  }

  void _goTo(int page) {
    _page = page;
    _load();
  }

  void _export() {
    final taps = _taps ?? const <GateTapEvent>[];
    CsvExport.save(
      fileName:
          'aimpark-gate-taps-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.csv',
      headers: const [
        'Time',
        'Gate',
        'What happened',
        'Who',
        'Card UID',
        'Camera saw',
        'Plate on file',
        'Plates match',
        'Why',
      ],
      rows: [
        for (final t in taps)
          [
            DateFormat('yyyy-MM-dd HH:mm:ss').format(t.at.toLocal()),
            '${t.gate}',
            t.outcomeLabel,
            t.who,
            t.rfidTagId ?? '',
            t.cameraPlate ?? '',
            t.registeredPlates ?? '',
            switch (t.plateMatches) {
              true => 'Yes',
              false => 'No',
              null => '',
            },
            t.message,
          ],
      ],
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Log exported.')));
  }

  @override
  Widget build(BuildContext context) {
    final taps = _taps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppToolbar(
          trailing: [
            OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined, size: AppSizes.iconSm),
              label: const Text('Export CSV'),
              onPressed: taps == null ? null : _export,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _load,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.headingGap),
        Expanded(
          child: _error != null
              ? AppEmptyState(
                  icon: Icons.sensors_off_outlined,
                  title: 'Gate taps unavailable',
                  message: _error,
                )
              : taps == null
              ? const SkeletonTable(
                  columns: 6,
                  columnWidths: [150, 70, 140, 180, 200, 240],
                )
              : taps.isEmpty
              ? const AppEmptyState(
                  icon: Icons.contactless_outlined,
                  title: 'No taps yet',
                  message:
                      'Every card tap at a gate — let in, turned away, or opened '
                      'by a guard — is listed here.',
                )
              : AppDataTable(
                  minWidth: 1100,
                  columns: const [
                    DataColumn(label: Text('Time')),
                    DataColumn(label: Text('Gate')),
                    DataColumn(label: Text('What happened')),
                    DataColumn(label: Text('Who')),
                    DataColumn(label: Text('Camera saw / Plate on file')),
                    DataColumn(label: Text('Why')),
                  ],
                  rows: [for (final t in taps) _row(context, t)],
                  footer: AppPagination(
                    page: _page,
                    pageSize: _pageSize,
                    total: _total,
                    itemLabel: 'gate taps',
                    onPage: _goTo,
                  ),
                ),
        ),
      ],
    );
  }

  DataRow _row(BuildContext context, GateTapEvent tap) {
    final text = Theme.of(context).textTheme;
    final t = context.tokens;
    void open() => showDialog<void>(
      context: context,
      builder: (_) => TapDetailDialog(tap: tap),
    );

    final plateIntent = switch (tap.plateMatches) {
      true => StatusIntent.success,
      false => StatusIntent.danger,
      null => StatusIntent.neutral,
    };

    return DataRow(
      cells: [
        DataCell(
          Text(_stamp.format(tap.at.toLocal()), style: text.bodySmall),
          onTap: open,
        ),
        DataCell(Text('Gate ${tap.gate}'), onTap: open),
        DataCell(
          StatusPill(
            label: tap.outcomeLabel,
            intent: tap.opened ? StatusIntent.success : StatusIntent.danger,
            icon: tap.opened ? Icons.check_circle : Icons.block,
            showDot: false,
            dense: true,
          ),
          onTap: open,
        ),
        DataCell(
          AppPrimaryCell(
            title: tap.who,
            subtitle: tap.rfidTagId == null
                ? null
                : 'Card UID ${tap.rfidTagId}',
          ),
          onTap: open,
        ),
        DataCell(
          tap.isManual
              ? Text(
                  '—',
                  style: text.bodyMedium?.copyWith(color: t.text.tertiary),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Camera: ${tap.cameraPlate ?? 'no plate seen'}',
                      style: text.bodySmall,
                    ),
                    Text(
                      'On file: ${tap.isUnknownCard ? 'card not registered' : tap.registeredPlates ?? 'none'}',
                      style: text.bodySmall?.copyWith(
                        color: plateIntent == StatusIntent.neutral
                            ? t.text.secondary
                            : t.status.of(plateIntent).fg,
                        fontWeight: plateIntent == StatusIntent.neutral
                            ? null
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
          onTap: open,
        ),
        DataCell(
          SizedBox(
            width: 280,
            child: Text(
              tap.message,
              style: text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onTap: open,
        ),
      ],
    );
  }
}
