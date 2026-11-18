import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ph_time.dart';
import '../../models/parking_slot.dart';
import '../../models/slot_history.dart';
import '../../providers/slot_history_provider.dart';
import '../../theme/theme.dart';
import '../slot_confirmation_pill.dart';
import '../ui/ui.dart';
import 'time_parked.dart';

final _short = DateFormat('MMM d, h:mm a');
final _time = DateFormat('h:mm a');
final _peso = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

/// How far back the bay's history reaches in the dialog.
enum _Range {
  today('Today'),
  week('7 days'),
  all('All');

  const _Range(this.label);
  final String label;

  /// Start of the window, in the clock the panel shows. Null reaches back to
  /// the beginning. Sent to the server in UTC.
  DateTime? start() => switch (this) {
        _Range.today => () {
            final now = manilaNow();
            // Midnight in Manila, back to the UTC instant the server compares.
            return DateTime.utc(now.year, now.month, now.day)
                .subtract(const Duration(hours: 8));
          }(),
        _Range.week => DateTime.now().toUtc().subtract(const Duration(days: 7)),
        _Range.all => null,
      };
}

/// Opens the history of one bay over the page: who is in it now and who has
/// been in it before. [onChangeStatus] adds the administrator's "Change
/// status" button; a guard sees the history only.
Future<void> showSlotHistoryDialog(
  BuildContext context,
  ParkingSlot slot, {
  VoidCallback? onChangeStatus,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SlotHistoryDialog(slot: slot, onChangeStatus: onChangeStatus),
  );
}

class _SlotHistoryDialog extends ConsumerStatefulWidget {
  const _SlotHistoryDialog({required this.slot, this.onChangeStatus});

  final ParkingSlot slot;
  final VoidCallback? onChangeStatus;

  @override
  ConsumerState<_SlotHistoryDialog> createState() => _SlotHistoryDialogState();
}

class _SlotHistoryDialogState extends ConsumerState<_SlotHistoryDialog> {
  _Range _range = _Range.today;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final query = SlotHistoryQuery(widget.slot.slotId, from: _range.start());

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Slot ${widget.slot.slotCode}',
                        style: text.titleLarge),
                  ),
                  if (widget.onChangeStatus != null)
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onChangeStatus!();
                      },
                      child: const Text('Change status'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              SegmentedButton<_Range>(
                showSelectedIcon: false,
                segments: [
                  for (final r in _Range.values)
                    ButtonSegment(value: r, label: Text(r.label)),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
              const SizedBox(height: AppSpacing.x3),
              Flexible(
                child: SingleChildScrollView(
                  child: SlotHistoryBody(query: query),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who is in a bay now, who has been, and any violations or wrong-bay warnings
/// raised there. Shared by the bay dialog and the incident's lookup.
class SlotHistoryBody extends ConsumerWidget {
  const SlotHistoryBody({super.key, required this.query, this.showCurrent = true});

  final SlotHistoryQuery query;

  /// The incident lookup is about a moment in the past, so who is in the bay
  /// today would only mislead.
  final bool showCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final history = ref.watch(slotHistoryProvider(query));

    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.x5),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Text('Could not load this bay\'s history.',
            style: text.bodyMedium?.copyWith(color: t.status.danger.solid)),
      ),
      data: (h) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCurrent) ...[
            _Label('In the bay now'),
            if (h.current == null)
              Text('Nobody has claimed this bay.',
                  style: text.bodyMedium?.copyWith(color: t.text.secondary))
            else
              _CurrentOccupant(session: h.current!),
            const SizedBox(height: AppSpacing.x4),
          ],
          _Label('Sessions · ${h.sessions.length}${h.truncated ? '+' : ''}'),
          if (h.sessions.isEmpty)
            Text('No sessions in this period.',
                style: text.bodyMedium?.copyWith(color: t.text.secondary))
          else
            for (final s in h.sessions) _SessionRow(session: s),
          if (h.truncated)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x2),
              child: Text('Showing the latest sessions. Narrow the period to see older ones.',
                  style: text.bodySmall?.copyWith(color: t.text.tertiary)),
            ),
          if (h.violations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            _Label('Violations · ${h.violations.length}'),
            for (final v in h.violations) _ViolationRow(violation: v),
          ],
          if (h.wrongBayFlags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            _Label('Wrong-bay warnings · ${h.wrongBayFlags.length}'),
            for (final f in h.wrongBayFlags)
              _Row(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_short.format(manila(f.detectedAt)),
                          style: text.bodyMedium),
                    ),
                    StatusPill.of(f.status,
                        intent: f.status == 'Confirmed'
                            ? StatusIntent.danger
                            : StatusIntent.neutral,
                        showDot: false,
                        dense: true),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x2),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.tokens.border.subtle)),
        ),
        child: child,
      );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final SlotSession session;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return _Row(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.isVisitor ? '${session.userName} (visitor)' : session.userName,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'In ${_short.format(manila(session.entryTime))} · '
                  '${session.isInside ? 'still inside' : 'out ${_short.format(manila(session.exitTime!))}'}',
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
          if (session.plateNumber != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x3),
              child: Text(session.plateNumber!,
                  style: AppTypography.tabular(
                      text.labelMedium!.copyWith(color: t.text.secondary))),
            ),
          // How long they stayed, or have stayed so far.
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.x3),
                child: TimeParked(
                  since: session.entryTime,
                  until: session.exitTime,
                  style: AppTypography.tabular(text.labelMedium!),
                ),
              ),
            ),
          ),
          // The bay on an unconfirmed session is only the gate's suggestion,
          // so it must not read as proof of where the car was.
          SlotConfirmationPill(
            confirmedAt: session.confirmedAt,
            exitTime: session.exitTime,
          ),
        ],
      ),
    );
  }
}

/// Whoever is in the bay right now, set apart from the history: name, plate,
/// when they came in and confirmed the bay, and a running time.
class _CurrentOccupant extends StatelessWidget {
  const _CurrentOccupant({required this.session});

  final SlotSession session;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(StatusIntents.slot('Occupied'));
    final name = session.isVisitor ? '${session.userName} (visitor)' : session.userName;
    final initials = session.userName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final details = [
      ?session.plateNumber,
      'In ${_time.format(manila(session.entryTime))}',
      session.confirmedAt == null
          ? 'bay not confirmed'
          : 'confirmed ${_time.format(manila(session.confirmedAt!))}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: AppRadii.smAll,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: c.solid,
            child: Text(initials.isEmpty ? '?' : initials,
                style: text.labelLarge?.copyWith(color: t.text.onBrand)),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: c.fg)),
                Text(details, style: text.bodySmall?.copyWith(color: c.fg)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TimeParked(
                since: session.entryTime,
                style: AppTypography.tabular(
                    text.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: c.fg)),
              ),
              const SizedBox(height: 2),
              SlotConfirmationPill(confirmedAt: session.confirmedAt, exitTime: null),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViolationRow extends StatelessWidget {
  const _ViolationRow({required this.violation});

  final SlotViolation violation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return _Row(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(violation.ruleTitle, style: text.bodyMedium),
                Text('${violation.userName} · ${_short.format(manila(violation.createdAt))}',
                    style: text.bodySmall?.copyWith(color: t.text.secondary)),
              ],
            ),
          ),
          if (violation.penaltyAmount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x2),
              child: Text(_peso.format(violation.penaltyAmount),
                  style: text.labelMedium?.copyWith(color: t.text.secondary)),
            ),
          StatusPill.of(violation.status,
              intent: StatusIntent.neutral, showDot: false, dense: true),
        ],
      ),
    );
  }
}
