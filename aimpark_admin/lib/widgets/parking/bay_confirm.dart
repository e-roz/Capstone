import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/responsive.dart';
import '../../models/parking_log.dart';
import '../../models/parking_slot.dart';
import '../../providers/parking_provider.dart';
import '../../theme/theme.dart';
import '../ui/ui.dart';

final _time = DateFormat('HH:mm');
final _stamp = DateFormat('MMM d, HH:mm');

/// The Parking Logs "Confirmed" cell: which bay the driver said they used,
/// or that they left without saying. A confirmed bay opens its history.
class BayConfirmCell extends StatelessWidget {
  const BayConfirmCell({super.key, required this.entry, this.onOpen});

  final ParkingLogEntry entry;

  /// Opens the confirm and its corrections. Null for an unconfirmed session,
  /// which has nothing to show.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    Widget note(String value, Color color, {IconData? icon}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 2),
            ],
            Text(value, style: text.bodySmall?.copyWith(color: color)),
          ],
        );

    switch (entry.confirmState) {
      case BayConfirmState.confirmed || BayConfirmState.confirmedLate:
        final at = entry.slotConfirmedAt?.toLocal();
        final cell = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill.of(
              entry.confirmedSlotCode ?? '—',
              intent: StatusIntent.success,
              dense: true,
              showDot: false,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: 2),
            if (entry.bayCorrected)
              note('Corrected by admin', t.text.link,
                  icon: Icons.verified_user_outlined)
            else if (entry.confirmState == BayConfirmState.confirmedLate)
              note('Confirmed late${at == null ? '' : ' · ${_time.format(at)}'}',
                  t.status.of(StatusIntent.warning).fg)
            else if (at != null)
              note(_time.format(at), t.text.tertiary),
          ],
        );
        return onOpen == null
            ? cell
            : Tooltip(
                message: 'See the confirm and any corrections',
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: AppRadii.fullAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: cell,
                  ),
                ),
              );
      case BayConfirmState.unconfirmed:
        return const StatusPill.of(
          'Unconfirmed',
          intent: StatusIntent.danger,
          dense: true,
          showDot: false,
          icon: Icons.error_outline,
        );
      case BayConfirmState.notYet:
        return Text('Not yet',
            style: text.bodyMedium?.copyWith(color: t.text.tertiary));
      case BayConfirmState.notCounted:
        return Text('—',
            style: text.bodyMedium?.copyWith(color: t.text.tertiary));
    }
  }
}

/// Shows the driver's confirm for [entry] and every correction since, and
/// lets an admin move it to the right bay. Returns true when it was corrected,
/// so the list can refresh.
Future<bool> showBayConfirmDialog(
  BuildContext context,
  ParkingLogEntry entry, {
  required bool canCorrect,
}) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _BayConfirmDialog(entry: entry, canCorrect: canCorrect),
  );
  return changed == true;
}

class _BayConfirmDialog extends ConsumerStatefulWidget {
  const _BayConfirmDialog({required this.entry, required this.canCorrect});

  final ParkingLogEntry entry;
  final bool canCorrect;

  @override
  ConsumerState<_BayConfirmDialog> createState() => _BayConfirmDialogState();
}

class _BayConfirmDialogState extends ConsumerState<_BayConfirmDialog> {
  late final Future<BayConfirmHistory> _history = _load();

  bool _correcting = false;
  bool _saving = false;
  String? _slotId;
  String? _error;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<BayConfirmHistory> _load() async {
    final res = await ref
        .read(dioProvider)
        .get(ApiEndpoints.parkingLogBayConfirm(widget.entry.id));
    return BayConfirmHistory.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> _save() async {
    final reason = _reason.text.trim();
    if (_slotId == null) {
      setState(() => _error = 'Pick the bay the vehicle was really in.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = 'Write why the bay is being corrected.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post(
            ApiEndpoints.parkingLogCorrectBay(widget.entry.id),
            data: {'slotId': _slotId, 'reason': reason},
          );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _saving = false;
        _error = data is Map && data['message'] != null
            ? data['message'].toString()
            : "Couldn't save the correction. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text('${widget.entry.userName} · bay confirm'),
      content: SizedBox(
        width: context.dialogWidth(440),
        child: FutureBuilder<BayConfirmHistory>(
          future: _history,
          builder: (context, snap) {
            if (snap.hasError) {
              return Text("Couldn't load the confirm history.",
                  style: text.bodyMedium?.copyWith(color: t.status.of(StatusIntent.danger).fg));
            }
            if (!snap.hasData) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final h = snap.data!;
            final confirmedAt = h.driverConfirmedAt?.toLocal();

            Widget line(String when, String what, {String? detail}) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(when,
                            style: AppTypography.tabular(text.bodySmall!)
                                .copyWith(color: t.text.tertiary)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(what, style: text.bodyMedium),
                            if (detail != null)
                              Text(detail,
                                  style: text.bodySmall
                                      ?.copyWith(color: t.text.tertiary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (h.driverSlotCode != null)
                  line(
                    confirmedAt == null ? '' : _stamp.format(confirmedAt),
                    'Driver confirmed ${h.driverSlotCode}',
                    detail: h.state == BayConfirmState.confirmedLate
                        ? 'Confirmed after leaving'
                        : null,
                  ),
                for (final c in h.corrections)
                  line(
                    _stamp.format(c.correctedAt.toLocal()),
                    'Admin moved it from ${c.fromSlotCode} to ${c.toSlotCode}',
                    detail: 'Reason: ${c.reason}\nBy: ${c.correctedByName}',
                  ),
                if (widget.canCorrect && h.state.isConfirmed) ...[
                  const Divider(),
                  if (!_correcting)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.edit_location_alt_outlined,
                            size: AppSizes.iconSm),
                        label: const Text('Correct bay'),
                        onPressed: () => setState(() => _correcting = true),
                      ),
                    )
                  else
                    _CorrectionForm(
                      currentCode: h.currentSlotCode,
                      slotId: _slotId,
                      reason: _reason,
                      error: _error,
                      onSlot: (id) => setState(() {
                        _slotId = id;
                        _error = null;
                      }),
                      onReasonChanged: () {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(_correcting ? 'Cancel' : 'Close'),
        ),
        if (_correcting)
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save correction'),
          ),
      ],
    );
  }
}

class _CorrectionForm extends ConsumerWidget {
  const _CorrectionForm({
    required this.currentCode,
    required this.slotId,
    required this.reason,
    required this.error,
    required this.onSlot,
    required this.onReasonChanged,
  });

  final String? currentCode;
  final String? slotId;
  final TextEditingController reason;
  final String? error;
  final ValueChanged<String?> onSlot;
  final VoidCallback onReasonChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final slots = ref.watch(parkingSlotsProvider).valueOrNull?.slots ??
        const <ParkingSlot>[];
    final choices = [...slots.where((s) => s.slotCode != currentCode)]
      ..sort((a, b) => a.slotCode.compareTo(b.slotCode));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Move this visit from ${currentCode ?? 'its bay'} to the bay the '
          'vehicle was really in. The driver\'s own answer is kept.',
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        ),
        const SizedBox(height: AppSpacing.x3),
        DropdownButtonFormField<String>(
          initialValue: slotId,
          decoration: const InputDecoration(labelText: 'Correct bay'),
          items: [
            for (final s in choices)
              DropdownMenuItem(
                value: s.slotId,
                child: Text('${s.slotCode} · Gate ${s.gate}'),
              ),
          ],
          onChanged: onSlot,
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: reason,
          maxLength: 500,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Sensor shows C4 empty, car seen in C5',
          ),
          onChanged: (_) => onReasonChanged(),
        ),
        if (error != null)
          Text(error!,
              style: text.bodySmall
                  ?.copyWith(color: t.status.of(StatusIntent.danger).fg)),
      ],
    );
  }
}
