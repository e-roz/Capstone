import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/alert_sound.dart';
import '../models/gate_reader.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// The Overview's header: is the cloud reachable, is the camera sending, is a
/// reader connected — and is the refusal beep on.
///
/// Checked every few seconds so a guard sees a camera or reader drop without
/// opening another screen. These answers come from the guard post's server;
/// opened from the cloud panel the checks are refused and the bar shows only
/// the sound toggle.
class GuardStatusBar extends ConsumerStatefulWidget {
  const GuardStatusBar({super.key});

  @override
  ConsumerState<GuardStatusBar> createState() => _GuardStatusBarState();
}

class _GuardStatusBarState extends ConsumerState<GuardStatusBar> {
  static const _refreshEvery = Duration(seconds: 5);

  Timer? _timer;
  bool _atGuardPost = true;
  bool? _cloud;
  bool? _camera;
  bool? _reader;

  /// The linked gates that are down, by name, for the Reader chip's tooltip.
  List<String> _readersDown = const [];

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(_refreshEvery, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final dio = ref.read(dioProvider);

    Future<T?> read<T>(String path, T? Function(dynamic) parse) async {
      try {
        return parse((await dio.get(path)).data);
      } on DioException catch (e) {
        // The cloud panel: these are the guard post's own endpoints.
        if (e.response?.statusCode == 400 || e.response?.statusCode == 404) {
          _atGuardPost = false;
        }
        return null;
      }
    }

    final results = await Future.wait([
      read<bool>(ApiEndpoints.siteStatus, (d) {
        // The cloud answers this too, as mode "Cloud": not the guard post.
        if ((d as Map)['mode'] != 'Site') {
          _atGuardPost = false;
          return null;
        }
        return d['cloudConnected'] == true;
      }),
      read<bool>(
        ApiEndpoints.liveGateCameras,
        (d) => ((d as Map)['gates'] as List? ?? const []).any(
          (g) => (g as Map)['live'] == true,
        ),
      ),
      read<bool>(ApiEndpoints.gateReaders, (d) {
        // USB readers and the wireless gates behind the hub alike: green
        // only when every linked barrier can take a card.
        final gates = GateReadersState.fromJson(
          d as Map<String, dynamic>,
        ).linkedGates;
        _readersDown = [for (final g in gates) if (!g.up) g.name];
        return gates.isNotEmpty && _readersDown.isEmpty;
      }),
    ]);

    if (!mounted) return;
    setState(() {
      _cloud = results[0];
      _camera = results[1];
      _reader = results[2];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_atGuardPost) ...[
          _Chip(
            label: 'Cloud',
            ok: _cloud,
            okTip: 'Connected to the cloud. Changes sync right away.',
            badTip:
                'No internet. The gates still work; records are sent when it is back.',
            badIntent: StatusIntent.warning,
          ),
          _Chip(
            label: 'Camera',
            ok: _camera,
            okTip: 'The ALPR camera is sending.',
            badTip:
                'No camera picture. Start the ALPR app on this PC and sign in.',
          ),
          _Chip(
            label: 'Reader',
            ok: _reader,
            okTip: 'Every gate reader is connected.',
            badTip: _readersDown.isEmpty
                ? 'No gate reader linked. Check the USB cable or the hub, then Gate → Gate Readers.'
                : 'Not answering: ${_readersDown.join(', ')}. See Devices below for what to check.',
          ),
        ],
        const SoundToggle(),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.ok,
    required this.okTip,
    required this.badTip,
    this.badIntent = StatusIntent.danger,
  });

  final String label;

  /// Null until the first check answers.
  final bool? ok;
  final String okTip;
  final String badTip;
  final StatusIntent badIntent;

  @override
  Widget build(BuildContext context) {
    final state = ok;
    return Tooltip(
      message: state == null ? 'Checking…' : (state ? okTip : badTip),
      child: StatusPill(
        label: label,
        intent: switch (state) {
          null => StatusIntent.neutral,
          true => StatusIntent.success,
          false => badIntent,
        },
        dense: true,
      ),
    );
  }
}

/// The refusal beep's on/off switch. Browsers block sound until a click, so
/// the guard turns it on here once per visit; while off it stays amber so it
/// gets noticed.
class SoundToggle extends StatefulWidget {
  const SoundToggle({super.key});

  @override
  State<SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends State<SoundToggle> {
  @override
  Widget build(BuildContext context) {
    final on = AlertSound.isOn;
    final warn = context.tokens.status.warning;

    return Tooltip(
      message: on
          ? 'A refused tap beeps. Click to mute.'
          : 'Beep when a tap is refused. Browsers need one click to allow sound.',
      child: on
          ? TextButton.icon(
              onPressed: () => setState(AlertSound.disable),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Sound on'),
            )
          : TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: warn.bg,
                foregroundColor: warn.fg,
              ),
              onPressed: () => setState(AlertSound.enable),
              icon: const Icon(Icons.notifications_off_outlined, size: 18),
              label: const Text('Sound off'),
            ),
    );
  }
}
