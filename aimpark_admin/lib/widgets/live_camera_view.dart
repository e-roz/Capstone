import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// The live picture from one gate's ALPR camera, for the guard's Overview.
///
/// One of these per gate, side by side, so the guard watches both barriers at
/// once instead of switching between them. An offline camera keeps its 16:9
/// slot as a placeholder, so the other one never jumps around the screen.
///
/// The camera app sends a frame to the site server a few times a second; this
/// fetches the newest one on a timer and swaps it in without a flash. Fetched
/// through Dio rather than an `<img>` so the sign-in token goes with it.
class LiveCameraView extends ConsumerStatefulWidget {
  const LiveCameraView({super.key, required this.gate});

  final int gate;

  @override
  ConsumerState<LiveCameraView> createState() => _LiveCameraViewState();
}

class _LiveCameraViewState extends ConsumerState<LiveCameraView> {
  static const _refreshEvery = Duration(milliseconds: 250);

  Timer? _timer;
  bool _inFlight = false;

  Uint8List? _frame;
  bool _offline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_refreshEvery, (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    // A slow network must not pile requests up behind each other.
    if (_inFlight) return;
    _inFlight = true;
    try {
      final res = await ref
          .read(dioProvider)
          .get<List<int>>(
            ApiEndpoints.liveGateCamera(widget.gate),
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
                  child: Text(
                    'Gate ${widget.gate} camera',
                    overflow: TextOverflow.ellipsis,
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
          if (_frame == null)
            // Holds the picture's place, so both gates line up whether or
            // not their camera is on.
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: t.surface.muted,
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off_outlined, size: 32, color: t.text.tertiary),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      _error ??
                          'Gate ${widget.gate} camera offline — start the ALPR app for this gate and sign in.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ],
                ),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: Stack(
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}
