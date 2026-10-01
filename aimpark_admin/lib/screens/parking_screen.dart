import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/parking_slot.dart';
import '../providers/auth_provider.dart';
import '../providers/parking_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';
import '../widgets/parking/live_parking_map.dart';
import '../widgets/user_picker.dart';

/// The lot drawn as it is laid out physically — see [LiveParkingMapCard].
///
/// Security opens it read-only for the map. Creating bays, changing their
/// status and logging entries by hand stay with the administrator.
class ParkingScreen extends ConsumerWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(staffRoleProvider) != StaffRole.security;

    return AppPage(
      title: 'Parking',
      subtitle: 'Live bay status across both gates.',
      scrollable: true,
      actions: [
        if (isAdmin) ...[
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
        ],
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(parkingSlotsProvider);
            ref.invalidate(activeParkingSessionsProvider);
          },
        ),
      ],
      body: LiveParkingMapCard(
        onBayTap: isAdmin ? (slot) => _changeStatus(context, ref, slot) : null,
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
              autovalidateMode: AutovalidateMode.onUserInteraction,
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

  Future<void> _changeStatus(BuildContext context, WidgetRef ref, ParkingSlot slot) async {
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
          title: Text('${slot.slotCode} — ${slot.status}'),
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

    if (picked == null || picked == slot.status || !context.mounted) return;

    final msg = await ref
        .read(parkingActionsProvider.notifier)
        .updateSlotStatus(slot.slotId, picked);
    if (!context.mounted) return;
    _showSnack(context, msg ?? 'Status updated.');
    ref.invalidate(parkingSlotsProvider);
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
