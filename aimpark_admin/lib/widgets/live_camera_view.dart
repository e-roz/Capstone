import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// Every gate's live camera at once, side by side, for the guard's Overview.
///
/// One [LiveCameraView] per gate that has a camera registered. Until the list
/// loads (or if it can't), gate 1 still shows.
class LiveCameras extends ConsumerStatefulWidget {
  const LiveCameras({super.key});

  /// Below this each camera takes the full width, one under the other.
  static const double _sideBySideFrom = 520;

  @override
  ConsumerState<LiveCameras> createState() => _LiveCamerasState();
}

class _LiveCamerasState extends ConsumerState<LiveCameras> {
  List<int> _gates = const [1];

  @override
  void initState() {
    super.initState();
    _loadGates();
  }

  Future<void> _loadGates() async {
    try {
      final res = await ref.read(dioProvider).get(ApiEndpoints.liveGateCameras);
      final gates = [
        for (final g in (res.data as Map)['gates'] as List? ?? const [])
          ((g as Map)['gate'] as num).toInt(),
      ];
      if (!mounted || gates.isEmpty) return;
      setState(() => _gates = gates);
    } on DioException {
      // Gate 1 still shows; its own fetch reports what's wrong.
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final views = [
          for (final g in _gates) LiveCameraView(key: ValueKey(g), gate: g),
        ];
        if (views.length == 1) return views.single;

        if (constraints.maxWidth < LiveCameras._sideBySideFrom) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < views.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.gutter),
                views[i],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < views.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.gutter),
              Expanded(child: views[i]),
            ],
          ],
        );
      },
    );
  }
}

/// The live picture from one gate's ALPR camera.
///
/// The camera app sends a frame to the site server about 15 times a second; this
/// fetches the newest one on a timer and swaps it in without a flash. Fetched
/// through Dio rather than an `<img>` so the sign-in token goes with it.
class LiveCameraView extends ConsumerStatefulWidget {
  const LiveCameraView({super.key, required this.gate});

  final int gate;

  @override
  ConsumerState<LiveCameraView> createState() => _LiveCameraViewState();
}

class _LiveCameraViewState extends ConsumerState<LiveCameraView> {
  // A little faster than the camera app sends (~15 fps), so a new frame is
  // picked up soon after it lands; _inFlight stops requests piling up.
  static const _refreshEvery = Duration(milliseconds: 50);

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
            // Nothing to show: a short notice, not a big black box.
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.cardPadding,
                0,
                AppSpacing.cardPadding,
                AppSpacing.cardPadding,
              ),
              padding: const EdgeInsets.all(AppSpacing.x4),
              decoration: BoxDecoration(
                color: t.surface.muted,
                borderRadius: AppRadii.mdAll,
              ),
              child: Row(
                children: [
                  Icon(Icons.videocam_off_outlined, color: t.text.tertiary),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Text(
                      _error ??
                          'Camera offline — start the ALPR app on this PC and sign in.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ),
                ],
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
