import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/alert_sound.dart';
import '../core/utils/responsive.dart';
import '../models/gate_tap_event.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// Today's taps at the gates, newest first, as they happen.
///
/// Polls the site server once a second and asks only for what is newer than
/// the last tap it has, so a quiet gate costs almost nothing. A refused tap
/// shows red and beeps (once the guard has turned sound on — browsers need a
/// click first). [onNewTaps] lets the Overview refresh its counters and the
/// "inside right now" list when a car moves.
class LiveGateLog extends ConsumerStatefulWidget {
  const LiveGateLog({super.key, this.onNewTaps});

  final VoidCallback? onNewTaps;

  @override
  ConsumerState<LiveGateLog> createState() => _LiveGateLogState();
}

class _LiveGateLogState extends ConsumerState<LiveGateLog> {
  static const _refreshEvery = Duration(seconds: 1);

  /// The newest few only: a glance, not a history. Access Monitoring has the rest.
  static const _shown = 5;

  Timer? _timer;
  bool _inFlight = false;
  List<GateTapEvent>? _taps;
  String? _error;
  DateTime? _day;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_refreshEvery, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_inFlight) return;
    _inFlight = true;

    // Past midnight, start the day's list over.
    final today = DateUtils.dateOnly(DateTime.now());
    if (_day != today) {
      _day = today;
      _taps = null;
    }

    final newest = _taps?.isNotEmpty == true ? _taps!.first.at : null;
    try {
      final res = await ref
          .read(dioProvider)
          .get(
            ApiEndpoints.liveGateTaps,
            queryParameters: {
              if (newest != null) 'since': newest.toUtc().toIso8601String(),
            },
          );
      if (!mounted) return;

      final fresh = [
        for (final t in (res.data as Map)['taps'] as List? ?? const [])
          GateTapEvent.fromJson(t as Map<String, dynamic>),
      ];
      final known = {for (final t in _taps ?? const <GateTapEvent>[]) t.id};
      final added = fresh.where((t) => !known.contains(t.id)).toList();

      final firstLoad = _taps == null;
      setState(() {
        // First in, first out: the newest goes on top and anything past
        // [_shown] drops off the bottom.
        _taps = [...added, ...?_taps].take(_shown).toList();
        _error = null;
      });

      if (!firstLoad && added.isNotEmpty) {
        if (added.any((t) => !t.opened)) AlertSound.beep();
        widget.onNewTaps?.call();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      setState(() {
        _error = data is Map
            ? data['message']?.toString() ?? 'Could not load the gate log.'
            : 'Could not reach the server.';
      });
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final taps = _taps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live gate log',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'The last $_shown card taps, newest on top.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                ],
              ),
            ),
            const _SoundToggle(),
          ],
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (_error != null && taps == null)
          AppEmptyState(
            icon: Icons.sensors_off_outlined,
            title: 'Gate log unavailable',
            message: _error!,
          )
        else if (taps == null)
          const SkeletonList(count: 5)
        else if (taps.isEmpty)
          const AppEmptyState(
            icon: Icons.contactless_outlined,
            title: 'No taps yet today',
            message:
                'Each card tap at a gate will appear here the moment it happens.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final tap in taps)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                  child: _TapRow(tap: tap),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.go('/system-logs?tab=taps'),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('See all taps'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Browsers block sound until a click, so the guard turns it on here.
class _SoundToggle extends StatefulWidget {
  const _SoundToggle();

  @override
  State<_SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends State<_SoundToggle> {
  @override
  Widget build(BuildContext context) {
    final on = AlertSound.isOn;
    return Tooltip(
      message: on
          ? 'A refused tap beeps. Click to mute.'
          : 'Beep when a tap is refused. Browsers need one click to allow sound.',
      child: on
          ? OutlinedButton.icon(
              onPressed: () => setState(AlertSound.disable),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Sound on'),
            )
          : FilledButton.tonalIcon(
              onPressed: () => setState(AlertSound.enable),
              icon: const Icon(Icons.notifications_off_outlined, size: 18),
              label: Text(
                AlertSound.wanted
                    ? 'Turn sound back on'
                    : 'Turn on alert sound',
              ),
            ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({required this.tap});

  final GateTapEvent tap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final refused = !tap.opened;
    final tone = t.status.of(
      refused ? StatusIntent.danger : StatusIntent.success,
    );
    final text = Theme.of(context).textTheme;
    final compact = context.isCompact;

    // Each tap in its own bordered box, so rows never run into each other.
    return Material(
      color: refused ? tone.bg : t.surface.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdAll,
        side: BorderSide(color: refused ? tone.border : t.border.normal),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => TapDetailDialog(tap: tap),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact) ...[
                TapPhoto(tap: tap, width: 112, height: 84),
                const SizedBox(width: AppSpacing.x4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 08:38:35  [ENTRY DENIED]  Gate 1
                    Wrap(
                      spacing: AppSpacing.x2,
                      runSpacing: AppSpacing.x1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          DateFormat('HH:mm:ss').format(tap.at.toLocal()),
                          style: text.labelLarge?.copyWith(
                            fontFamily: 'IBM Plex Mono',
                          ),
                        ),
                        StatusPill(
                          label: tap.outcomeLabel,
                          intent: refused
                              ? StatusIntent.danger
                              : StatusIntent.success,
                          icon: refused ? Icons.block : Icons.check_circle,
                          showDot: false,
                        ),
                        Text(
                          'Gate ${tap.gate}',
                          style: text.labelLarge?.copyWith(
                            color: t.text.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tap.who,
                            style: text.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tap.isVisitor || tap.isDriver) ...[
                          const SizedBox(width: AppSpacing.x2),
                          StatusPill(
                            label: tap.isVisitor ? 'Visitor' : 'Driver',
                            intent: tap.isVisitor
                                ? StatusIntent.info
                                : StatusIntent.neutral,
                            dense: true,
                            showDot: false,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    for (final line in TapFacts.of(tap))
                      _FactLine(line: line, refused: refused),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One labelled fact about a tap, shared by the row and the detail dialog so
/// the two always word things the same way.
class TapFacts {
  const TapFacts(this.label, this.value, [this.intent]);

  final String label;
  final String value;

  /// Null for plain text; danger or success when the line is the verdict.
  final StatusIntent? intent;

  static List<TapFacts> of(GateTapEvent tap) {
    if (tap.isManual) return [TapFacts('What happened', tap.message)];

    return [
      if (tap.rfidTagId != null) TapFacts('Card UID', tap.rfidTagId!),
      TapFacts('Camera saw', tap.cameraPlate ?? 'No plate seen'),
      _plateOnFile(tap),
      TapFacts('Why', tap.message),
    ];
  }

  static TapFacts _plateOnFile(GateTapEvent tap) {
    if (tap.isUnknownCard) {
      return const TapFacts(
        'Plate on file',
        "None — this card isn't registered to anyone",
      );
    }
    final plates = tap.registeredPlates;
    if (plates == null) {
      return const TapFacts('Plate on file', 'None — no vehicle registered');
    }
    return switch (tap.plateMatches) {
      true => TapFacts(
        'Plate on file',
        '$plates  ✓ matches the camera',
        StatusIntent.success,
      ),
      false => TapFacts(
        'Plate on file',
        '$plates  ✗ does NOT match the camera',
        StatusIntent.danger,
      ),
      null => TapFacts('Plate on file', plates),
    };
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.line, required this.refused});

  final TapFacts line;
  final bool refused;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodySmall;
    final valueColor = line.intent != null
        ? t.status.of(line.intent!).fg
        : t.text.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              '${line.label}:',
              style: style?.copyWith(color: t.text.secondary),
            ),
          ),
          Expanded(
            child: Text(
              line.value,
              style: style?.copyWith(
                color: valueColor,
                fontWeight: line.intent != null ? FontWeight.w600 : null,
                fontFamily:
                    line.label == 'Card UID' ||
                        line.label == 'Camera saw' ||
                        line.label == 'Plate on file'
                    ? 'IBM Plex Mono'
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The photo kept for a tap, fetched once and remembered for the visit.
class TapPhoto extends ConsumerStatefulWidget {
  const TapPhoto({
    super.key,
    required this.tap,
    required this.width,
    required this.height,
  });

  final GateTapEvent tap;
  final double width;
  final double height;

  @override
  ConsumerState<TapPhoto> createState() => TapPhotoState();
}

class TapPhotoState extends ConsumerState<TapPhoto> {
  // Rows are rebuilt every second; without this each would refetch its photo.
  static final Map<String, Future<Uint8List?>> _cache = {};

  late Future<Uint8List?> _photo;

  @override
  void initState() {
    super.initState();
    _photo = widget.tap.hasPhoto
        ? _cache.putIfAbsent(widget.tap.id, _fetch)
        : Future.value(null);
  }

  Future<Uint8List?> _fetch() async {
    try {
      final res = await ref
          .read(dioProvider)
          .get<List<int>>(
            ApiEndpoints.liveGateTapPhoto(widget.tap.id),
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = res.data;
      return bytes == null ? null : Uint8List.fromList(bytes);
    } on DioException {
      _cache.remove(widget.tap.id);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: AppRadii.smAll,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: FutureBuilder<Uint8List?>(
          future: _photo,
          builder: (context, snap) {
            final bytes = snap.data;
            if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
            return Container(
              color: t.surface.muted,
              alignment: Alignment.center,
              child: snap.connectionState == ConnectionState.waiting
                  ? const SkeletonBone(
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Icon(Icons.no_photography_outlined, color: t.text.tertiary),
            );
          },
        ),
      ),
    );
  }
}

class TapDetailDialog extends StatelessWidget {
  const TapDetailDialog({super.key, required this.tap});

  final GateTapEvent tap;

  @override
  Widget build(BuildContext context) {
    final width = context.dialogWidth(560);
    final rows = <(String, String)>[
      ('Time', DateFormat('MMM d, HH:mm:ss').format(tap.at.toLocal())),
      ('Gate', ['Gate ${tap.gate}', ?tap.readerName].join(' · ')),
      ('What happened', tap.outcomeLabel),
      ('Barrier', tap.opened ? 'Opened' : 'Stayed shut'),
      ('Who', tap.who + (tap.isVisitor ? ' (visitor)' : '')),
      for (final f in TapFacts.of(tap)) (f.label, f.value),
    ];

    return AlertDialog(
      title: Text(tap.who),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tap.hasPhoto)
                TapPhoto(tap: tap, width: width, height: width * 3 / 4),
              const SizedBox(height: AppSpacing.x4),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.tokens.text.secondary),
                        ),
                      ),
                      Expanded(child: SelectableText(value)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
