import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/parking_slot.dart';
import '../providers/parking_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';
import '../widgets/user_picker.dart';

final _clock = DateFormat('HH:mm');

/// The lot drawn as it is laid out physically: two gates, each with its
/// four-wheel bays and its motorcycle bays.
///
/// This is the one screen whose data is inherently spatial, and it used to
/// announce a full lot with a line of grey 14px text. The ring, the per-gate
/// bars and the coloured bays say the same thing in a glance — and the
/// "real-time parking visualisation" requirement is satisfied by a map of the
/// facility in a way no table ever satisfies it.
class ParkingScreen extends ConsumerWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Parking',
      subtitle: 'Live bay status across both gates.',
      scrollable: true,
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.login, size: AppSizes.iconSm),
          label: const Text('Log Entry'),
          onPressed: () => _showLogEntry(context, ref),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout, size: AppSizes.iconSm),
          label: const Text('Log Exit'),
          onPressed: () => _showLogExit(context, ref),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.add, size: AppSizes.iconSm),
          label: const Text('Add Slot'),
          onPressed: () => _showAddSlot(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(parkingSlotsProvider);
            ref.invalidate(activeParkingSessionsProvider);
          },
        ),
      ],
      body: AsyncView(
        value: ref.watch(parkingSlotsProvider),
        onRetry: () => ref.invalidate(parkingSlotsProvider),
        loading: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBlock(height: 180),
            SizedBox(height: AppSpacing.gutter),
            SkeletonBlock(height: 220),
            SizedBox(height: AppSpacing.gutter),
            SkeletonBlock(height: 220),
          ],
        ),
        isEmpty: (availability) => availability.slots.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.local_parking_outlined,
          title: 'No bays configured',
          message: 'Add a slot to start tracking the lot.',
        ),
        data: (availability) {
          // Occupied bays are matched back to who is standing in them, so a
          // hovered bay can name the driver rather than just its own code.
          final sessions = {
            for (final s
                in ref.watch(activeParkingSessionsProvider).valueOrNull ??
                    const <ActiveParkingSession>[])
              if (s.slotCode != null) s.slotCode!: s,
          };

          final gates = availability.slots.map((s) => s.gate).toSet().toList()
            ..sort();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LotSummary(availability: availability, gates: gates),
              const SizedBox(height: AppSpacing.gutter),
              for (final gate in gates) ...[
                _GateSection(
                  gate: gate,
                  slots:
                      availability.slots.where((s) => s.gate == gate).toList(),
                  sessions: sessions,
                ),
                const SizedBox(height: AppSpacing.gutter),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _showAddSlot(BuildContext context, WidgetRef ref) async {
    final codeCtrl = TextEditingController();
    String? vehicleType;
    var gate = 1;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Parking Slot'),
          content: SizedBox(
            width: ctx.dialogWidth(380),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppRequiredNote(),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                        label: AppFieldLabel('Slot code', isRequired: true)),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Slot code is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  DropdownButtonFormField<String?>(
                    initialValue: vehicleType,
                    decoration:
                        const InputDecoration(labelText: 'Vehicle type'),
                    // Values must be the API's VehicleType enum names — the old
                    // 'Motor'/'4 Wheels' never matched what registration stores.
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Any')),
                      DropdownMenuItem(
                          value: 'Motorcycle', child: Text('Motorcycle')),
                      DropdownMenuItem(value: 'Car', child: Text('Car')),
                    ],
                    onChanged: (v) => setState(() => vehicleType = v),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  DropdownButtonFormField<int>(
                    initialValue: gate,
                    decoration: const InputDecoration(labelText: 'Gate'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Gate 1')),
                      DropdownMenuItem(value: 2, child: Text('Gate 2')),
                    ],
                    onChanged: (v) => setState(() => gate = v ?? 1),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final msg = await ref
        .read(parkingActionsProvider.notifier)
        .createSlot(codeCtrl.text.trim(), vehicleType, gate);
    if (!context.mounted) return;
    _showSnack(context, msg ?? 'Slot created.');
    ref.invalidate(parkingSlotsProvider);
  }

  Future<void> _showLogEntry(BuildContext context, WidgetRef ref) async {
    PickedUser? picked;
    String? slotId;
    String? userError;
    var gate = 1;
    final slots = ref
            .read(parkingSlotsProvider)
            .valueOrNull
            ?.slots
            .where((s) => s.status == 'Available')
            .toList() ??
        [];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Log Parking Entry'),
          content: SizedBox(
            width: ctx.dialogWidth(380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogNote(
                  'Stand-in for the RFID reader — record a vehicle entering '
                  'the lot.',
                ),
                const SizedBox(height: AppSpacing.x4),
                UserPickerField(
                  selected: picked,
                  errorText: userError,
                  onChanged: (u) => setState(() {
                    picked = u;
                    userError = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.x3),
                // Which reader the vehicle pulled up to. Set by hand while
                // testing; in production each ESP32 is fixed to one gate and
                // supplies this itself.
                DropdownButtonFormField<int>(
                  initialValue: gate,
                  decoration:
                      const InputDecoration(labelText: 'Scanning at gate'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Gate 1')),
                    DropdownMenuItem(value: 2, child: Text('Gate 2')),
                  ],
                  onChanged: (v) => setState(() {
                    gate = v ?? 1;
                    // The bay picked at the old gate is not behind this one.
                    slotId = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.x3),
                // Only bays behind the gate the driver is actually at. A
                // reader is bolted to one barrier, so offering Gate 2's bays
                // while scanning at Gate 1 could only ever produce a wrong
                // entry.
                Builder(builder: (context) {
                  final atGate =
                      slots.where((s) => s.gate == gate).toList();

                  return DropdownButtonFormField<String?>(
                    initialValue:
                        atGate.any((s) => s.slotId == slotId) ? slotId : null,
                    decoration: InputDecoration(
                      labelText: 'Slot',
                      helperText: 'Free bays at gate $gate',
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Assign automatically')),
                      ...atGate.map((s) => DropdownMenuItem(
                          value: s.slotId, child: Text(s.slotCode))),
                    ],
                    onChanged: (v) => setState(() => slotId = v),
                  );
                }),
                if (slotId == null) ...[
                  const SizedBox(height: AppSpacing.x2),
                  _DialogNote(
                    'The system will pick a bay at this gate, or send the '
                    'driver to the other gate if this one is full.',
                  ),
                ],
                if (slots.isEmpty) ...[
                  const SizedBox(height: AppSpacing.x2),
                  _DialogNote(
                    'No slots are currently available.',
                    intent: StatusIntent.warning,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (picked == null) {
                  setState(() => userError = 'Select a user');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Log Entry'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final msg = await ref.read(parkingActionsProvider.notifier).logEntry(
          userId: picked!.userId,
          slotId: slotId,
          gate: gate,
        );
    if (!context.mounted) return;
    _showSnack(context, msg ?? 'Entry logged.');
    ref.invalidate(parkingSlotsProvider);
    ref.invalidate(activeParkingSessionsProvider);
  }

  Future<void> _showLogExit(BuildContext context, WidgetRef ref) async {
    final sessions = await ref.read(activeParkingSessionsProvider.future);
    if (!context.mounted) return;

    if (sessions.isEmpty) {
      _showSnack(context, 'No vehicles are currently inside.');
      return;
    }

    final selected = await showDialog<ActiveParkingSession>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Parking Exit'),
        content: SizedBox(
          width: ctx.dialogWidth(420),
          height: ctx.dialogHeight(360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogNote('Select the vehicle that is leaving.'),
              const SizedBox(height: AppSpacing.x3),
              Expanded(
                child: ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    final detail = [
                      if (s.plateNumber != null) s.plateNumber!,
                      if (s.slotCode != null) 'Slot ${s.slotCode}',
                      'In since ${DateFormat('MMM d, HH:mm').format(s.entryTime.toLocal())}',
                    ].join(' • ');

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.userName),
                      subtitle: Text(detail),
                      onTap: () => Navigator.pop(ctx, s),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );

    if (selected == null || !context.mounted) return;

    final msg = await ref
        .read(parkingActionsProvider.notifier)
        .logExit(selected.logId);
    if (!context.mounted) return;
    _showSnack(context, msg ?? 'Exit logged.');
    ref.invalidate(parkingSlotsProvider);
    ref.invalidate(activeParkingSessionsProvider);
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ── Lot summary ──────────────────────────────────────────────────────────────

class _LotSummary extends StatelessWidget {
  const _LotSummary({required this.availability, required this.gates});

  final ParkingAvailability availability;
  final List<int> gates;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final total = availability.totalSlots;
    final free = availability.availableSlots;
    final occupied = total - free;
    final ratio = total == 0 ? 0.0 : occupied / total;

    final intent = switch (ratio) {
      >= 0.95 => StatusIntent.danger,
      >= 0.8 => StatusIntent.warning,
      _ => StatusIntent.success,
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ring = AppProgressRing(
            value: ratio,
            intent: intent,
            size: 150,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$free',
                    style: AppTypography.tabular(text.displaySmall!)),
                Text('free',
                    style:
                        text.bodySmall?.copyWith(color: t.text.secondary)),
              ],
            ),
          );

          final detail = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$occupied of $total bays in use', style: text.titleMedium),
              const SizedBox(height: AppSpacing.x4),
              for (final gate in gates) ...[
                _GateBar(
                  gate: gate,
                  slots:
                      availability.slots.where((s) => s.gate == gate).toList(),
                ),
                const SizedBox(height: AppSpacing.x3),
              ],
              const SizedBox(height: AppSpacing.x1),
              const _Legend(),
            ],
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: ring),
                const SizedBox(height: AppSpacing.x5),
                detail,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ring,
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: detail),
            ],
          );
        },
      ),
    );
  }
}

/// One gate's fill level as a bar, so the two gates can be compared without
/// counting bays. A lot that is half full overall but has one gate jammed is a
/// different operational situation, and only this makes that visible.
class _GateBar extends StatelessWidget {
  const _GateBar({required this.gate, required this.slots});

  final int gate;
  final List<ParkingSlot> slots;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final free = slots.where((s) => s.status == 'Available').length;
    final ratio = slots.isEmpty ? 0.0 : (slots.length - free) / slots.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.door_front_door_outlined,
                size: AppSizes.iconSm, color: t.text.secondary),
            const SizedBox(width: AppSpacing.x2),
            Expanded(child: Text('Gate $gate', style: text.titleSmall)),
            Text(
              '$free free',
              style: AppTypography.tabular(
                text.bodySmall!.copyWith(color: t.text.secondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x1),
        ClipRRect(
          borderRadius: AppRadii.fullAll,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: t.surface.muted,
            valueColor: AlwaysStoppedAnimation(
              t.status.of(ratio >= 0.95 ? StatusIntent.danger : StatusIntent.accent)
                  .solid,
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  static const _entries = [
    ('Available', 'Available'),
    ('Occupied', 'Occupied'),
    ('OutOfService', 'Out of service'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Wrap(
      spacing: AppSpacing.x4,
      runSpacing: AppSpacing.x2,
      children: [
        for (final (status, label) in _entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: t.status.of(StatusIntents.slot(status)).solid,
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
              ),
              const SizedBox(width: AppSpacing.x2 - 2),
              Text(label,
                  style: text.labelSmall?.copyWith(color: t.text.secondary)),
            ],
          ),
      ],
    );
  }
}

// ── Gate section ─────────────────────────────────────────────────────────────

class _GateSection extends StatelessWidget {
  const _GateSection({
    required this.gate,
    required this.slots,
    required this.sessions,
  });

  final int gate;
  final List<ParkingSlot> slots;
  final Map<String, ActiveParkingSession> sessions;

  @override
  Widget build(BuildContext context) {
    final cars = slots.where((s) => !s.isMotorcycle).toList()
      ..sort((a, b) => a.slotCode.compareTo(b.slotCode));
    final motorcycles = slots.where((s) => s.isMotorcycle).toList()
      ..sort((a, b) => a.slotCode.compareTo(b.slotCode));
    final free = slots.where((s) => s.status == 'Available').length;

    return AppSectionCard(
      title: 'Gate $gate',
      subtitle: '$free of ${slots.length} bays free',
      icon: Icons.door_front_door_outlined,
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cars.isNotEmpty)
            _BayRow(
              icon: Icons.directions_car_rounded,
              label: 'Four-wheel',
              slots: cars,
              sessions: sessions,
            ),
          if (cars.isNotEmpty && motorcycles.isNotEmpty)
            const SizedBox(height: AppSpacing.x5),
          if (motorcycles.isNotEmpty)
            _BayRow(
              icon: Icons.two_wheeler_rounded,
              label: 'Motorcycle',
              slots: motorcycles,
              sessions: sessions,
            ),
        ],
      ),
    );
  }
}

class _BayRow extends StatelessWidget {
  const _BayRow({
    required this.icon,
    required this.label,
    required this.slots,
    required this.sessions,
  });

  final IconData icon;
  final String label;
  final List<ParkingSlot> slots;
  final Map<String, ActiveParkingSession> sessions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: AppSizes.iconSm, color: t.text.tertiary),
            const SizedBox(width: AppSpacing.x2),
            Text(
              label.toUpperCase(),
              style: text.labelSmall?.copyWith(
                color: t.text.tertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: [
            for (final slot in slots)
              _Bay(slot: slot, session: sessions[slot.slotCode]),
          ],
        ),
      ],
    );
  }
}

/// One bay. Colour is the status, the strip along the bottom repeats it for
/// anyone who cannot separate the tints, and an occupied bay names its driver
/// on hover — which is the whole reason to draw a map rather than a list.
class _Bay extends ConsumerStatefulWidget {
  const _Bay({required this.slot, required this.session});

  final ParkingSlot slot;
  final ActiveParkingSession? session;

  @override
  ConsumerState<_Bay> createState() => _BayState();
}

class _BayState extends ConsumerState<_Bay> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final slot = widget.slot;
    final c = t.status.of(StatusIntents.slot(slot.status));

    final session = widget.session;
    final tooltip = [
      '${slot.slotCode} · ${slot.status}',
      if (session != null) session.userName,
      if (session?.plateNumber != null) session!.plateNumber!,
      if (session != null)
        'In since ${_clock.format(session.entryTime.toLocal())}',
    ].join('\n');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _changeStatus,
        child: Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            width: 86,
            height: 64,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: AppRadii.mdAll,
              border: Border.all(
                color: _hovered ? c.solid : c.border,
                width: _hovered ? 1.5 : 1,
              ),
              boxShadow: _hovered ? AppElevation.md : AppElevation.none,
            ),
            padding: const EdgeInsets.all(AppSpacing.x2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.slotCode,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(color: c.fg),
                ),
                const Spacer(),
                if (session != null)
                  Text(
                    session.plateNumber ?? session.userName,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: c.fg),
                  )
                else
                  Container(
                    width: 24,
                    height: 3,
                    decoration: BoxDecoration(
                      color: c.solid,
                      borderRadius: AppRadii.fullAll,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeStatus() async {
    const options = {
      'Available': 'Available',
      'Occupied': 'Occupied',
      'OutOfService': 'Out of service',
    };

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final t = ctx.tokens;
        return SimpleDialog(
          title: Text('${widget.slot.slotCode} — ${widget.slot.status}'),
          children: [
            for (final entry in options.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, entry.key),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: t.status.of(StatusIntents.slot(entry.key)).solid,
                        borderRadius: const BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Text(entry.value),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (picked == null || picked == widget.slot.status || !mounted) return;

    final msg = await ref
        .read(parkingActionsProvider.notifier)
        .updateSlotStatus(widget.slot.slotId, picked);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Status updated.')));
    ref.invalidate(parkingSlotsProvider);
  }
}

/// Explanatory small print inside a dialog.
class _DialogNote extends StatelessWidget {
  const _DialogNote(this.message, {this.intent});

  final String message;
  final StatusIntent? intent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: intent == null
                ? t.text.secondary
                : t.status.of(intent!).fg,
          ),
    );
  }
}
