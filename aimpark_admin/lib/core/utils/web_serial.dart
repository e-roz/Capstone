import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// ── Web Serial bindings ──────────────────────────────────────────────────────
// package:web ships the stream and text types but not Web Serial itself, so
// the handful of members this file needs are declared here.

extension type _Serial._(JSObject _) implements web.EventTarget {
  external JSPromise<_SerialPort> requestPort([_RequestOptions options]);
  external JSPromise<JSArray<_SerialPort>> getPorts();
}

extension type _RequestOptions._(JSObject _) implements JSObject {
  external factory _RequestOptions({JSArray<_PortFilter> filters});
}

extension type _PortFilter._(JSObject _) implements JSObject {
  external factory _PortFilter({int usbVendorId});
}

extension type _SerialPort._(JSObject _) implements web.EventTarget {
  external JSPromise<JSAny?> open(_OpenOptions options);
  external JSPromise<JSAny?> close();
  external web.ReadableStream? get readable;
  external web.WritableStream? get writable;
}

extension type _OpenOptions._(JSObject _) implements JSObject {
  external factory _OpenOptions({int baudRate});
}

// ── Reader ───────────────────────────────────────────────────────────────────

enum UsbReaderStatus { unsupported, disconnected, connecting, connected }

/// The enrollment desk reader, read straight off USB by the browser.
///
/// The ESP32 firmware prints `UID:<hex>` for each tap and then waits for one
/// `RESULT:<value>` line to decide how to beep (see
/// `firmware/aimpark_enroll_reader`). `bridge.py` used to sit in the middle and
/// relay every tap through the cloud; Chrome and Edge can open the port
/// themselves, so a tap reaches the Assign dialog without leaving the desk.
///
/// Only one program can hold a serial port, so this and `bridge.py` (or the
/// Arduino Serial Monitor) cannot run against the same reader at once.
class UsbReader extends ChangeNotifier {
  UsbReader() {
    final serial = _serial;
    if (serial == null) {
      _status = UsbReaderStatus.unsupported;
      return;
    }

    // A reader already allowed on this computer comes back on its own when it
    // is plugged in again, with no picker.
    web.EventStreamProvider<web.Event>('connect').forTarget(serial).listen((e) {
      final port = e.target;
      if (port != null) _open(port as _SerialPort);
    });

    unawaited(_reconnectRemembered(serial));
  }

  /// USB-serial chips found on ESP32 boards: Silicon Labs CP210x, WCH CH340,
  /// FTDI, and Espressif's own USB. Keeps Bluetooth and modem ports out of the
  /// picker.
  static const _vendorIds = [0x10C4, 0x1A86, 0x0403, 0x303A];

  static _Serial? get _serial {
    final navigator = web.window.navigator as JSObject;
    if (!navigator.has('serial')) return null;
    return navigator.getProperty<JSObject?>('serial'.toJS) as _Serial?;
  }

  UsbReaderStatus _status = UsbReaderStatus.disconnected;
  UsbReaderStatus get status => _status;

  /// Why the last connect attempt failed, in words for the admin.
  String? _error;
  String? get error => _error;

  _SerialPort? _port;

  final _taps = StreamController<String>.broadcast();

  /// Each card tapped, as the raw UID the board printed. Whoever handles one
  /// must answer it with [answer].
  Stream<String> get taps => _taps.stream;

  /// True between a tap and its answer. The board reads exactly one RESULT
  /// line per tap; a second one would be taken as the answer to the next tap.
  bool _awaitingAnswer = false;

  Future<void> _writing = Future.value();

  /// Opens the browser's port picker. Must be called from a click.
  Future<void> connect() async {
    final serial = _serial;
    if (serial == null || _port != null) return;

    final _SerialPort port;
    try {
      port = await serial
          .requestPort(_RequestOptions(
            filters: [for (final id in _vendorIds) _PortFilter(usbVendorId: id)]
                .toJS,
          ))
          .toDart;
    } catch (_) {
      // Closing the picker without choosing lands here too — not an error.
      return;
    }
    await _open(port);
  }

  Future<void> _reconnectRemembered(_Serial serial) async {
    try {
      final ports = (await serial.getPorts().toDart).toDart;
      if (ports.isNotEmpty) await _open(ports.first);
    } catch (_) {
      // Nothing remembered, or the browser refused: the button still works.
    }
  }

  Future<void> _open(_SerialPort port) async {
    if (_port != null || _status == UsbReaderStatus.connecting) return;

    _status = UsbReaderStatus.connecting;
    _error = null;
    notifyListeners();

    try {
      await port.open(_OpenOptions(baudRate: 115200)).toDart;
    } catch (_) {
      _status = UsbReaderStatus.disconnected;
      _error = 'The reader is in use by another program. Close bridge.py, '
          'the Arduino Serial Monitor or another AimPark tab, then try again.';
      notifyListeners();
      return;
    }

    _port = port;
    _status = UsbReaderStatus.connected;
    notifyListeners();
    unawaited(_readLoop(port));
  }

  Future<void> _readLoop(_SerialPort port) async {
    final readable = port.readable;
    if (readable == null) return _closed(port);

    final reader = readable.getReader() as web.ReadableStreamDefaultReader;
    final decoder = web.TextDecoder();
    var pending = '';

    try {
      while (true) {
        final result = await reader.read().toDart;
        if (result.done) break;

        final chunk = result.value;
        if (chunk == null) continue;
        pending += decoder.decode(
          chunk as JSObject,
          web.TextDecodeOptions(stream: true),
        );

        var newline = pending.indexOf('\n');
        while (newline >= 0) {
          final line = pending.substring(0, newline).trim();
          pending = pending.substring(newline + 1);
          // Everything else is the board's startup banner or its own echo of
          // the result; opening the port resets it, so a banner is expected.
          if (line.startsWith('UID:')) _onUid(line.substring(4).trim());
          newline = pending.indexOf('\n');
        }
      }
    } catch (_) {
      // Unplugged mid-read. Handled below the same as a clean end.
    } finally {
      try {
        reader.releaseLock();
      } catch (_) {}
      await _closed(port);
    }
  }

  void _onUid(String uid) {
    if (uid.isEmpty) return;
    _awaitingAnswer = true;

    // No Assign dialog open: three beeps straight away, rather than the board
    // waiting a full minute for an answer nobody is going to give.
    if (!_taps.hasListener) {
      answer('ERROR');
      return;
    }
    _taps.add(uid);
  }

  /// Tells the board how the tap went: FREE (one beep), IN_USE (two) or
  /// anything else (three). Only the first answer per tap is sent.
  Future<void> answer(String result) {
    final port = _port;
    if (!_awaitingAnswer || port == null) return Future.value();
    _awaitingAnswer = false;

    // Chained so two answers can never ask for the writer at the same time.
    return _writing = _writing.then((_) async {
      final writable = port.writable;
      if (writable == null) return;
      final writer = writable.getWriter();
      try {
        await writer.write(web.TextEncoder().encode('RESULT:$result\n')).toDart;
      } catch (_) {
        // Unplugged between the tap and the answer; the read loop cleans up.
      } finally {
        writer.releaseLock();
      }
    });
  }

  Future<void> _closed(_SerialPort port) async {
    try {
      await _writing;
      await port.close().toDart;
    } catch (_) {}

    if (_port == port) _port = null;
    _awaitingAnswer = false;
    _status = UsbReaderStatus.disconnected;
    notifyListeners();
  }
}
