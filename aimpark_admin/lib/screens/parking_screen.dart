import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/parking_slot.dart';
import '../providers/parking_provider.dart';
import '../widgets/user_picker.dart';
import '../core/utils/responsive.dart';
import '../widgets/page_header.dart';

class ParkingScreen extends ConsumerWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(parkingSlotsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Parking',
              actions: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('Log Entry'),
                  onPressed: () => _showLogEntry(context, ref),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Log Exit'),
                  onPressed: () => _showLogExit(context, ref),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Slot'),
                  onPressed: () => _showAddSlot(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(parkingSlotsProvider),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load slots: $e')),
                data: (availability) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${availability.availableSlots} of ${availability.totalSlots} slots available',
                        style: const TextStyle(fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 12),
                    Expanded(child: _SlotGrid(slots: availability.slots)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Slot Code', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Slot code is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: vehicleType,
                  decoration: const InputDecoration(
                      labelText: 'Vehicle Type', border: OutlineInputBorder()),
                  // Values must be the API's VehicleType enum names — the old
                  // 'Motor'/'4 Wheels' never matched what registration stores.
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any')),
                    DropdownMenuItem(value: 'Motorcycle', child: Text('Motorcycle')),
                    DropdownMenuItem(value: 'Car', child: Text('Car')),
                  ],
                  onChanged: (v) => setState(() => vehicleType = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: gate,
                  decoration: const InputDecoration(
                      labelText: 'Gate', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Gate 1')),
                    DropdownMenuItem(value: 2, child: Text('Gate 2')),
                  ],
                  onChanged: (v) => setState(() => gate = v ?? 1),
                ),
              ],
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
    final slots = ref.read(parkingSlotsProvider).valueOrNull?.slots
            .where((s) => s.status == 'Available')
            .toList() ??
        [];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Log Parking Entry'),
          content: SizedBox(
            width: context.dialogWidth(380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Stand-in for the RFID reader — record a vehicle entering the lot.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ),
                const SizedBox(height: 16),
                UserPickerField(
                  selected: picked,
                  errorText: userError,
                  onChanged: (u) => setState(() {
                    picked = u;
                    userError = null;
                  }),
                ),
                const SizedBox(height: 12),
                // Which reader the vehicle pulled up to. Set by hand while
                // testing; in production each ESP32 is fixed to one gate and
                // supplies this itself.
                DropdownButtonFormField<int>(
                  initialValue: gate,
                  decoration: const InputDecoration(
                      labelText: 'Scanning at gate',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Gate 1')),
                    DropdownMenuItem(value: 2, child: Text('Gate 2')),
                  ],
                  onChanged: (v) => setState(() => gate = v ?? 1),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: slotId,
                  decoration: const InputDecoration(
                      labelText: 'Slot', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Assign automatically')),
                    ...slots.map((s) => DropdownMenuItem(
                        value: s.slotId, child: Text(s.slotCode))),
                  ],
                  onChanged: (v) => setState(() => slotId = v),
                ),
                if (slotId == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                        'The system will pick a bay at this gate, or send the '
                        'driver to the other gate if this one is full.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                if (slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No slots are currently available.',
                        style: TextStyle(fontSize: 12, color: Colors.orange)),
                  ),
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
          width: context.dialogWidth(420),
          height: context.dialogHeight(360),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Select the vehicle that is leaving.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    final subtitle = [
                      if (s.plateNumber != null) s.plateNumber!,
                      if (s.slotCode != null) 'Slot ${s.slotCode}',
                      'In since ${DateFormat('MMM d, HH:mm').format(s.entryTime.toLocal())}',
                    ].join(' • ');

                    return ListTile(
                      dense: true,
                      title: Text(s.userName),
                      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
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

/// Colour for a slot status, shared by the tiles and the legend so the two can
/// never drift apart.
Color _statusColor(String status) => switch (status) {
      'Available' => const Color(0xFF2E7D32),
      'Occupied' => const Color(0xFFE65100),
      _ => const Color(0xFFB71C1C),
    };

/// The lot rendered as it is laid out physically: two gates, each with its
/// four-wheel bays and its motorcycle bays. A flat table gave no sense of where
/// anything is, and did not satisfy the "real-time parking visualisation"
/// requirement the way a map of the facility does.
class _SlotGrid extends ConsumerWidget {
  const _SlotGrid({required this.slots});

  final List<ParkingSlot> slots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (slots.isEmpty) {
      return const Center(child: Text('No parking slots yet.'));
    }

    final gates = slots.map((s) => s.gate).toSet().toList()..sort();

    return ListView(
      children: [
        const _Legend(),
        const SizedBox(height: 16),
        for (final gate in gates) ...[
          _GateSection(
            gate: gate,
            slots: slots.where((s) => s.gate == gate).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const entries = ['Available', 'Occupied', 'Out of Service'];
    const keys = ['Available', 'Occupied', 'OutOfService'];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (var i = 0; i < entries.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _statusColor(keys[i]),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(entries[i], style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
    );
  }
}

class _GateSection extends StatelessWidget {
  const _GateSection({required this.gate, required this.slots});

  final int gate;
  final List<ParkingSlot> slots;

  @override
  Widget build(BuildContext context) {
    final cars = slots.where((s) => !s.isMotorcycle).toList()
      ..sort((a, b) => a.slotCode.compareTo(b.slotCode));
    final motorcycles = slots.where((s) => s.isMotorcycle).toList()
      ..sort((a, b) => a.slotCode.compareTo(b.slotCode));
    final free = slots.where((s) => s.status == 'Available').length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.door_front_door_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Gate $gate',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$free of ${slots.length} free',
                    style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
            if (cars.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _RowLabel(icon: Icons.directions_car_rounded, text: 'Four-wheel'),
              const SizedBox(height: 8),
              _SlotWrap(slots: cars),
            ],
            if (motorcycles.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _RowLabel(icon: Icons.two_wheeler_rounded, text: 'Motorcycle'),
              const SizedBox(height: 8),
              _SlotWrap(slots: motorcycles),
            ],
          ],
        ),
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.black54),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SlotWrap extends StatelessWidget {
  const _SlotWrap({required this.slots});

  final List<ParkingSlot> slots;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final slot in slots) _SlotTile(slot: slot)],
    );
  }
}

class _SlotTile extends ConsumerWidget {
  const _SlotTile({required this.slot});

  final ParkingSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(slot.status);

    return Tooltip(
      message: '${slot.slotCode} · ${slot.status}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _changeStatus(context, ref),
        child: Container(
          width: 76,
          height: 58,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                slot.slotCode,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Container(
                width: 26,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref) async {
    const options = {
      'Available': 'Available',
      'Occupied': 'Occupied',
      'OutOfService': 'Out of Service',
    };

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
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
                      color: _statusColor(entry.key),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(entry.value),
                ],
              ),
            ),
        ],
      ),
    );

    if (picked == null || picked == slot.status || !context.mounted) return;

    final msg = await ref
        .read(parkingActionsProvider.notifier)
        .updateSlotStatus(slot.slotId, picked);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Status updated.')));
    ref.invalidate(parkingSlotsProvider);
  }
}
