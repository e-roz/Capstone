import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/parking_slot.dart';
import '../providers/auth_provider.dart';
import '../providers/parking_provider.dart';
import '../router/destinations.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';
import '../widgets/parking/gate_entry_banners.dart';
import '../widgets/parking/live_parking_map.dart';
import '../widgets/parking/slot_history.dart';

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
        const ParkingStatus(),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(parkingSlotsProvider);
            ref.invalidate(activeParkingSessionsProvider);
          },
        ),
      ],
      // A guard gets the gate banners on top, for the screen the page is
      // projected on, and has the wrong-bay alerts on the Overview instead.
      body: LiveParkingMapCard(
        // Everyone opens a bay's history; only the administrator can also
        // change its status from there.
        onBayTap: (slot) => showSlotHistoryDialog(
          context,
          slot,
          onChangeStatus: isAdmin ? () => _changeStatus(context, ref, slot) : null,
        ),
        showWrongBayAlerts: isAdmin,
        header: isAdmin ? null : const GateEntryBanners(),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

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
