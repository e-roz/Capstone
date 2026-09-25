import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/gate_reader.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

/// The barrier readers plugged into the guard post's PC by USB.
///
/// A guard picks which COM port is which gate's reader, sees whether each is
/// connected, watches the taps come in, and can open a gate by hand. There is
/// no key to copy: the cable into the server is what makes a reader trusted.
class GateReadersScreen extends ConsumerStatefulWidget {
  const GateReadersScreen({super.key});

  @override
  ConsumerState<GateReadersScreen> createState() => _GateReadersScreenState();
}

class _GateReadersScreenState extends ConsumerState<GateReadersScreen> {
  /// Taps should appear about as fast as the barrier moves.
  static const _refreshEvery = Duration(seconds: 2);

  Timer? _timer;
  GateReadersState? _state;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_refreshEvery, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(dioProvider).get(ApiEndpoints.gateReaders);
      if (!mounted) return;
      setState(() {
        _state = GateReadersState.fromJson(res.data as Map<String, dynamic>);
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageOf(e));
    }
  }

  String _messageOf(DioException e) {
    final data = e.response?.data;
    return data is Map
        ? data['message']?.toString() ?? e.message ?? 'Error'
        : e.message ?? 'Could not reach the server.';
  }

  Future<void> _run(Future<Response<dynamic>> Function(Dio dio) call) async {
    setState(() => _busy = true);
    String message;
    try {
      final res = await call(ref.read(dioProvider));
      message = (res.data as Map?)?['message']?.toString() ?? 'Done.';
    } on DioException catch (e) {
      message = _messageOf(e);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    await _load();
  }

  Future<void> _link(String port, String deviceId) => _run(
        (dio) => dio.put(ApiEndpoints.gateReader(port), data: {'deviceId': deviceId}),
      );

  Future<void> _unlink(String port) =>
      _run((dio) => dio.delete(ApiEndpoints.gateReader(port)));

  Future<void> _open(String port) =>
      _run((dio) => dio.post(ApiEndpoints.openGateReader(port)));

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return AppPage(
      title: 'Gate Readers',
      subtitle: 'The card readers plugged into this PC. Pick which reader each '
          'port is, then tap a card to try it.',
      scrollable: true,
      body: switch ((state, _error)) {
        (null, null) => const AppLoadingState(),
        (null, final error?) => AppErrorState(error: error, onRetry: _load),
        (final s?, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                _Banner(text: 'Lost contact with the server: $_error'),
                const SizedBox(height: AppSpacing.x3),
              ],
              if (s.readers.isEmpty) ...[
                _Banner(
                  text: 'No RFID reader is registered for a gate yet. Register '
                      'one in Gate Devices (type RFID Reader, gate 1 or higher), '
                      'then come back and link it to its port.',
                  action: TextButton(
                    onPressed: () => context.go('/gate-devices'),
                    child: const Text('Open Gate Devices'),
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
              ],
              AppSectionCard(
                title: 'Ports',
                subtitle: 'Refreshes every few seconds.',
                icon: Icons.usb,
                child: s.ports.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.usb_off,
                        title: 'No serial ports found',
                        message: 'Plug the reader in by USB. If nothing appears, '
                            'install its USB driver (CH340 or CP210x) or try '
                            'another cable.',
                      )
                    : AppDataTable(
                        minWidth: 820,
                        columns: const [
                          DataColumn(label: Text('Port')),
                          DataColumn(label: Text('Reader')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Last tap')),
                          DataColumn(label: Text('')),
                        ],
                        rows: [for (final p in s.ports) _portRow(p, s.readers)],
                      ),
              ),
              const SizedBox(height: AppSpacing.x4),
              AppSectionCard(
                title: 'Recent taps',
                subtitle: 'The last 50, newest first. Cleared when the server restarts.',
                icon: Icons.contactless_outlined,
                child: s.taps.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.contactless_outlined,
                        title: 'No taps yet',
                        message: 'Tap a card on a linked reader.',
                      )
                    : AppDataTable(
                        minWidth: 820,
                        columns: const [
                          DataColumn(label: Text('Time')),
                          DataColumn(label: Text('Reader')),
                          DataColumn(label: Text('Card')),
                          DataColumn(label: Text('In/Out')),
                          DataColumn(label: Text('Barrier')),
                          DataColumn(label: Text('Why')),
                        ],
                        rows: [for (final t in s.taps) _tapRow(t)],
                      ),
              ),
            ],
          ),
      },
    );
  }

  DataRow _portRow(GateReaderPort p, List<LinkableReader> readers) {
    final known = readers.any((r) => r.deviceId == p.deviceId);

    final (label, intent) = switch (p) {
      GateReaderPort(isLinked: false) => ('Not linked', StatusIntent.neutral),
      GateReaderPort(connected: true) => ('Connected', StatusIntent.success),
      _ => ('Disconnected', StatusIntent.danger),
    };

    return DataRow(cells: [
      DataCell(AppPrimaryCell(title: p.port, subtitle: p.description)),
      DataCell(
        DropdownButton<String>(
          value: known ? p.deviceId : null,
          hint: Text(p.isLinked ? 'Reader no longer active' : 'Choose a reader'),
          underline: const SizedBox.shrink(),
          items: [
            for (final r in readers)
              DropdownMenuItem(
                value: r.deviceId,
                child: Text('${r.name} (Gate ${r.gate})'),
              ),
          ],
          onChanged: _busy || readers.isEmpty
              ? null
              : (id) {
                  if (id != null && id != p.deviceId) _link(p.port, id);
                },
        ),
      ),
      DataCell(Tooltip(
        message: p.error ?? '',
        child: StatusPill(label: label, intent: intent, dense: true),
      )),
      DataCell(Text(p.lastTapAt == null
          ? '—'
          : DateFormat('HH:mm:ss').format(p.lastTapAt!.toLocal()))),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.isLinked && p.connected)
            AppRowAction(
              label: 'Open gate',
              icon: Icons.lock_open,
              onPressed: _busy ? null : () => _confirmOpen(p.port),
            ),
          if (p.isLinked)
            AppRowAction(
              label: 'Unlink',
              icon: Icons.link_off,
              intent: StatusIntent.danger,
              onPressed: _busy ? null : () => _unlink(p.port),
            ),
        ],
      )),
    ]);
  }

  DataRow _tapRow(GateReaderTap t) {
    return DataRow(cells: [
      DataCell(Text(DateFormat('HH:mm:ss').format(t.at.toLocal()))),
      DataCell(Text(t.reader ?? t.port)),
      DataCell(Text(t.rfidTagId ?? '—')),
      DataCell(Text(switch (t.direction) {
        'IN' => 'Entry',
        'OUT' => 'Exit',
        _ => '—',
      })),
      DataCell(StatusPill(
        label: t.opened ? 'Opened' : 'Stayed shut',
        intent: t.opened ? StatusIntent.success : StatusIntent.danger,
        dense: true,
      )),
      DataCell(Text(t.message)),
    ]);
  }

  Future<void> _confirmOpen(String port) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open the gate by hand?'),
        content: const Text(
          'The barrier opens without a card, and nothing is logged as an entry '
          'or exit. Use Gate Check to log the car if it needs one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open gate'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _open(port);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tone = context.tokens.status.warning;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(color: tone.bg, borderRadius: AppRadii.mdAll),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: tone.fg, size: AppSizes.iconSm),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tone.fg)),
          ),
          ?action,
        ],
      ),
    );
  }
}
