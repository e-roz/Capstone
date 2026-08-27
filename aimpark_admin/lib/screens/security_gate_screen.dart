import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/security.dart';
import '../providers/parking_provider.dart';
import '../providers/security_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

/// The barrier, as one screen.
///
/// A guard's job at the gate is three questions in a row — whose card is this,
/// does the car match it, and does the barrier open — and they were spread
/// across the parking screen, the user list and nowhere at all. Here they are
/// one column: look the card up, read what should be in front of you, act.
///
/// The hardware normally does all of this itself. This screen is the fallback
/// for when a reader is down or a card will not scan, which on a live gate is
/// the moment somebody is sitting in a queue waiting.
class SecurityGateScreen extends ConsumerStatefulWidget {
  const SecurityGateScreen({super.key});

  @override
  ConsumerState<SecurityGateScreen> createState() => _SecurityGateScreenState();
}

class _SecurityGateScreenState extends ConsumerState<SecurityGateScreen> {
  final _tagCtrl = TextEditingController();
  final _tagFocus = FocusNode();

  @override
  void dispose() {
    _tagCtrl.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  void _lookup() {
    ref.read(gateTagQueryProvider.notifier).set(_tagCtrl.text);
  }

  void _reset() {
    _tagCtrl.clear();
    ref.read(gateTagQueryProvider.notifier).clear();
    // Straight back into the box. The next car is already waiting, and a guard
    // should never have to reach for the mouse between vehicles.
    _tagFocus.requestFocus();
  }

  Future<void> _act(Future<String?> Function() action) async {
    final message = await action();
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message ?? 'Done.')));

    ref.invalidate(gateTagLookupProvider);
    ref.invalidate(activeParkingSessionsProvider);
    ref.invalidate(parkingSlotsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(gateTagLookupProvider);

    return AppPage(
      title: 'Gate Check',
      subtitle: 'Look up the card in front of you, check the vehicle matches, '
          'then log the entry or exit.',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagCtrl,
                      focusNode: _tagFocus,
                      autofocus: true,
                      decoration: const InputDecoration(
                        label: AppFieldLabel('RFID card number'),
                        hintText: 'Scan the card or type its number',
                      ),
                      // A USB reader types the number and presses Enter. This
                      // is what makes the screen work with one, hands-free.
                      onSubmitted: (_) => _lookup(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.controlGap),
                  FilledButton.icon(
                    onPressed: _lookup,
                    icon: const Icon(Icons.search),
                    label: const Text('Look up'),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  TextButton(onPressed: _reset, child: const Text('Clear')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gutter),
            lookup.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.x8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => AppErrorState(
                error: e,
                title: 'Could not look that card up',
                onRetry: () => ref.invalidate(gateTagLookupProvider),
              ),
              data: (result) => result == null
                  ? const AppEmptyState(
                      icon: Icons.badge_outlined,
                      title: 'No card yet',
                      message: 'Scan a card, or type its number and press Enter.',
                    )
                  : _LookupResult(
                      result: result,
                      onLogEntry: () => _act(() => ref
                          .read(parkingActionsProvider.notifier)
                          .logEntry(rfidTagId: _tagCtrl.text.trim())),
                      onLogExit: () => _act(() => ref
                          .read(parkingActionsProvider.notifier)
                          .logExitByTag(_tagCtrl.text.trim())),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who the card belongs to, and what the guard should do about it.
class _LookupResult extends StatelessWidget {
  const _LookupResult({
    required this.result,
    required this.onLogEntry,
    required this.onLogExit,
  });

  final TagLookup result;
  final VoidCallback onLogEntry;
  final VoidCallback onLogExit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (!result.isKnown) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.help_outline, color: t.status.danger.solid, size: 32),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Card not recognised', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    result.deniedReason ??
                        'Nobody holds this card. If they are a guest, issue a '
                            'visitor pass instead.',
                    style: text.bodyMedium?.copyWith(color: t.text.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final intent =
        result.accessAllowed ? StatusIntent.success : StatusIntent.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The verdict, first and large. A guard glances at this screen with a
        // car waiting; whether to raise the barrier must not be something they
        // have to read a paragraph to work out.
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                result.accessAllowed
                    ? Icons.check_circle_outline
                    : Icons.block_outlined,
                color: t.status.of(intent).solid,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.accessAllowed ? 'Allowed' : 'Do not let in',
                      style: text.headlineSmall
                          ?.copyWith(color: t.status.of(intent).solid),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Row(
                      children: [
                        Flexible(
                          child: Text(result.name ?? 'Unknown',
                              style: text.titleMedium),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        StatusPill.of(
                          result.affiliation ?? result.holder,
                          intent: result.isVisitor
                              ? StatusIntent.info
                              : StatusIntent.neutral,
                          dense: true,
                          showDot: false,
                        ),
                      ],
                    ),
                    if (result.deniedReason case final reason?) ...[
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        reason,
                        style: text.bodyMedium
                            ?.copyWith(color: t.status.danger.solid),
                      ),
                    ],
                    if (result.passExpiresAt case final expires?) ...[
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        'Visitor pass valid until '
                        '${DateFormat('MMM d, HH:mm').format(expires.toLocal())}',
                        style:
                            text.bodySmall?.copyWith(color: t.text.secondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gutter),

        // The verification half: what should be sitting in front of them.
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Check the vehicle', style: text.titleSmall),
              const SizedBox(height: AppSpacing.x1),
              Text(
                result.vehicles.length == 1
                    ? 'This card should arrive on this plate.'
                    : 'This card may arrive on any of these plates.',
                style: text.bodySmall?.copyWith(color: t.text.secondary),
              ),
              const SizedBox(height: AppSpacing.x3),
              if (result.vehicles.isEmpty)
                Text(
                  'No vehicle is registered to this card.',
                  style: text.bodyMedium?.copyWith(color: t.status.warning.solid),
                )
              else
                Wrap(
                  spacing: AppSpacing.x3,
                  runSpacing: AppSpacing.x3,
                  children: [
                    for (final vehicle in result.vehicles)
                      _PlateChip(vehicle: vehicle),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gutter),

        // Only the move that makes sense. Offering both means offering the
        // wrong one, and the wrong one here either orphans a session or
        // charges somebody for a visit they never made.
        AppCard(
          child: context.isCompact
              ? Column(children: _actions(context))
              : Row(children: _actions(context)),
        ),
      ],
    );
  }

  List<Widget> _actions(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return [
      Expanded(
        child: Text(
          result.isInside
              ? 'Inside since '
                  '${DateFormat('HH:mm').format(result.entryTime!.toLocal())}'
                  '${result.slotCode == null ? '' : ' at ${result.slotCode}'}'
              : 'Not inside the lot.',
          style: text.bodyMedium?.copyWith(color: t.text.secondary),
        ),
      ),
      const SizedBox(width: AppSpacing.controlGap),
      if (result.isInside)
        FilledButton.icon(
          onPressed: onLogExit,
          icon: const Icon(Icons.logout),
          label: const Text('Log exit'),
        )
      else
        FilledButton.icon(
          // Refused cards get no button at all. A guard who can see "Do not let
          // in" and a "Log entry" button beside it is being invited to make the
          // mistake the screen exists to prevent.
          onPressed: result.accessAllowed ? onLogEntry : null,
          icon: const Icon(Icons.login),
          label: const Text('Log entry'),
        ),
    ];
  }
}

class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.vehicle});

  final TagVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: AppRadii.smAll,
        border: Border.all(
          color: vehicle.registrationExpired
              ? t.status.warning.solid
              : t.border.normal,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The plate is the thing being compared against metal, so it is set
          // large and monospaced rather than in the body style.
          Text(
            vehicle.plateNumber,
            style: text.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            [vehicle.vehicleType, ?vehicle.color].join(' · '),
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
          if (vehicle.registrationExpired) ...[
            const SizedBox(height: AppSpacing.x2),
            StatusPill.of(
              'Registration expired',
              intent: StatusIntent.warning,
              dense: true,
              showDot: false,
            ),
          ],
        ],
      ),
    );
  }
}
