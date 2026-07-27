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
                    Expanded(child: _SlotTable(slots: availability.slots)),
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
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any')),
                    DropdownMenuItem(value: 'Motor', child: Text('Motor')),
                    DropdownMenuItem(value: '4 Wheels', child: Text('4 Wheels')),
                  ],
                  onChanged: (v) => setState(() => vehicleType = v),
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
        .createSlot(codeCtrl.text.trim(), vehicleType);
    if (!context.mounted) return;
    _showSnack(context, msg ?? 'Slot created.');
    ref.invalidate(parkingSlotsProvider);
  }

  Future<void> _showLogEntry(BuildContext context, WidgetRef ref) async {
    PickedUser? picked;
    String? slotId;
    String? userError;
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
                DropdownButtonFormField<String?>(
                  initialValue: slotId,
                  decoration: const InputDecoration(
                      labelText: 'Slot (optional)', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...slots.map((s) => DropdownMenuItem(
                        value: s.slotId, child: Text(s.slotCode))),
                  ],
                  onChanged: (v) => setState(() => slotId = v),
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

class _SlotTable extends ConsumerWidget {
  const _SlotTable({required this.slots});

  final List<ParkingSlot> slots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (slots.isEmpty) {
      return const Center(child: Text('No parking slots yet.'));
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('Slot Code')),
            DataColumn(label: Text('Vehicle Type')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: slots.map((s) => _slotRow(context, ref, s)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _slotRow(BuildContext context, WidgetRef ref, ParkingSlot slot) {
    return DataRow(cells: [
      DataCell(Text(slot.slotCode)),
      DataCell(Text(slot.vehicleType ?? 'Any')),
      DataCell(_StatusChip(status: slot.status)),
      DataCell(DropdownButton<String>(
        value: slot.status,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: 'Available', child: Text('Available')),
          DropdownMenuItem(value: 'Occupied', child: Text('Occupied')),
          DropdownMenuItem(value: 'OutOfService', child: Text('Out of Service')),
        ],
        onChanged: (v) async {
          if (v == null || v == slot.status) return;
          final msg = await ref
              .read(parkingActionsProvider.notifier)
              .updateSlotStatus(slot.slotId, v);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg ?? 'Status updated.')));
          ref.invalidate(parkingSlotsProvider);
        },
      )),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Available':
        color = Colors.green;
        break;
      case 'Occupied':
        color = Colors.orange;
        break;
      default:
        color = Colors.red;
    }
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
