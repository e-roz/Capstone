import 'package:aimpark_admin/models/device_health.dart';
import 'package:aimpark_admin/models/gate_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// The site server's answers, as JSON, for the hub at COM5 with G1 linked and
/// online, G2 linked but offline, and S1 watching a slot.
const _gateReaders = {
  'ports': [
    {'port': 'COM4', 'kind': 'reader', 'deviceId': 'r2', 'connected': true, 'looksLikeHub': false},
    {'port': 'COM5', 'kind': 'hub', 'connected': true, 'looksLikeHub': false},
    {'port': 'COM6', 'kind': null, 'connected': false},
  ],
  'hubs': [
    {
      'port': 'COM5',
      'connected': true,
      'responding': true,
      'nodes': [
        {'node': 'G1', 'kind': 'gate', 'boundTo': 'r1', 'online': true},
        {'node': 'G2', 'kind': 'gate', 'boundTo': 'r3', 'online': false},
        {'node': 'S1', 'kind': 'sensor', 'boundTo': 'slot-a', 'online': true, 'occupied': true, 'distanceCm': 7},
        {'node': 'S2', 'kind': 'sensor', 'online': true},
      ],
    },
  ],
  'readers': [
    {'deviceId': 'r1', 'name': 'Gate 1 Reader', 'gate': 1},
    {'deviceId': 'r2', 'name': 'Gate 2 USB', 'gate': 2},
    {'deviceId': 'r3', 'name': 'Gate 2 Reader', 'gate': 2},
  ],
  'slots': [
    {'slotId': 'slot-a', 'slotCode': 'A-01', 'gate': 1, 'status': 'Occupied'},
  ],
  'taps': [
    {'at': '2026-10-01T08:00:00Z', 'port': 'COM5', 'node': 'G1', 'direction': 'IN', 'opened': true, 'message': 'Welcome.'},
  ],
  'canSimulate': true,
};

void main() {
  group('GateReadersState', () {
    final state = GateReadersState.fromJson(_gateReaders);

    test('reads the hub and its boards', () {
      expect(state.hubs.single.nodes.map((n) => n.node), ['G1', 'G2', 'S1', 'S2']);
      final s1 = state.hubs.single.nodes.firstWhere((n) => n.node == 'S1');
      expect(s1.isSensor, isTrue);
      expect(s1.occupied, isTrue);
      expect(s1.distanceCm, 7);
      expect(state.ports.firstWhere((p) => p.port == 'COM5').isHub, isTrue);
      expect(state.ports.firstWhere((p) => p.port == 'COM6').isLinked, isFalse);
      expect(state.taps.single.node, 'G1');
      expect(state.canSimulate, isTrue);
    });

    test('offers to open the USB reader and the online wireless gate only', () {
      final gates = state.openableGates;
      expect(gates.map((g) => (g.port, g.node)), [('COM5', 'G1'), ('COM4', null)]);
      expect(gates.first.name, 'Gate 1');
    });

    test('the Reader chip names the linked gate that is down', () {
      final down = state.linkedGates.where((g) => !g.up).map((g) => g.name);
      expect(down, ['G2 (Gate 2 Reader)']);
    });
  });

  group('DeviceHealth', () {
    DeviceHealth device(Map<String, dynamic> json) =>
        DeviceHealth.fromJson({'id': 'x', 'name': 'x', 'kind': 'gateNode', ...json});

    test('tells up, down, troubled and unlinked apart', () {
      expect(device({'bound': true, 'online': true}).condition, DeviceCondition.ok);
      expect(device({'bound': true, 'online': false}).condition, DeviceCondition.down);
      expect(device({'bound': true, 'online': true, 'lastError': 'NOT_DELIVERED'}).condition,
          DeviceCondition.degraded);
      expect(device({'bound': false, 'online': false}).condition, DeviceCondition.unlinked);
      expect(device({'bound': false, 'online': true}).condition, DeviceCondition.unlinked);
    });

    test('finds the row a board depends on', () {
      final report = DeviceHealthReport.fromJson({
        'checkedAt': '2026-10-01T08:00:00Z',
        'devices': [
          {'id': 'hub:COM5', 'name': 'ESP-NOW hub', 'kind': 'hub', 'bound': true, 'online': false},
          {'id': 'node:COM5:G1', 'name': 'Wireless gate G1', 'kind': 'gateNode', 'bound': true,
            'online': false, 'dependsOn': 'hub:COM5'},
        ],
      });
      expect(report.byId(report.devices.last.dependsOn)?.kind, 'hub');
      expect(report.byId(null), isNull);
    });
  });
}
