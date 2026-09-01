import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/rfid_scan.dart';
import '../theme/theme.dart';

/// The RFID tag field in the Assign dialog, wired to the desk reader.
///
/// A UID typed by hand is the most common way a card ends up registered in a
/// form the gate will never match — one wrong character and the card is
/// silently unusable until someone thinks to compare the two strings. So the
/// admin taps the card instead and the field fills itself.
///
/// The field stays editable on purpose. If the reader is unplugged, on another
/// network, or simply not built yet, typing the printed ID still works, and the
/// panel says plainly which of the two is happening.
class RfidScanField extends ConsumerStatefulWidget {
  const RfidScanField({
    super.key,
    required this.controller,
    required this.userId,
  });

  /// Filled in when a card is tapped; also what the dialog reads on save.
  final TextEditingController controller;

  /// The user being assigned to, so a card already on *their* account reads as
  /// "already theirs" rather than as a clash.
  final String userId;

  @override
  ConsumerState<RfidScanField> createState() => _RfidScanFieldState();
}

class _RfidScanFieldState extends ConsumerState<RfidScanField> {
  /// Fast enough to feel immediate at the desk, slow enough to be nothing on a
  /// LAN. The buffer holds a tap for two minutes, so nothing is missed between
  /// polls.
  static const _pollEvery = Duration(seconds: 1);

  Timer? _timer;

  /// The scan that was already sitting in the buffer when the dialog opened.
  /// Ignored, so an unrelated tap from a minute ago cannot fill the field for a
  /// user the admin never meant to give it to.
  String? _baselineScanId;
  bool _baselineTaken = false;

  RfidScan? _scan;
  bool _readerReachable = true;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(_pollEvery, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusStrip(
          scan: _scan,
          userId: widget.userId,
          reachable: _readerReachable,
          waiting: _scan == null,
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
    required this.waiting,
  });

  final RfidScan? scan;
  final String userId;
  final bool reachable;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (intent, icon, label) = _state();
    final colors = t.status.of(intent);

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
        ],
      ),
    );
  }

  (StatusIntent, IconData, String) _state() {
    if (!reachable) {
      return (
        StatusIntent.neutral,
        Icons.sensors_off,
        'Cannot reach the reader bridge. Type the printed ID instead.',
      );
    }

    final s = scan;
    if (s == null || waiting) {
      return (
        StatusIntent.info,
        Icons.contactless,
        'Waiting for a card — tap it on the reader.',
      );
    }

    if (s.isAssigned && s.assignedToUserId == userId) {
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
}
