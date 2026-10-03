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
import '../widgets/device_health_list.dart' show lastSeenLabel;
import '../widgets/hub_diagnostics.dart';
import '../widgets/ui/ui.dart';

/// The barrier readers plugged into the guard post's PC by USB, and the
/// ESP-NOW hub with the wireless gates and slot sensors behind it.
///
/// A guard picks which COM port is which gate's reader — or the hub — then
/// which reader each wireless gate logs as and which slot each sensor
/// watches. They see whether each is up, watch the taps come in, and can
/// open a gate by hand. There is no key to copy: the cable into the server is
/// what makes a reader, or the hub, trusted.
class GateReadersScreen extends ConsumerStatefulWidget {
  const GateReadersScreen({super.key});

  @override
  ConsumerState<GateReadersScreen> createState() => _GateReadersScreenState();
}

class _GateReadersScreenState extends ConsumerState<GateReadersScreen> {
  /// Taps should appear about as fast as the barrier moves.
  static const _refreshEvery = Duration(seconds: 2);

  /// The port dropdown's value for "this port is the hub".
  static const _hubChoice = '__hub__';

  /// The port a development build plays the hub on. Not a real COM port, so
  /// the server never fights the simulator for it.
  static const _simulatedPort = 'SIM1';

  Timer? _timer;
  GateReadersState? _state;
  String? _error;
  bool _busy = false;

  /// What is being tested right now: a hub's port, or "port/G1".
  String? _testing;

  /// Hubs whose console is open.
  final Set<String> _consoles = {};

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

  Future<void> _linkHub(String port) => _run(
        (dio) => dio.put(ApiEndpoints.gateReader(port), data: {'kind': 'hub'}),
      );

  Future<void> _unlink(String port) =>
      _run((dio) => dio.delete(ApiEndpoints.gateReader(port)));

  Future<void> _open(String port) =>
      _run((dio) => dio.post(ApiEndpoints.openGateReader(port)));

  Future<void> _linkNode(String port, HubNode node, String id) => _run(
        (dio) => dio.put(ApiEndpoints.hubNode(port, node.node),
            data: node.isGate ? {'deviceId': id} : {'slotId': id}),
      );

  Future<void> _unlinkNode(String port, String node) =>
      _run((dio) => dio.delete(ApiEndpoints.hubNode(port, node)));

  Future<void> _openNode(String port, String node) =>
      _run((dio) => dio.post(ApiEndpoints.openHubNode(port, node)));

  Future<void> _pair(String port, String id, String node) => _run(
        (dio) => dio.post(ApiEndpoints.pairHub(port), data: {'id': id, 'node': node}),
      );

  Future<void> _forget(String port, String node) =>
      _run((dio) => dio.delete(ApiEndpoints.hubBoard(port, node)));

  /// The connection test: the hub and every board behind it, or one board.
  /// Takes a few seconds per board that doesn't answer.
  Future<void> _diagnose(String port, {String? node}) async {
    setState(() => _testing = node == null ? port : '$port/$node');
    List<HubDiagnosis>? results;
    String? failure;
    try {
      final res = await ref.read(dioProvider).post(node == null
          ? ApiEndpoints.diagnoseHub(port)
          : ApiEndpoints.diagnoseHubNode(port, node));
      results = [
        for (final r in (res.data as Map)['results'] as List<dynamic>? ?? const [])
          HubDiagnosis.fromJson(r as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      failure = _messageOf(e);
    }
    if (!mounted) return;
    setState(() => _testing = null);
    if (results != null) {
      await showHubDiagnostics(context, results);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure ?? 'Error')));
    }
    await _load();
  }

  /// Accepting a board: the installer says what it is. A name already in use
  /// goes to the new board — how a broken one is replaced.
  Future<void> _accept(HubPort hub, HubJoinRequest request, GateReadersState s) async {
    final letter = request.isGate ? 'G' : 'S';
    String label(int n) => request.isGate ? 'Gate $n' : 'Sensor board $n';
    final taken = {for (final n in hub.nodes) if (n.boardId != null) n.node};

    // Only what the lot has: one gate board per gate with bays behind it, and
    // as many sensor boards (each watches one gate's bays).
    final gates = {for (final slot in s.slots) slot.gate}.where((g) => g >= 1).toList()..sort();
    final count = gates.isEmpty ? 2 : gates.last;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(request.isGate ? 'Which gate is this board at?' : 'Which sensor board is this?'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Board ${request.id}'),
          ),
          for (var n = 1; n <= count; n++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, '$letter$n'),
              child: Text(taken.contains('$letter$n')
                  ? '${label(n)} — replaces the board there now'
                  : label(n)),
            ),
        ],
      ),
    );
    if (name != null) await _pair(hub.port, request.id, name);
  }

  /// Links a sensor board's sensors to one gate's slots in order: sensor 1 to
  /// the first slot, and so on. Each one can still be changed after.
  Future<void> _fillInOrder(HubPort hub, HubNode board, GateReadersState s) async {
    final sensors = hub.nodes.where((o) => o.isSensor && o.node.startsWith('${board.node}/')).toList()
      ..sort((a, b) => _naturalCompare(a.node, b.node));
    final gates = {for (final slot in s.slots) slot.gate}.toList()..sort();

    final gate = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Which slots does ${board.node} watch?'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Sensor 1 gets the first slot, sensor 2 the next, and so on. '
                'You can change any of them after.'),
          ),
          for (final g in gates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, g),
              child: Text("Gate $g's slots"),
            ),
        ],
      ),
    );
    if (gate == null) return;

    final slots = s.slots.where((slot) => slot.gate == gate).toList()
      ..sort((a, b) => _naturalCompare(a.slotCode, b.slotCode));
    final pairs = [for (var i = 0; i < sensors.length && i < slots.length; i++) (sensors[i], slots[i])];

    await _run((dio) async {
      Response<dynamic>? last;
      for (final (sensor, slot) in pairs) {
        last = await dio.put(ApiEndpoints.hubNode(hub.port, sensor.node), data: {'slotId': slot.slotId});
      }
      return last ?? Response(requestOptions: RequestOptions(), data: {'message': 'Nothing to link yet.'});
    });
  }

  Future<void> _confirmForget(HubPort hub, HubNode n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${n.node}?'),
        content: Text(n.isGate
            ? 'This gate stops reading cards until another board is accepted as ${n.node}. '
                  'Use this when a board broke or is being replaced.'
            : 'Its slots stop following its sensors until another board is accepted as ${n.node}. '
                  'Use this when a board broke or is being replaced.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) await _forget(hub.port, n.node);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return AppPage(
      title: 'Gate Readers',
      subtitle: 'The card readers and the ESP-NOW hub plugged into this PC. '
          'Pick what each port is, then tap a card to try it.',
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
                      'one in Devices (type RFID Reader, gate 1 or higher), '
                      'then come back and link it to its port or wireless gate.',
                  action: TextButton(
                    onPressed: () => context.go('/gate-devices'),
                    child: const Text('Open Devices'),
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
              ],
              for (final p in s.ports.where((p) => p.looksLikeHub)) ...[
                _Banner(
                  text: '${p.port} is linked as a card reader, but the board on '
                      'it is the ESP-NOW hub. Link it as the hub so the wireless '
                      'gates and slot sensors work.',
                  action: TextButton(
                    onPressed: _busy ? null : () => _linkHub(p.port),
                    child: const Text('Link as hub'),
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
                        message: 'Plug the reader or hub in by USB. If nothing '
                            'appears, install its USB driver (CH340 or CP210x) '
                            'or try another cable.',
                      )
                    : AppDataTable(
                        minWidth: 820,
                        columns: const [
                          DataColumn(label: Text('Port')),
                          DataColumn(label: Text('Linked to')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Last tap')),
                          DataColumn(label: Text('')),
                        ],
                        rows: [for (final p in s.ports) _portRow(p, s)],
                      ),
              ),
              for (final hub in s.hubs) ...[
                const SizedBox(height: AppSpacing.x4),
                _hubSection(hub, s),
              ],
              if (s.canSimulate) ...[
                const SizedBox(height: AppSpacing.x4),
                _SimulatorCard(
                  hubs: s.hubs,
                  busy: _busy,
                  onAddHub: () => _linkHub(_simulatedPort),
                  onSent: _load,
                ),
              ],
              const SizedBox(height: AppSpacing.x4),
              AppSectionCard(
                title: 'Recent taps',
                subtitle: 'The last 50, newest first. Cleared when the server restarts.',
                icon: Icons.contactless_outlined,
                child: s.taps.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.contactless_outlined,
                        title: 'No taps yet',
                        message: 'Tap a card on a linked reader or wireless gate.',
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

  DataRow _portRow(GateReaderPort p, GateReadersState s) {
    final readers = s.readers;
    final hub = s.hubs.where((h) => h.port == p.port).firstOrNull;
    final known = readers.any((r) => r.deviceId == p.deviceId);

    final (label, intent) = switch (p) {
      GateReaderPort(isLinked: false) => ('Not linked', StatusIntent.neutral),
      GateReaderPort(isHub: true) when hub?.connected == true && hub?.responding == false =>
        ('Not answering', StatusIntent.warning),
      GateReaderPort(connected: true) => ('Connected', StatusIntent.success),
      _ => ('Disconnected', StatusIntent.danger),
    };

    return DataRow(cells: [
      DataCell(AppPrimaryCell(title: p.port, subtitle: p.description)),
      DataCell(
        DropdownButton<String>(
          value: p.isHub ? _hubChoice : (known ? p.deviceId : null),
          hint: Text(p.isLinked ? 'Reader no longer active' : 'Choose a reader or the hub'),
          underline: const SizedBox.shrink(),
          items: [
            for (final r in readers)
              DropdownMenuItem(
                value: r.deviceId,
                child: Text('${r.name} (Gate ${r.gate})'),
              ),
            const DropdownMenuItem(
              value: _hubChoice,
              child: Text('ESP-NOW hub (wireless gates and sensors)'),
            ),
          ],
          onChanged: _busy
              ? null
              : (id) {
                  if (id == _hubChoice && !p.isHub) {
                    _linkHub(p.port);
                  } else if (id != null && id != _hubChoice && id != p.deviceId) {
                    _link(p.port, id);
                  }
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
          if (p.isLinked && !p.isHub && p.connected)
            AppRowAction(
              label: 'Open gate',
              icon: Icons.lock_open,
              onPressed: _busy ? null : () => _confirmOpen(() => _open(p.port)),
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

  Widget _hubSection(HubPort hub, GateReadersState s) {
    // Boards, not the sensors on them: S1's nine slots are one board.
    final boards = hub.nodes.where((n) => !n.isSensor).toList();
    final online = boards.where((n) => n.online).length;
    final status = switch (hub) {
      HubPort(connected: false) => 'Not connected. Check the hub\'s USB cable.',
      HubPort(responding: false) =>
        'Connected but not answering. It restarts itself; if it keeps happening, unplug it and plug it back in.',
      _ => '$online of ${boards.length} boards online · heard from ${lastSeenLabel(hub.lastSeenAt)}',
    };

    final testing = _testing == hub.port;
    final consoleOpen = _consoles.contains(hub.port);

    return AppSectionCard(
      title: 'ESP-NOW hub on ${hub.port}${hub.simulated ? ' (simulated)' : ''}',
      subtitle: hub.error != null && hub.connected ? hub.error! : status,
      icon: Icons.hub_outlined,
      actions: [
        OutlinedButton.icon(
          onPressed: () => setState(() => consoleOpen ? _consoles.remove(hub.port) : _consoles.add(hub.port)),
          icon: const Icon(Icons.terminal, size: 18),
          label: Text(consoleOpen ? 'Hide console' : 'Console'),
        ),
        const SizedBox(width: AppSpacing.x2),
        FilledButton.tonalIcon(
          onPressed: _testing != null || !hub.connected ? null : () => _diagnose(hub.port),
          icon: testing
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.network_check, size: 18),
          label: Text(testing ? 'Testing…' : 'Test connection'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hub.requests.isNotEmpty) ...[
            _Banner(text: hub.requests.length == 1
                ? 'A new board is asking to join. Accept it and say what it is.'
                : '${hub.requests.length} new boards are asking to join. Accept each and say what it is.'),
            for (final r in hub.requests)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(r.isGate ? Icons.door_sliding_outlined : Icons.sensors),
                title: Text(r.isGate ? 'New gate board' : 'New sensor board'),
                subtitle: Text('Board ${r.id}'),
                trailing: FilledButton.icon(
                  onPressed: _busy ? null : () => _accept(hub, r, s),
                  icon: const Icon(Icons.check),
                  label: const Text('Accept'),
                ),
              ),
            const SizedBox(height: AppSpacing.x3),
          ],
          AppDataTable(
            minWidth: 1100,
            columns: const [
              DataColumn(label: Text('Board')),
              DataColumn(label: Text('Stands for')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Last seen')),
              DataColumn(label: Text('Reading')),
              DataColumn(label: Text('Last test')),
              DataColumn(label: Text('')),
            ],
            rows: [for (final n in hub.nodes) _nodeRow(hub, n, s)],
          ),
          if (consoleOpen) ...[
            const SizedBox(height: AppSpacing.x4),
            HubConsole(port: hub.port),
          ],
        ],
      ),
    );
  }

  /// A board's last connection test, or a sensor's board's. Tap to see it again.
  Widget _lastTestCell(HubPort hub, HubNode n) {
    if (n.isSensor) return const Text('—');
    final d = hub.diagnoses[n.node];
    if (d == null) return const Text('Not tested');
    final (label, intent) = diagnosisStatus(d);
    return InkWell(
      onTap: () => showHubDiagnostics(context, [d]),
      child: Tooltip(
        message: d.problem ?? 'Tested at ${DateFormat('HH:mm:ss').format(d.at.toLocal())}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusPill(label: label, intent: intent, dense: true),
            if (d.ok) ...[
              const SizedBox(width: AppSpacing.x2),
              Text(diagnosisSummary(d)),
            ],
          ],
        ),
      ),
    );
  }

  DataRow _nodeRow(HubPort hub, HubNode n, GateReadersState s) {
    final recentError = n.lastErrorAt != null &&
        DateTime.now().difference(n.lastErrorAt!.toLocal()) < const Duration(minutes: 10);

    final (label, intent) = switch (n) {
      HubNode(online: false) when !n.isLinked => ('Offline', StatusIntent.neutral),
      HubNode(online: false) => ('Offline', StatusIntent.danger),
      _ when recentError => ('Missed a message', StatusIntent.warning),
      _ => ('Online', StatusIntent.success),
    };

    final options = n.isGate
        ? [
            for (final r in s.readers)
              DropdownMenuItem(value: r.deviceId, child: Text('${r.name} (Gate ${r.gate})')),
          ]
        : n.isSensor
            ? [
                for (final slot in s.slots)
                  DropdownMenuItem(
                    value: slot.slotId,
                    child: Text('Slot ${slot.slotCode} (Gate ${slot.gate})'),
                  ),
              ]
            : <DropdownMenuItem<String>>[];
    final known = options.any((o) => o.value == n.boundTo);

    final sensorsOnBoard = n.isSensorBoard
        ? hub.nodes.where((o) => o.isSensor && o.node.startsWith('${n.node}/')).toList()
        : const <HubNode>[];

    final reading = switch (n) {
      HubNode(isSensor: true, occupied: true) => 'Vehicle at ${n.distanceCm ?? '?'} cm',
      HubNode(isSensor: true, occupied: false) => 'Empty',
      HubNode(isSensor: true) => 'No reading yet',
      HubNode(isSensorBoard: true) when sensorsOnBoard.isEmpty => 'No reading yet',
      HubNode(isSensorBoard: true) =>
        '${sensorsOnBoard.where((o) => o.occupied == true).length} of ${sensorsOnBoard.length} slots taken',
      HubNode(lastTapAt: final at?) => 'Last tap ${DateFormat('HH:mm:ss').format(at.toLocal())}',
      _ => '—',
    };

    return DataRow(cells: [
      DataCell(AppPrimaryCell(
        title: n.node,
        subtitle: [
          switch (n) {
            HubNode(isGate: true) => 'Wireless gate',
            HubNode(isSensor: true) => 'Slot sensor',
            HubNode(isSensorBoard: true) => 'Sensor board',
            _ => 'Unknown board',
          },
          ?n.boardId,
        ].join(' · '),
      )),
      if (n.isSensorBoard)
        DataCell(sensorsOnBoard.isEmpty
            ? const Text('Its sensors appear here once it reports')
            // Right where the installer is looking, not off the table's edge.
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${sensorsOnBoard.where((o) => o.boundTo != null).length} of '
                      '${sensorsOnBoard.length} linked'),
                  const SizedBox(width: AppSpacing.x2),
                  TextButton.icon(
                    onPressed: _busy || n.boardId == null ? null : () => _fillInOrder(hub, n, s),
                    icon: const Icon(Icons.format_list_numbered, size: 18),
                    label: const Text('Fill slots in order'),
                  ),
                ],
              ))
      else DataCell(
        DropdownButton<String>(
          value: known ? n.boundTo : null,
          hint: Text(n.boundTo != null
              ? (n.isGate ? 'Reader no longer active' : 'Slot no longer exists')
              : (n.isGate
                  ? (n.gate != null ? 'Gate ${n.gate}' : 'Choose a reader')
                  : 'Choose a slot')),
          underline: const SizedBox.shrink(),
          items: options,
          onChanged: _busy || options.isEmpty
              ? null
              : (id) {
                  if (id != null && id != n.boundTo) _linkNode(hub.port, n, id);
                },
        ),
      ),
      DataCell(Tooltip(
        message: recentError && n.lastError == 'NOT_DELIVERED'
            ? 'The last answer or open command didn\'t reach ${n.node}.'
            : (n.lastError ?? ''),
        child: StatusPill(label: label, intent: intent, dense: true),
      )),
      DataCell(Text(lastSeenLabel(n.lastSeenAt))),
      DataCell(Text(reading)),
      DataCell(_lastTestCell(hub, n)),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((n.isGate || n.isSensorBoard) && n.boardId != null)
            AppRowAction(
              label: _testing == '${hub.port}/${n.node}' ? 'Testing…' : 'Test',
              icon: Icons.network_check,
              onPressed: _testing != null || !hub.connected
                  ? null
                  : () => _diagnose(hub.port, node: n.node),
            ),
          if (n.isGate && n.online && n.isLinked)
            AppRowAction(
              label: 'Open gate',
              icon: Icons.lock_open,
              onPressed: _busy
                  ? null
                  : () => _confirmOpen(() => _openNode(hub.port, n.node)),
            ),
          if (n.boundTo != null)
            AppRowAction(
              label: n.isGate && n.gate != null ? 'Use Gate ${n.gate}' : 'Unlink',
              icon: Icons.link_off,
              intent: StatusIntent.danger,
              onPressed: _busy ? null : () => _unlinkNode(hub.port, n.node),
            ),
          if ((n.isGate || n.isSensorBoard) && n.boardId != null)
            AppRowAction(
              label: 'Remove',
              icon: Icons.delete_outline,
              intent: StatusIntent.danger,
              onPressed: _busy ? null : () => _confirmForget(hub, n),
            ),
        ],
      )),
    ]);
  }

  DataRow _tapRow(GateReaderTap t) {
    final reader = t.reader ?? t.port;
    return DataRow(cells: [
      DataCell(Text(DateFormat('HH:mm:ss').format(t.at.toLocal()))),
      DataCell(Text(t.node == null ? reader : '$reader · ${t.node}')),
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

  Future<void> _confirmOpen(Future<void> Function() open) async {
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
    if (confirmed == true) await open();
  }
}

/// Development servers only: plays the hub's side, one line at a time, so
/// the screens can be tried without the boards. Each line is exactly what
/// the hub would print over USB.
class _SimulatorCard extends ConsumerStatefulWidget {
  const _SimulatorCard({
    required this.hubs,
    required this.busy,
    required this.onAddHub,
    required this.onSent,
  });

  final List<HubPort> hubs;
  final bool busy;
  final VoidCallback onAddHub;
  final Future<void> Function() onSent;

  @override
  ConsumerState<_SimulatorCard> createState() => _SimulatorCardState();
}

class _SimulatorCardState extends ConsumerState<_SimulatorCard> {
  static const _presets = [
    'G1 ONLINE',
    'G2 ONLINE',
    'S1 ONLINE',
    'S2 ONLINE',
    'G1 UID:04A1B2C3',
    'S1/1 SLOT:OCCUPIED 3.7',
    'S1/1 SLOT:FREE 0.0',
    'S2/4 SLOT:OCCUPIED 2.4',
    'G2 ERR:NOT_DELIVERED',
    'DIAG HUB id=20500DCF8718 proto=3 up=120 heap=200 reset=POWERON channel=1 nodes=4 fails=0',
    'DIAG G1 rtt=12 rssi=-58 noderssi=-55 up=300 heap=180 reset=POWERON fails=0 packets=60 drops=0 rc522=92',
    'DIAG S1 rtt=35 rssi=-83 noderssi=-81 up=300 heap=190 reset=BROWNOUT fails=4 packets=60 drops=2 sensors=9 noecho=0020',
    'DIAG G2 FAIL NO_REPLY',
    'G1 OFFLINE',
    'S2 OFFLINE',
  ];

  final _line = TextEditingController();
  String? _port;
  List<String> _sent = const [];

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  Future<void> _send(String line) async {
    final port = _port ?? widget.hubs.firstOrNull?.port;
    if (port == null || line.trim().isEmpty) return;
    try {
      final res = await ref
          .read(dioProvider)
          .post(ApiEndpoints.simulateHub(port), data: {'line': line.trim()});
      final sent = (res.data as Map?)?['sent'] as List<dynamic>? ?? const [];
      if (!mounted) return;
      setState(() => _sent = [for (final l in sent) l.toString()]);
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data is Map ? '${data['message']}' : 'Could not send.'),
      ));
    }
    await widget.onSent();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final ports = [for (final h in widget.hubs) h.port];
    final port = ports.contains(_port) ? _port : ports.firstOrNull;

    return AppSectionCard(
      title: 'Hub simulator',
      subtitle: 'Development build only. Sends a line as if the hub had printed it.',
      icon: Icons.science_outlined,
      child: ports.isEmpty
          ? AppEmptyState(
              icon: Icons.hub_outlined,
              title: 'No hub linked',
              message: 'Link a port as the ESP-NOW hub, or add a simulated one.',
              action: FilledButton(
                onPressed: widget.busy ? null : widget.onAddHub,
                child: const Text('Add simulated hub'),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DropdownButton<String>(
                      value: port,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final p in ports) DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: (p) => setState(() => _port = p),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: TextField(
                        controller: _line,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'e.g. G1 UID:04A1B2C3',
                        ),
                        onSubmitted: _send,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    FilledButton(
                      onPressed: () => _send(_line.text),
                      child: const Text('Send'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    for (final line in _presets)
                      ActionChip(label: Text(line), onPressed: () => _send(line)),
                  ],
                ),
                if (_sent.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x3),
                  Text('The server wrote back, newest first:',
                      style: text.labelMedium?.copyWith(color: t.text.secondary)),
                  const SizedBox(height: AppSpacing.x1),
                  Text(_sent.take(8).join('\n'),
                      style: AppTypography.tabular(text.bodySmall!)
                          .copyWith(fontFamily: 'monospace')),
                ],
              ],
            ),
    );
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

/// "S1/10" after "S1/9", "M10" after "M9".
int _naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]);
    final nb = int.tryParse(pb[i]);
    final c = (na != null && nb != null) ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}
