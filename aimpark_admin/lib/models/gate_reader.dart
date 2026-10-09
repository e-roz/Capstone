/// A serial port on the guard PC, and the gate reader it is linked to if any.
class GateReaderPort {
  final String port;

  /// Windows' name for the device, e.g. "USB-SERIAL CH340" — how a guard
  /// tells the reader apart from COM1, which every PC has.
  final String? description;

  /// "reader", "hub", or null when the port isn't linked.
  final String? kind;

  final String? deviceId;
  final bool connected;
  final String? error;
  final DateTime? lastTapAt;

  /// Linked as a reader, but the board printed the ESP-NOW hub's banner.
  final bool looksLikeHub;

  const GateReaderPort({
    required this.port,
    required this.description,
    required this.kind,
    required this.deviceId,
    required this.connected,
    required this.error,
    required this.lastTapAt,
    required this.looksLikeHub,
  });

  bool get isHub => kind == 'hub';
  bool get isLinked => kind != null;

  factory GateReaderPort.fromJson(Map<String, dynamic> json) => GateReaderPort(
        port: json['port']?.toString() ?? '',
        description: json['description']?.toString(),
        kind: json['kind']?.toString(),
        deviceId: json['deviceId']?.toString(),
        connected: json['connected'] as bool? ?? false,
        error: json['error']?.toString(),
        lastTapAt: json['lastTapAt'] == null
            ? null
            : DateTime.parse(json['lastTapAt'].toString()),
        looksLikeHub: json['looksLikeHub'] as bool? ?? false,
      );
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value.toString());

/// One board behind the ESP-NOW hub: a wireless gate (G1, G2), a sensor
/// board (S1, S2), or one sensor on a sensor board (S1/3).
class HubNode {
  final String node;

  /// "gate", "sensor", "sensorBoard", or null for a board this panel doesn't know.
  final String? kind;

  /// The reader a gate logs as, or the slot a sensor watches.
  final String? boundTo;

  /// Gates and sensor boards: the board's id (its MAC), once paired.
  final String? boardId;

  /// Gates: the gate it stands for by its name (G2 is gate 2) when no
  /// reader is chosen.
  final int? gate;
  final bool online;
  final DateTime? lastSeenAt;
  final DateTime? wentOfflineAt;

  /// "NOT_DELIVERED": an answer or an open didn't reach the board.
  final String? lastError;
  final DateTime? lastErrorAt;
  final DateTime? lastTapAt;

  /// Sensors: what it last saw. Null until the first reading.
  final bool? occupied;
  final int? distanceCm;

  /// Sensors: not answering (unplugged or broken), though its board is online.
  final bool fault;

  const HubNode({
    required this.node,
    required this.kind,
    required this.boundTo,
    required this.boardId,
    required this.gate,
    required this.online,
    required this.lastSeenAt,
    required this.wentOfflineAt,
    required this.lastError,
    required this.lastErrorAt,
    required this.lastTapAt,
    required this.occupied,
    required this.distanceCm,
    this.fault = false,
  });

  bool get isGate => kind == 'gate';

  /// One sensor on a sensor board, e.g. S1/3. Stands for a slot.
  bool get isSensor => kind == 'sensor';

  /// S1, S2: the board itself. Only online or not; its sensors are the slots.
  bool get isSensorBoard => kind == 'sensorBoard';

  /// Stands for something: a gate is linked by its name alone, a sensor
  /// once it has a slot.
  bool get isLinked => boundTo != null || (isGate && gate != null);

  factory HubNode.fromJson(Map<String, dynamic> json) => HubNode(
        node: json['node']?.toString() ?? '',
        kind: json['kind']?.toString(),
        boundTo: json['boundTo']?.toString(),
        boardId: json['boardId']?.toString(),
        gate: (json['gate'] as num?)?.toInt(),
        online: json['online'] as bool? ?? false,
        lastSeenAt: _date(json['lastSeenAt']),
        wentOfflineAt: _date(json['wentOfflineAt']),
        lastError: json['lastError']?.toString(),
        lastErrorAt: _date(json['lastErrorAt']),
        lastTapAt: _date(json['lastTapAt']),
        occupied: json['occupied'] as bool?,
        distanceCm: (json['distanceCm'] as num?)?.toInt(),
        fault: json['fault'] as bool? ?? false,
      );
}

/// A port linked as the ESP-NOW hub, and the boards behind it.
class HubPort {
  final String port;
  final bool connected;

  /// Connected and answering STATUS.
  final bool responding;

  /// The device on this port is another board, or never said it is the hub.
  final bool notTheHub;
  final String? error;
  final DateTime? lastSeenAt;

  /// Played by hand from this screen, in a development build.
  final bool simulated;
  final List<HubNode> nodes;

  /// Boards asking to join, to be accepted and named.
  final List<HubJoinRequest> requests;

  /// The last connection test of the hub ("HUB") and of each board ("G1"),
  /// since the server started.
  final Map<String, HubDiagnosis> diagnoses;

  const HubPort({
    required this.port,
    required this.connected,
    required this.responding,
    required this.error,
    required this.lastSeenAt,
    required this.simulated,
    required this.nodes,
    required this.requests,
    this.notTheHub = false,
    this.diagnoses = const {},
  });

  factory HubPort.fromJson(Map<String, dynamic> json) => HubPort(
        port: json['port']?.toString() ?? '',
        connected: json['connected'] as bool? ?? false,
        responding: json['responding'] as bool? ?? false,
        notTheHub: json['notTheHub'] as bool? ?? false,
        error: json['error']?.toString(),
        lastSeenAt: _date(json['lastSeenAt']),
        simulated: json['simulated'] as bool? ?? false,
        nodes: [
          for (final n in json['nodes'] as List<dynamic>? ?? const [])
            HubNode.fromJson(n as Map<String, dynamic>),
        ],
        requests: [
          for (final r in json['requests'] as List<dynamic>? ?? const [])
            HubJoinRequest.fromJson(r as Map<String, dynamic>),
        ],
        diagnoses: {
          for (final e in (json['diagnoses'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: HubDiagnosis.fromJson(e.value as Map<String, dynamic>),
        },
      );
}

/// One connection test: the hub over USB ("HUB"), or a board behind it
/// pinged over the air.
class HubDiagnosis {
  /// "HUB", or the board: "G1", "S2".
  final String node;
  final DateTime at;

  /// It answered.
  final bool ok;

  /// Server to board and back, USB included.
  final int roundTripMs;

  /// What the hub reported: rtt, rssi, noderssi, up, heap, reset, fails,
  /// packets, drops, rc522 (gates), sensors and noecho (sensor boards).
  final Map<String, String> values;

  /// Why it failed, or what needs a look though it answered.
  final String? problem;

  const HubDiagnosis({
    required this.node,
    required this.at,
    required this.ok,
    required this.roundTripMs,
    required this.values,
    required this.problem,
  });

  bool get isHub => node == 'HUB';

  /// Answered, with nothing to look at.
  bool get healthy => ok && problem == null;

  /// How loud the board is at the hub, dBm. Null when not known.
  int? get rssi => _dbm(values['rssi']);

  /// How loud the hub is at the board, dBm.
  int? get boardRssi => _dbm(values['noderssi']);

  /// Over the air only, as the hub timed it.
  int? get airMs => int.tryParse(values['rtt'] ?? '');

  Duration? get uptime {
    final s = int.tryParse(values['up'] ?? '');
    return s == null ? null : Duration(seconds: s);
  }

  static int? _dbm(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null || n == 0 ? null : n;
  }

  factory HubDiagnosis.fromJson(Map<String, dynamic> json) => HubDiagnosis(
        node: json['node']?.toString() ?? '',
        at: DateTime.parse(json['at'].toString()),
        ok: json['ok'] as bool? ?? false,
        roundTripMs: (json['roundTripMs'] as num?)?.toInt() ?? 0,
        values: {
          for (final e in (json['values'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: e.value.toString(),
        },
        problem: json['problem']?.toString(),
      );
}

/// One line over the hub's USB cable, for the hub console.
class HubTrafficLine {
  final int seq;
  final DateTime at;

  /// The server wrote it; otherwise the hub printed it.
  final bool out;
  final String line;

  const HubTrafficLine({required this.seq, required this.at, required this.out, required this.line});

  factory HubTrafficLine.fromJson(Map<String, dynamic> json) => HubTrafficLine(
        seq: (json['seq'] as num?)?.toInt() ?? 0,
        at: DateTime.parse(json['at'].toString()),
        out: json['out'] as bool? ?? false,
        line: json['line']?.toString() ?? '',
      );
}

/// How a guard should read a signal strength in dBm.
String signalLabel(int dbm) => switch (dbm) {
      >= -60 => 'Excellent',
      >= -70 => 'Good',
      >= -80 => 'Fair',
      _ => 'Weak',
    };

/// An unpaired board asking to join the hub.
class HubJoinRequest {
  /// Its MAC as 12 hex digits, as on its label.
  final String id;

  /// "gate" or "sensorBoard".
  final String kind;

  const HubJoinRequest({required this.id, required this.kind});

  bool get isGate => kind == 'gate';

  factory HubJoinRequest.fromJson(Map<String, dynamic> json) => HubJoinRequest(
        id: json['id']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
      );
}

/// A parking slot a sensor can watch.
class LinkableSlot {
  final String slotId;
  final String slotCode;
  final int gate;
  final String status;

  const LinkableSlot({
    required this.slotId,
    required this.slotCode,
    required this.gate,
    required this.status,
  });

  factory LinkableSlot.fromJson(Map<String, dynamic> json) => LinkableSlot(
        slotId: json['slotId']?.toString() ?? '',
        slotCode: json['slotCode']?.toString() ?? '',
        gate: (json['gate'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString() ?? '',
      );
}

/// An RFID reader registered in Gate Devices that a port can stand for.
class LinkableReader {
  final String deviceId;
  final String name;
  final int gate;

  const LinkableReader({
    required this.deviceId,
    required this.name,
    required this.gate,
  });

  factory LinkableReader.fromJson(Map<String, dynamic> json) => LinkableReader(
        deviceId: json['deviceId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        gate: (json['gate'] as num?)?.toInt() ?? 0,
      );
}

/// One card tap at a USB reader or a wireless gate, or one manual open.
class GateReaderTap {
  final DateTime at;
  final String port;
  final String? reader;
  final String? rfidTagId;

  /// "IN", "OUT", or "-" when it was neither (refused before it got that far,
  /// or opened by hand).
  final String direction;
  final bool opened;
  final String message;

  /// The wireless gate (G1, G2) it came from, when it came through the hub.
  final String? node;

  const GateReaderTap({
    required this.at,
    required this.port,
    required this.reader,
    required this.rfidTagId,
    required this.direction,
    required this.opened,
    required this.message,
    required this.node,
  });

  factory GateReaderTap.fromJson(Map<String, dynamic> json) => GateReaderTap(
        at: DateTime.parse(json['at'].toString()),
        port: json['port']?.toString() ?? '',
        reader: json['reader']?.toString(),
        rfidTagId: json['rfidTagId']?.toString(),
        direction: json['direction']?.toString() ?? '-',
        opened: json['opened'] as bool? ?? false,
        message: json['message']?.toString() ?? '',
        node: json['node']?.toString(),
      );
}

class GateReadersState {
  final List<GateReaderPort> ports;
  final List<HubPort> hubs;
  final List<LinkableReader> readers;
  final List<LinkableSlot> slots;
  final List<GateReaderTap> taps;

  /// A development server: the hub can be played from this screen.
  final bool canSimulate;

  const GateReadersState({
    required this.ports,
    required this.hubs,
    required this.readers,
    required this.slots,
    required this.taps,
    required this.canSimulate,
  });

  /// Every barrier the guard can open right now: a connected USB reader, or
  /// a wireless gate that is online and linked.
  List<OpenableGate> get openableGates => [
        for (final p in ports)
          if (!p.isHub && p.connected && p.deviceId != null)
            OpenableGate(port: p.port, node: null, reader: _reader(p.deviceId)),
        for (final h in hubs)
          for (final n in h.nodes)
            if (n.isGate && n.online && n.isLinked)
              OpenableGate(port: h.port, node: n.node, reader: _reader(n.boundTo), gate: n.gate),
      ]..sort((a, b) => (a.gateNumber ?? 0).compareTo(b.gateNumber ?? 0));

  /// Every barrier that is linked, up or not — for the Reader chip.
  List<({String name, bool up})> get linkedGates => [
        for (final p in ports)
          if (!p.isHub && p.deviceId != null)
            (name: _reader(p.deviceId)?.name ?? p.port, up: p.connected),
        for (final h in hubs)
          for (final n in h.nodes)
            if (n.isGate && n.isLinked)
              (
                name: n.boundTo == null
                    ? '${n.node} (Gate ${n.gate})'
                    : '${n.node} (${_reader(n.boundTo)?.name ?? 'reader'})',
                up: n.online,
              ),
      ];

  LinkableReader? _reader(String? id) =>
      readers.where((r) => r.deviceId == id).firstOrNull;

  factory GateReadersState.fromJson(Map<String, dynamic> json) =>
      GateReadersState(
        ports: [
          for (final p in json['ports'] as List<dynamic>? ?? const [])
            GateReaderPort.fromJson(p as Map<String, dynamic>),
        ],
        hubs: [
          for (final h in json['hubs'] as List<dynamic>? ?? const [])
            HubPort.fromJson(h as Map<String, dynamic>),
        ],
        readers: [
          for (final r in json['readers'] as List<dynamic>? ?? const [])
            LinkableReader.fromJson(r as Map<String, dynamic>),
        ],
        slots: [
          for (final s in json['slots'] as List<dynamic>? ?? const [])
            LinkableSlot.fromJson(s as Map<String, dynamic>),
        ],
        taps: [
          for (final t in json['taps'] as List<dynamic>? ?? const [])
            GateReaderTap.fromJson(t as Map<String, dynamic>),
        ],
        canSimulate: json['canSimulate'] as bool? ?? false,
      );
}

/// A barrier the Open gate button can open: a USB reader's port, or a
/// wireless gate behind the hub on that port.
class OpenableGate {
  final String port;

  /// G1, G2 — null for a USB reader.
  final String? node;
  final LinkableReader? reader;

  /// A wireless gate with no reader chosen: the gate in its name.
  final int? gate;

  const OpenableGate({required this.port, required this.node, required this.reader, this.gate});

  int? get gateNumber => reader?.gate ?? gate;

  String get name => gateNumber == null ? (node ?? port) : 'Gate $gateNumber';
}
