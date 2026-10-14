import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../models/gate_tap_event.dart';
import '../../models/parking_slot.dart';
import '../../providers/parking_provider.dart';
import '../../theme/theme.dart';

/// One big banner per gate, for the guard's Parking page and the screen it is
/// projected on: who just tapped in, "You can go", and the bay they were
/// recommended, large enough to read from across the room.
///
/// The bay is a recommendation, never an assignment: the driver may park in
/// another free bay of their kind, and that bay's sensor reports it. So the
/// banner names the bay but no plate, and nothing here records where anyone
/// parked.
///
/// A banner shows for [showFor] after its tap, or until the next tap at the
/// same gate replaces it. Below the banners: how many vehicles are inside, by
/// kind, against the bays for each.
///
/// Reads the guard post's live tap log, polled once a second like the
/// Overview's. Opened from the cloud panel, there is no live log and the
/// banners say so.
class GateEntryBanners extends ConsumerStatefulWidget {
  const GateEntryBanners({super.key});

  static const showFor = Duration(seconds: 15);

  @override
  ConsumerState<GateEntryBanners> createState() => _GateEntryBannersState();
}

class _GateEntryBannersState extends ConsumerState<GateEntryBanners> {
  static const _gates = [1, 2];
  static const _pollEvery = Duration(seconds: 1);

  Timer? _poll;
  bool _inFlight = false;
  bool _loadedOnce = false;
  DateTime? _newest;
  String? _unavailable;

  /// The tap on show at each gate, and when this screen first saw it. The
  /// countdown runs from then rather than from the server's clock.
  final Map<int, ({GateTapEvent tap, DateTime seenAt})> _shown = {};

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(_pollEvery, (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final res = await ref.read(dioProvider).get(
            ApiEndpoints.liveGateTaps,
            queryParameters: {
              if (_newest != null) 'since': _newest!.toUtc().toIso8601String(),
            },
          );
      if (!mounted) return;

      final taps = [
        for (final t in (res.data as Map)['taps'] as List? ?? const [])
          GateTapEvent.fromJson(t as Map<String, dynamic>),
      ]..sort((a, b) => a.at.compareTo(b.at));

      final now = DateTime.now();
      for (final tap in taps) {
        if (_newest == null || tap.at.isAfter(_newest!)) _newest = tap.at;

        // Entries only: a car leaving needs no bay, and a guard's manual
        // open has nobody to name.
        if (tap.direction != 'IN' || tap.isManual || !_gates.contains(tap.gate)) continue;

        // On opening the page, today's earlier taps are history, not news.
        if (!_loadedOnce && now.difference(tap.at.toLocal()) > GateEntryBanners.showFor) continue;

        _shown[tap.gate] = (tap: tap, seenAt: now);
      }

      _shown.removeWhere((_, s) => now.difference(s.seenAt) > GateEntryBanners.showFor);
      setState(() {
        _loadedOnce = true;
        _unavailable = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      setState(() {
        _unavailable = data is Map
            ? data['message']?.toString() ?? 'The live gate log is unavailable.'
            : 'Could not reach the guard post.';
      });
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = DateTime.now();

    Widget banner(int gate) {
      final shown = _shown[gate];
      if (shown == null) return _IdleBanner(gate: gate);
      final left = GateEntryBanners.showFor - now.difference(shown.seenAt);
      return _TapBanner(
        tap: shown.tap,
        remaining: (left.inMilliseconds / GateEntryBanners.showFor.inMilliseconds).clamp(0.0, 1.0),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final gate in _gates) ...[
                    if (gate != _gates.first) const SizedBox(height: AppSpacing.x3),
                    banner(gate),
                  ],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final gate in _gates) ...[
                    if (gate != _gates.first) const SizedBox(width: AppSpacing.x3),
                    Expanded(child: banner(gate)),
                  ],
                ],
              ),
            );
          },
        ),
        if (_unavailable != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            _unavailable!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.text.secondary),
          ),
        ],
        const SizedBox(height: AppSpacing.x3),
        const _InsideCounts(),
      ],
    );
  }
}

class _TapBanner extends StatelessWidget {
  const _TapBanner({required this.tap, required this.remaining});

  final GateTapEvent tap;

  /// 1 when the tap has just arrived, 0 when the banner is about to go.
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = tap.opened ? t.status.success : t.status.warning;
    final slot = tap.opened ? tap.recommendedSlot : null;

    final headline = tap.opened ? 'You can go' : 'Gate stays shut';
    final detail = !tap.opened
        ? tap.message
        : slot == null
            ? 'Park in any open bay.'
            : null;

    return Container(
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: c.border, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'GATE ${tap.gate} · ${DateFormat('h:mm a').format(tap.at.toLocal())}',
                  style: text.titleMedium?.copyWith(color: c.fg, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  tap.who,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineSmall?.copyWith(color: c.fg),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  headline,
                  style: text.displaySmall?.copyWith(color: c.fg, fontWeight: FontWeight.w800, fontSize: 48, height: 1.05),
                ),
                if (detail != null) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(detail, style: text.titleMedium?.copyWith(color: c.fg)),
                ],
                const SizedBox(height: AppSpacing.x4),
                ClipRRect(
                  borderRadius: AppRadii.smAll,
                  child: LinearProgressIndicator(
                    value: remaining,
                    minHeight: 6,
                    color: c.solid,
                    backgroundColor: t.surface.card,
                  ),
                ),
              ],
            ),
          ),
          if (slot != null) ...[
            const SizedBox(width: AppSpacing.x5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6, vertical: AppSpacing.x3),
              decoration: BoxDecoration(
                color: t.surface.card,
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: c.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RECOMMENDED',
                    style: text.titleSmall?.copyWith(color: t.text.secondary, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                  ),
                  Text(
                    slot,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 120,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      color: c.fg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IdleBanner extends StatelessWidget {
  const _IdleBanner({required this.gate});

  final int gate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: t.border.normal),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'GATE $gate',
            style: text.titleMedium?.copyWith(color: t.text.tertiary, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text('Waiting for a card tap', style: text.headlineSmall?.copyWith(color: t.text.tertiary)),
        ],
      ),
    );
  }
}

/// Vehicles inside, and by kind against the bays for that kind. Counted by
/// cards, the same way the gate decides whether there is room.
class _InsideCounts extends ConsumerWidget {
  const _InsideCounts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(parkingSlotsProvider).valueOrNull;

    String inside() => availability?.usersInside?.toString() ?? '—';

    // A bay with no signal or out of service is not counted as room, so the
    // vehicles of a kind are its working bays less the free ones.
    (String, String) ofKind(bool Function(ParkingSlot) kind, int? free) {
      if (availability == null || free == null) return ('—', '—');
      final bays = availability.slots.where(kind).where((s) => s.status != 'OutOfService');
      final working = bays.where((s) => s.status != 'NoSignal').length;
      return ('${(working - free).clamp(0, working)}', '${bays.length}');
    }

    final (cars, carBays) = ofKind((s) => s.vehicleType == 'Car', availability?.availableCars);
    final (bikes, bikeBays) = ofKind((s) => s.vehicleType == 'Motorcycle', availability?.availableMotorcycles);

    return Row(
      children: [
        Expanded(child: _Count(label: 'Inside now', icon: Icons.local_parking_outlined, value: inside())),
        const SizedBox(width: AppSpacing.x3),
        Expanded(child: _Count(label: 'Cars', icon: Icons.directions_car_outlined, value: cars, of: carBays)),
        const SizedBox(width: AppSpacing.x3),
        Expanded(child: _Count(label: 'Motorcycles', icon: Icons.two_wheeler_outlined, value: bikes, of: bikeBays)),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.icon, required this.value, this.of});

  final String label;
  final IconData icon;
  final String value;
  final String? of;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
      decoration: BoxDecoration(
        color: t.surface.card,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: t.border.subtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: t.text.secondary),
              const SizedBox(width: AppSpacing.x2),
              Text(label, style: text.titleSmall?.copyWith(color: t.text.secondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.x1),
          Text.rich(
            TextSpan(
              text: value,
              style: text.displaySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 40),
              children: [
                if (of != null)
                  TextSpan(
                    text: ' / $of',
                    style: text.titleLarge?.copyWith(color: t.text.tertiary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
