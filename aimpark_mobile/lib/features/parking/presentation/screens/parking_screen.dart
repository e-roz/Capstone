import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../data/models/parking_history_entry.dart';
import '../../data/models/parking_slot.dart';
import '../providers/parking_history_provider.dart';
import '../widgets/availability_freshness.dart';

/// The Parking tab: how full the lot is right now, and whether you are in it.
///
/// New in the redesign. The tab it replaced was Parking *history* — a list of
/// finished sessions — which answered a question nobody opens a parking app to
/// ask. History moved to a row under Account; this answers "can I park, and
/// where am I parked".
class ParkingScreen extends ConsumerWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availabilityAsync = ref.watch(parkingAvailabilityNotifierProvider);
    final current =
        ref.watch(parkingHistoryNotifierProvider).valueOrNull?.currentlyParked;

    Future<void> refresh() async {
      ref.invalidate(parkingAvailabilityNotifierProvider);
      await Future.wait([
        ref.read(parkingAvailabilityNotifierProvider.future),
        ref.read(parkingHistoryNotifierProvider.notifier).refresh(),
      ]);
    }

    return AppScreen.tab(
      body: AsyncView(
        value: availabilityAsync,
        onRefresh: refresh,
        errorTitle: "Couldn't load availability",
        loading: const Padding(
          padding: kScreenListPadding,
          child: _AvailabilitySkeleton(),
        ),
        data: (availability) => ListView(
          padding: kScreenListPadding,
          children: [
            const AppScreenTitle(title: 'Parking'),
            _AvailabilityCard(availability: availability, onRefresh: refresh),
            if (availability.isLotFull) ...[
              const SizedBox(height: AppSpacing.gutter),
              // Someone already parked has no use for a free bay.
              _LotFullCard(canWatch: current == null),
            ],
            if (current != null) ...[
              const SizedBox(height: AppSpacing.gutter),
              _CurrentSessionCard(entry: current, availability: availability),
            ],
            if (!availability.isLotFull) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Browse slots',
                onPressed: () => context.push('/home/user/parking-slots'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.availability, required this.onRefresh});

  final ParkingAvailability availability;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final freshness = AvailabilityFreshness.of(availability.fetchedAt);
    final c = t.status.of(freshness.intent);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      // The card's own border carries the warning too, so a stale count reads
      // as suspect before you have got as far as the chip.
      borderColor: freshness == AvailabilityFreshness.stale ? c.border : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AVAILABILITY', style: context.text.labelSmall),
                    const SizedBox(height: 6),
                    Text(
                      '${availability.availableSlots}',
                      style: AppTypography.tabular(context.text.displayLarge!),
                    ),
                    Text(
                      'of ${availability.totalSlots} slots free',
                      style: context.text.bodyMedium
                          ?.copyWith(color: t.text.secondary),
                    ),
                  ],
                ),
              ),
              _RefreshButton(onRefresh: onRefresh),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          AppStatusBadge(
            label: freshness.label(availability.fetchedAt),
            intent: freshness.intent,
            showDot: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, thickness: 1, color: t.border.subtle),
          const SizedBox(height: AppSpacing.sm + 4),
          Row(
            children: [
              Expanded(
                child: _Split(label: 'CARS', value: availability.freeCars),
              ),
              Container(width: 1, height: 32, color: t.border.subtle),
              Expanded(
                child: _Split(
                  label: 'MOTORCYCLES',
                  value: availability.freeMotorcycles,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.labelSmall),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: AppTypography.tabular(context.text.titleMedium!),
          ),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_spin.isAnimating) return;
    _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      // Guarded: the tab can be disposed mid-request, and touching a disposed
      // controller throws.
      if (mounted) {
        _spin.stop();
        _spin.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      button: true,
      label: 'Refresh availability',
      child: InkWell(
        onTap: _run,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.border.normal),
          ),
          child: RotationTransition(
            turns: _spin,
            child: Icon(
              Icons.refresh_rounded,
              size: AppSizes.iconMd,
              color: t.brand.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LotFullCard extends ConsumerStatefulWidget {
  const _LotFullCard({required this.canWatch});

  /// False while this user is parked inside, where "tell me when a slot
  /// opens" would only buzz them about a bay they do not need.
  final bool canWatch;

  @override
  ConsumerState<_LotFullCard> createState() => _LotFullCardState();
}

/// "Notify me when a slot opens" lives here, on the one screen that shows the
/// lot is full.
///
/// It replaced a push that told every user the lot had filled and every user
/// again when a bay came free — including everyone already parked and everyone
/// not coming in. Now only the people who asked hear about it, once.
class _LotFullCardState extends ConsumerState<_LotFullCard> {
  /// Null until the server has said; the button waits for it rather than
  /// guessing and flipping a moment later.
  bool? _watching;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.canWatch) _load();
  }

  Future<void> _load() async {
    try {
      final watching =
          await ref.read(notificationsRepositoryProvider).isWatchingSlots();
      if (mounted) setState(() => _watching = watching);
    } catch (_) {
      // Not worth an error bar: the card still says the lot is full, and the
      // button offers to watch, which is the safe default.
      if (mounted) setState(() => _watching = false);
    }
  }

  Future<void> _toggle() async {
    final watching = _watching ?? false;
    setState(() => _busy = true);
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      if (watching) {
        await repo.unwatchSlots();
      } else {
        await repo.watchSlots();
      }
      if (!mounted) return;
      setState(() => _watching = !watching);
      showAppMessage(
        context,
        watching
            ? "Okay, we won't notify you."
            : "We'll notify you when a slot opens.",
      );
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.warning;
    final watching = _watching ?? false;

    return AppCard(
      color: c.bg,
      borderColor: c.border,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        children: [
          Text(
            'Lot is full',
            style: context.text.headlineSmall?.copyWith(color: c.fg),
          ),
          const SizedBox(height: 6),
          Text(
            watching
                ? "You'll get a notification when a slot opens."
                : 'No slots are free right now. Pull down to check again.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium
                ?.copyWith(color: context.tokens.text.secondary),
          ),
          if (widget.canWatch) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: watching
                  ? 'Stop notifying me'
                  : 'Notify me when a slot opens',
              style: watching ? AppButtonStyle.ghost : AppButtonStyle.primary,
              isLoading: _busy,
              onPressed: _busy || _watching == null ? null : _toggle,
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentSessionCard extends StatelessWidget {
  const _CurrentSessionCard({required this.entry, required this.availability});

  final ParkingHistoryEntry entry;
  final ParkingAvailability availability;

  /// The gate lives on the *slot*, not on the history entry, so a session's
  /// gate has to be looked up by slot code. Null when the code matches nothing
  /// currently returned — the line then drops the gate rather than guessing.
  int? get _gate {
    final code = entry.slotCode;
    if (code == null) return null;
    for (final slot in availability.slots) {
      if (slot.slotCode == code) return slot.gate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final gate = _gate;
    final title = [
      entry.slotCode ?? 'Unassigned slot',
      if (gate != null) 'Gate $gate',
    ].join(' · ');

    return AppCard(
      borderColor: t.tertiary.primary,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: t.tertiary.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                'CURRENT SESSION',
                style: context.text.labelSmall
                    ?.copyWith(color: t.tertiary.subtleText),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: context.text.headlineMedium),
          const SizedBox(height: 2),
          Text(
            Formatters.sessionRange(entry.entryTime, null, entry.duration),
            style: AppTypography.tabular(context.text.bodyMedium!)
                .copyWith(color: t.text.secondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          // No running fee estimate here, on purpose. Nothing in the app knows
          // the lot's rate — ratePerHourApplied only exists on a payment, which
          // is created at exit — so any figure here would be the app inventing
          // a number the server has not agreed to.
          Text(
            'The amount is calculated at exit from the gate reading.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AvailabilitySkeleton extends StatelessWidget {
  const _AvailabilitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppScreenTitle(title: 'Parking'),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppSkeleton.line(width: 80, height: 11),
              SizedBox(height: AppSpacing.sm),
              AppSkeleton(width: 96, height: 40, radius: AppRadius.sm),
              SizedBox(height: AppSpacing.xs),
              AppSkeleton.line(width: 140),
              SizedBox(height: AppSpacing.md),
              AppSkeleton(width: 160, height: 28, radius: AppRadius.full),
              SizedBox(height: AppSpacing.md),
              AppSkeleton.line(width: double.infinity, height: 32),
            ],
          ),
        ),
      ],
    );
  }
}
