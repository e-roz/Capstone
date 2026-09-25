/// A serial port on the guard PC, and the gate reader it is linked to if any.
class GateReaderPort {
  final String port;

  /// Windows' name for the device, e.g. "USB-SERIAL CH340" — how a guard
  /// tells the reader apart from COM1, which every PC has.
  final String? description;

  final String? deviceId;
  final bool connected;
  final String? error;
  final DateTime? lastTapAt;

  const GateReaderPort({
    required this.port,
    required this.description,
    required this.deviceId,
    required this.connected,
    required this.error,
    required this.lastTapAt,
  });

  bool get isLinked => deviceId != null;

  factory GateReaderPort.fromJson(Map<String, dynamic> json) => GateReaderPort(
        port: json['port']?.toString() ?? '',
        description: json['description']?.toString(),
        deviceId: json['deviceId']?.toString(),
        connected: json['connected'] as bool? ?? false,
        error: json['error']?.toString(),
        lastTapAt: json['lastTapAt'] == null
            ? null
            : DateTime.parse(json['lastTapAt'].toString()),
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

/// One card tap at a USB reader, or one manual open.
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

  const GateReaderTap({
    required this.at,
    required this.port,
    required this.reader,
    required this.rfidTagId,
    required this.direction,
    required this.opened,
    required this.message,
  });

  factory GateReaderTap.fromJson(Map<String, dynamic> json) => GateReaderTap(
        at: DateTime.parse(json['at'].toString()),
        port: json['port']?.toString() ?? '',
        reader: json['reader']?.toString(),
        rfidTagId: json['rfidTagId']?.toString(),
        direction: json['direction']?.toString() ?? '-',
        opened: json['opened'] as bool? ?? false,
        message: json['message']?.toString() ?? '',
      );
}

class GateReadersState {
  final List<GateReaderPort> ports;
  final List<LinkableReader> readers;
  final List<GateReaderTap> taps;

  const GateReadersState({
    required this.ports,
    required this.readers,
    required this.taps,
  });

  factory GateReadersState.fromJson(Map<String, dynamic> json) =>
      GateReadersState(
        ports: [
          for (final p in json['ports'] as List<dynamic>? ?? const [])
            GateReaderPort.fromJson(p as Map<String, dynamic>),
        ],
        readers: [
          for (final r in json['readers'] as List<dynamic>? ?? const [])
            LinkableReader.fromJson(r as Map<String, dynamic>),
        ],
        taps: [
          for (final t in json['taps'] as List<dynamic>? ?? const [])
            GateReaderTap.fromJson(t as Map<String, dynamic>),
        ],
      );
}
