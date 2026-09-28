import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// The live picture from a gate's ALPR camera, for the guard's Overview.
///
/// The camera app sends a frame to the site server a few times a second; this
/// fetches the newest one on a timer and swaps it in without a flash. Fetched
/// through Dio rather than an `<img>` so the sign-in token goes with it.
class LiveCameraView extends ConsumerStatefulWidget {
  const LiveCameraView({super.key});

  @override
  ConsumerState<LiveCameraView> createState() => _LiveCameraViewState();
}

class _LiveCameraViewState extends ConsumerState<LiveCameraView> {
  static const _refreshEvery = Duration(milliseconds: 250);

  Timer? _timer;
  bool _inFlight = false;

  List<int> _gates = const [];
  int _gate = 1;
  Uint8List? _frame;
  bool _offline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGates();
    _timer = Timer.periodic(_refreshEvery, (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadGates() async {
    try {
      final res = await ref.read(dioProvider).get(ApiEndpoints.liveGateCameras);
      final gates = [
        for (final g in (res.data as Map)['gates'] as List? ?? const [])
          (g as num).toInt(),
      ];
      if (!mounted || gates.isEmpty) return;
      setState(() {
        _gates = gates;
        if (!gates.contains(_gate)) _gate = gates.first;
      });
    } on DioException {
      // The picker is a nicety; gate 1 still shows.
    }
  }

  Future<void> _fetch() async {
    // A slow network must not pile requests up behind each other.
    if (_inFlight) return;
    _inFlight = true;
    try {
      final res = await ref
          .read(dioProvider)
          .get<List<int>>(
            ApiEndpoints.liveGateCamera(_gate),
            options: Options(responseType: ResponseType.bytes),
          );
      if (!mounted) return;
      final bytes = res.data;
      setState(() {
        _error = null;
        if (res.statusCode == 204 || bytes == null || bytes.isEmpty) {
          _offline = true;
        } else {
          _offline = false;
          _frame = Uint8List.fromList(bytes);
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      setState(() {
        _offline = true;
        // A byte body can't be read as a message; the status is enough.
        _error = data is Map
            ? data['message']?.toString()
            : 'Could not reach the camera feed.';
      });
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final live = !_offline && _frame != null;
    final badge = live ? t.status.success : t.status.danger;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.x3,
              AppSpacing.x3,
              AppSpacing.x3,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.videocam_outlined,
                  size: 18,
                  color: t.text.secondary,
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: _gates.length > 1
                      ? DropdownButton<int>(
                          value: _gate,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final g in _gates)
                              DropdownMenuItem(
                                value: g,
                                child: Text('Gate $g camera'),
                              ),
                          ],
                          onChanged: (g) => setState(() {
                            _gate = g ?? _gate;
                            _frame = null;
                          }),
                        )
                      : Text(
                          'Gate $_gate camera',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                ),
                StatusPill(
                  label: live ? 'Live' : 'Camera offline',
                  intent: live ? StatusIntent.success : StatusIntent.danger,
                  dense: true,
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: _frame != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          _frame!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                        if (!live)
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: Text(
                              'Last picture — the camera stopped sending.',
                              style: TextStyle(color: badge.bg),
                            ),
                          ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(AppSpacing.x6),
                      child: Text(
                        _error ??
                            'No picture yet. Start the ALPR app on this PC and '
                                'point it at http://localhost:5041.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
