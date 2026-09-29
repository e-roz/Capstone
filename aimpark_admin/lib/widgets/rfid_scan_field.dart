import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/web_serial.dart';
import '../models/rfid_scan.dart';
import '../providers/usb_reader_provider.dart';
import '../theme/theme.dart';

/// The RFID tag field in the Assign dialog, wired to the desk reader.
///
/// A UID typed by hand is the most common way a card ends up registered in a
/// form the gate will never match — one wrong character and the card is
/// silently unusable until someone thinks to compare the two strings. So the
/// admin taps the card instead and the field fills itself.
///
/// A tap arrives one of two ways. Normally the reader is plugged into this
/// computer and the browser reads it directly ([UsbReader]) — instant, and it
/// works with no bridge script. The older path, `bridge.py` relaying through
/// the cloud, is still polled so a desk set up that way keeps working.
///
/// The field stays editable on purpose. If the reader is unplugged or the
/// browser can't reach it, typing the printed ID still works, and the panel
/// says plainly which of these is happening.
class RfidScanField extends ConsumerStatefulWidget {
  const RfidScanField({
    super.key,
    required this.controller,
    this.userId,
  });

  /// Filled in when a card is tapped; also what the dialog reads on save.
  final TextEditingController controller;

  /// The user being assigned to, so a card already on *their* account reads as
  /// "already theirs" rather than as a clash. Null where there is no account
  /// to compare against — issuing a visitor pass, say — which just drops that
  /// one special case from the status line below.
  final String? userId;

  @override
  ConsumerState<RfidScanField> createState() => _RfidScanFieldState();
}

class _RfidScanFieldState extends ConsumerState<RfidScanField> {
  /// Fast enough to feel immediate at the desk, slow enough to be nothing on a
  /// LAN. The buffer holds a tap for two minutes, so nothing is missed between
  /// polls.
  static const _pollEvery = Duration(seconds: 1);

  /// Same rule as the API's `RfidTag.LooksValid`: hex, 6–32 characters.
  static final _validTag = RegExp(r'^[0-9A-F]{6,32}$');

  Timer? _timer;
  StreamSubscription<String>? _usbTaps;

  /// The scan that was already sitting in the buffer when the dialog opened.
  /// Ignored, so an unrelated tap from a minute ago cannot fill the field for a
  /// user the admin never meant to give it to.
  String? _baselineScanId;
  bool _baselineTaken = false;

  RfidScan? _scan;
  bool _readerReachable = true;

  /// A USB tap is in the field but the "who holds it" answer hasn't come back.
  bool _checking = false;

  /// The USB tap was read but the holder couldn't be looked up.
  bool _lookupFailed = false;

  @override
  void initState() {
    super.initState();
    _usbTaps = ref.read(usbReaderProvider).taps.listen(_onUsbTap);
    _poll();
    _timer = Timer.periodic(_pollEvery, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _usbTaps?.cancel();
    super.dispose();
  }

  Future<void> _onUsbTap(String raw) async {
    final reader = ref.read(usbReaderProvider);
    final tag = raw.replaceAll(RegExp(r'[:\-\s_]'), '').toUpperCase();

    if (!_validTag.hasMatch(tag)) {
      // A misread must never become the value one click away from saving.
      unawaited(reader.answer('ERROR'));
      return;
    }

    widget.controller.text = tag;
    setState(() {
      _scan = RfidScan(
        scanId: 'usb-${DateTime.now().microsecondsSinceEpoch}',
        rfidTagId: tag,
        scannedAt: DateTime.now(),
        deviceName: 'USB reader',
        isAssigned: false,
        assignedToUserId: null,
        assignedToName: null,
      );
      _checking = true;
      _lookupFailed = false;
    });

    try {
      final res = await ref
          .read(dioProvider)
          .get(ApiEndpoints.rfidLookup, queryParameters: {'tag': tag});
      final scan = RfidScan.fromJson(res.data as Map<String, dynamic>);
      unawaited(reader.answer(scan.isAssigned ? 'IN_USE' : 'FREE'));
      if (!mounted) return;
      setState(() {
        _scan = scan;
        _checking = false;
      });
    } catch (_) {
      // The card was read, which is all the beep reports. Whether someone
      // already holds it is the status line's job, and it says it couldn't
      // tell.
      unawaited(reader.answer('FREE'));
      if (!mounted) return;
      setState(() {
        _checking = false;
        _lookupFailed = true;
      });
    }
  }

  Future<void> _poll() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiEndpoints.rfidLastScan);
      if (!mounted) return;

      final data = res.data;
      final scan = data is Map<String, dynamic>
          ? RfidScan.fromJson(data)
          : null; // null body: nothing tapped recently.

      // The first reply only establishes what to ignore.
      if (!_baselineTaken) {
        setState(() {
          _baselineTaken = true;
          _baselineScanId = scan?.scanId;
          _readerReachable = true;
        });
        return;
      }

      if (scan == null || scan.scanId == _baselineScanId) {
        if (!_readerReachable) setState(() => _readerReachable = true);
        return;
      }

      setState(() {
        _scan = scan;
        _baselineScanId = scan.scanId;
        _readerReachable = true;
        _checking = false;
        _lookupFailed = false;
        widget.controller.text = scan.rfidTagId;
      });
    } on DioException {
      if (!mounted) return;
      // A poll failing is not worth a red banner on its own — the field still
      // works by hand — but the admin should know why nothing is arriving.
      if (_readerReachable) setState(() => _readerReachable = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usb = ref.watch(usbReaderProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusStrip(
          scan: _scan,
          userId: widget.userId,
          reachable: _readerReachable,
          checking: _checking,
          lookupFailed: _lookupFailed,
          usbStatus: usb.status,
          usbError: usb.error,
          onConnect: usb.connect,
        ),
        const SizedBox(height: AppSpacing.x4),
        TextFormField(
          controller: widget.controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'RFID Tag ID',
            helperText: 'Tap the card on the desk reader, or type the printed ID.',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Tag ID is required' : null,
        ),
      ],
    );
  }
}

/// The one line above the field that says what the reader is doing.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.scan,
    required this.userId,
    required this.reachable,
    required this.checking,
    required this.lookupFailed,
    required this.usbStatus,
    required this.usbError,
    required this.onConnect,
  });

  final RfidScan? scan;
  final String? userId;
  final bool reachable;
  final bool checking;
  final bool lookupFailed;
  final UsbReaderStatus usbStatus;
  final String? usbError;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (intent, icon, label) = _state();
    final colors = t.status.of(intent);

    // Offered only while nothing has been read yet: once a card is in the
    // field, the line is about that card.
    final showConnect =
        scan == null && usbStatus == UsbReaderStatus.disconnected;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.solid),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: colors.fg),
            ),
          ),
          if (showConnect) ...[
            const SizedBox(width: AppSpacing.x3),
            TextButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.usb, size: 16),
              label: const Text('Connect reader'),
            ),
          ],
        ],
      ),
    );
  }

  (StatusIntent, IconData, String) _state() {
    final s = scan;

    if (s != null) {
      if (checking) {
        return (
          StatusIntent.info,
          Icons.contactless,
          'Read ${s.rfidTagId} — checking whether it is already assigned…',
        );
      }

      if (lookupFailed) {
        return (
          StatusIntent.warning,
          Icons.cloud_off,
          'Read ${s.rfidTagId} — could not check whether someone already '
              'holds it. Saving will still work.',
        );
      }

      if (userId != null && s.isAssigned && s.assignedToUserId == userId) {
        return (
          StatusIntent.info,
          Icons.check_circle_outline,
          'Read ${s.rfidTagId} — this is already this user\'s card.',
        );
      }

      if (s.isAssigned) {
        return (
          StatusIntent.warning,
          Icons.warning_amber_rounded,
          'Read ${s.rfidTagId} — currently held by ${s.assignedToName}. '
              'Assigning moves the card off their account.',
        );
      }

      return (
        StatusIntent.success,
        Icons.check_circle,
        'Read ${s.rfidTagId} on ${s.deviceName} — not yet assigned.',
      );
    }

    switch (usbStatus) {
      case UsbReaderStatus.connected:
        return (
          StatusIntent.info,
          Icons.contactless,
          'USB reader connected — tap a card.',
        );
      case UsbReaderStatus.connecting:
        return (
          StatusIntent.info,
          Icons.usb,
          'Connecting to the USB reader…',
        );
      case UsbReaderStatus.disconnected when usbError != null:
        return (StatusIntent.warning, Icons.usb_off, usbError!);
      case UsbReaderStatus.disconnected:
        return (
          StatusIntent.info,
          Icons.usb,
          'Plug in the desk reader and connect it, or type the printed ID.',
        );
      case UsbReaderStatus.unsupported:
        if (!reachable) {
          return (
            StatusIntent.neutral,
            Icons.sensors_off,
            'Open this page in Chrome or Edge to use the USB reader, '
                'or type the printed ID.',
          );
        }
        return (
          StatusIntent.info,
          Icons.contactless,
          'Waiting for a card from the reader bridge. For the USB reader, '
              'use Chrome or Edge.',
        );
    }
  }
}
