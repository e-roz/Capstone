import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/gate_reader.dart';
import '../theme/theme.dart';

/// The guard's manual override, on the Overview where it can't be missed.
///
/// The same action as Gate Readers → Open gate: asks which gate when there is
/// more than one reader connected, always asks "are you sure" so a stray
/// click doesn't let a car in, and lands on the live gate log as
/// "Opened by guard" with the guard's name.
class OpenGateButton extends ConsumerStatefulWidget {
  const OpenGateButton({super.key});

  @override
  ConsumerState<OpenGateButton> createState() => _OpenGateButtonState();
}

class _OpenGateButtonState extends ConsumerState<OpenGateButton> {
  bool _busy = false;

  Future<void> _press() async {
    setState(() => _busy = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiEndpoints.gateReaders);
      final state = GateReadersState.fromJson(res.data as Map<String, dynamic>);

      final gates = [
        for (final p in state.ports)
          if (p.connected && p.deviceId != null)
            (
              port: p.port,
              reader: state.readers
                  .where((r) => r.deviceId == p.deviceId)
                  .firstOrNull,
            ),
      ]..sort((a, b) => (a.reader?.gate ?? 0).compareTo(b.reader?.gate ?? 0));

      if (!mounted) return;
      if (gates.isEmpty) {
        _say('No gate reader is connected. Check Gate → Gate Readers.');
        return;
      }

      String nameOf(({String port, LinkableReader? reader}) g) =>
          g.reader == null ? g.port : 'Gate ${g.reader!.gate}';

      final chosen = await showDialog<({String port, LinkableReader? reader})>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            gates.length == 1
                ? 'Open ${nameOf(gates.single)} now?'
                : 'Open which gate?',
          ),
          content: Text(
            gates.length == 1
                ? 'The barrier opens for a few seconds. No card is checked and '
                      'no entry is logged. Use Gate check if the car needs a record.'
                : 'Pick the barrier to open. No card is checked and no entry '
                      'is logged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            for (final g in gates)
              FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop(g),
                icon: const Icon(Icons.lock_open, size: 18),
                label: Text(gates.length == 1 ? 'Open' : 'Open ${nameOf(g)}'),
              ),
          ],
        ),
      );
      if (chosen == null || !mounted) return;

      final opened = await dio.post(ApiEndpoints.openGateReader(chosen.port));
      _say((opened.data as Map?)?['message']?.toString() ?? 'Gate opened.');
    } on DioException catch (e) {
      final data = e.response?.data;
      _say(
        data is Map
            ? data['message']?.toString() ?? 'Could not open the gate.'
            : 'Could not reach the server.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final warn = context.tokens.status.warning;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: warn.solid,
        foregroundColor: Colors.black,
      ),
      onPressed: _busy ? null : _press,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.lock_open),
      label: const Text('Open gate'),
    );
  }
}
