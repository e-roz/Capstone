import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/ph_time.dart';
import '../models/parking_slot.dart';
import '../models/slot_history.dart';
import '../providers/slot_history_provider.dart';
import '../screens/violations_screen.dart' show showIssueViolationDialog;
import '../theme/theme.dart';
import 'parking/slot_history.dart';
import 'review_summary.dart';
import 'slot_confirmation_pill.dart';
import 'ui/ui.dart';
import 'user_picker.dart';

final _time = DateFormat('h:mm a');
final _when = DateFormat('MMM d, h:mm a');

/// How far before a report the lookup reaches. Damage is usually found some
/// time after it happened. The same six hours the user's page uses for
/// "possibly involved", so the two never disagree.
const incidentLookBack = Duration(hours: 6);

/// Who was in the bay an incident is about, when it was reported.
///
/// Reads as a conclusion first (who was inside at that moment), then shows the
/// same thing as a timeline and as one card per person, with the next step on
/// each card. It is evidence for the administrator to weigh, never a finding.
class IncidentLeadPanel extends ConsumerWidget {
  const IncidentLeadPanel({
    super.key,
    required this.slotId,
    required this.slotCode,
    required this.reportedAt,
    required this.incidentLabel,
  });

  final String slotId;
  final String slotCode;
  final DateTime reportedAt;

  /// "Vehicle damage", for the violation's starting description.
  final String incidentLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = SlotHistoryQuery(
      slotId,
      from: reportedAt.subtract(incidentLookBack),
      to: reportedAt,
    );
    final async = ref.watch(slotHistoryProvider(query));
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.x5),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Text(
        'Could not load who was in $slotCode.',
        style: text.bodyMedium?.copyWith(color: t.status.danger.fg),
      ),
      data: (h) {
        final leads = [for (final s in h.sessions) _Lead(s, reportedAt)]
          ..sort((a, b) => a.rank.compareTo(b.rank));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Summary(slotCode: slotCode, leads: leads),
            const SizedBox(height: AppSpacing.x3),
            if (leads.isNotEmpty) ...[
              _Timeline(leads: leads, reportedAt: reportedAt),
              const SizedBox(height: AppSpacing.x3),
              for (final lead in leads)
                _PersonCard(
                  lead: lead,
                  slotCode: slotCode,
                  reportedAt: reportedAt,
                  violationDescription:
                      '$incidentLabel reported in $slotCode on ${_when.format(manila(reportedAt))}.',
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Opens the bay's full history, with the slot's own numbers on the side.
class IncidentSlotSummary extends ConsumerWidget {
  const IncidentSlotSummary({
    super.key,
    required this.slotId,
    required this.slotCode,
    required this.reportedAt,
  });

  final String slotId;
  final String slotCode;
  final DateTime reportedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final history = ref
        .watch(slotHistoryProvider(SlotHistoryQuery(
          slotId,
          from: reportedAt.subtract(incidentLookBack),
          to: reportedAt,
        )))
        .valueOrNull;

    final violations = history?.violations.length ?? 0;
    final flags = history?.wrongBayFlags.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.x3),
          decoration: BoxDecoration(
            border: Border.all(color: t.border.subtle),
            borderRadius: AppRadii.smAll,
          ),
          child: Row(
            children: [
              Icon(
                violations + flags > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                size: AppSizes.iconMd,
                color: violations + flags > 0 ? t.status.warning.solid : t.status.success.solid,
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  history == null
                      ? 'Loading $slotCode…'
                      : violations + flags == 0
                          ? 'No violations or warnings in $slotCode around this time.'
                          : '$violations violation${violations == 1 ? '' : 's'} · '
                              '$flags wrong-bay warning${flags == 1 ? '' : 's'} in $slotCode around this time.',
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        OutlinedButton.icon(
          icon: const Icon(Icons.history, size: AppSizes.iconSm),
          label: Text('Open full history of $slotCode'),
          onPressed: () => showSlotHistoryDialog(
            context,
            ParkingSlot(
              slotId: slotId,
              slotCode: slotCode,
              gate: history?.gate ?? 1,
              vehicleType: history?.bayType,
              status: '',
            ),
          ),
        ),
      ],
    );
  }
}

/// One session in the bay, read against the moment of the report.
class _Lead {
  _Lead(this.session, DateTime reportedAt)
      : insideAtReport = session.exitTime == null || !session.exitTime!.isBefore(reportedAt),
        leftBefore = session.exitTime == null || !session.exitTime!.isBefore(reportedAt)
            ? null
            : reportedAt.difference(session.exitTime!);

  final SlotSession session;
  final bool insideAtReport;

  /// How long before the report they left, when they had.
  final Duration? leftBefore;

  /// Inside at the time first, then the ones who left most recently.
  int get rank => insideAtReport ? 0 : 1 + (leftBefore?.inMinutes ?? 0);

  StatusIntent get intent => insideAtReport
      ? StatusIntent.danger
      : session.isConfirmed
          ? StatusIntent.success
          : StatusIntent.warning;
}

String _confirmation(SlotSession s, String slotCode) =>
    switch (SlotConfirmation.of(confirmedAt: s.confirmedAt, exitTime: s.exitTime)) {
      SlotConfirmation.confirmed => 'confirmed $slotCode',
      SlotConfirmation.late => 'confirmed $slotCode after leaving',
      SlotConfirmation.none => 'did not confirm the bay',
    };

String _ago(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

class _Summary extends StatelessWidget {
  const _Summary({required this.slotCode, required this.leads});

  final String slotCode;
  final List<_Lead> leads;

  @override
  Widget build(BuildContext context) {
    final inside = leads.where((l) => l.insideAtReport).toList();
    final hours = incidentLookBack.inHours;

    final (intent, icon, headline, detail) = leads.isEmpty
        ? (
            StatusIntent.neutral,
            Icons.person_off_outlined,
            'Nobody was recorded in $slotCode in the $hours hours before this report.',
            'The bay may have been used without a session being logged. Check the camera or ask the guard.',
          )
        : inside.isNotEmpty
            ? (
                StatusIntent.danger,
                Icons.person_pin_circle_outlined,
                '${inside.length == 1 ? inside.first.session.userName : '${inside.length} people'} '
                    '${inside.length == 1 ? 'was' : 'were'} inside $slotCode when this was reported.',
                leads.length == inside.length
                    ? 'This is a lead, not a finding.'
                    : '${leads.length - inside.length} more used the bay in the $hours hours before. This is a lead, not a finding.',
              )
            : (
                StatusIntent.warning,
                Icons.history_toggle_off,
                'Nobody was inside $slotCode when this was reported.',
                '${leads.length} ${leads.length == 1 ? 'person' : 'people'} used it in the $hours hours before; '
                    'the last left ${_ago(leads.first.leftBefore ?? Duration.zero)} earlier. This is a lead, not a finding.',
              );

    return ReviewSummary(intent: intent, icon: icon, headline: headline, detail: detail);
  }
}

/// Six hours before the report, one bar per person, and a mark where it was
/// reported. A bar touching the mark was there when it happened.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.leads, required this.reportedAt});

  final List<_Lead> leads;
  final DateTime reportedAt;

  static const _lane = 28.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final start = reportedAt.subtract(incidentLookBack);
    final span = incidentLookBack.inMilliseconds.toDouble();
    final shown = leads.take(6).toList();
    final height = shown.length * _lane + 8;

    double at(DateTime x) =>
        (x.difference(start).inMilliseconds / span).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: AppRadii.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                return Stack(
                  children: [
                    for (final (i, lead) in shown.indexed)
                      () {
                        final from = at(lead.session.entryTime);
                        final to = lead.session.exitTime == null ? 1.0 : at(lead.session.exitTime!);
                        final c = t.status.of(lead.intent);
                        final left = from * w;
                        final width = ((to - from) * w).clamp(6.0, w);
                        return Positioned(
                          left: left,
                          top: 4 + i * _lane,
                          width: width,
                          height: _lane - 6,
                          child: Tooltip(
                            message: '${lead.session.userName}: '
                                '${_time.format(manila(lead.session.entryTime))} to '
                                '${lead.session.exitTime == null ? 'still inside' : _time.format(manila(lead.session.exitTime!))}',
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                              decoration: BoxDecoration(
                                color: c.bg,
                                border: Border.all(color: c.solid),
                                borderRadius: AppRadii.smAll,
                              ),
                              child: Text(
                                lead.session.userName.split(' ').first,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: text.labelSmall?.copyWith(color: c.fg, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        );
                      }(),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 2,
                      child: ColoredBox(color: t.status.danger.solid),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_time.format(manila(start)),
                  style: text.labelSmall?.copyWith(color: t.text.tertiary)),
              Text('Reported ${_time.format(manila(reportedAt))}',
                  style: text.labelSmall?.copyWith(
                      color: t.status.danger.fg, fontWeight: FontWeight.w700)),
            ],
          ),
          if (leads.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x1),
              child: Text('+${leads.length - shown.length} more below',
                  style: text.labelSmall?.copyWith(color: t.text.tertiary)),
            ),
        ],
      ),
    );
  }
}

class _PersonCard extends ConsumerWidget {
  const _PersonCard({
    required this.lead,
    required this.slotCode,
    required this.reportedAt,
    required this.violationDescription,
  });

  final _Lead lead;
  final String slotCode;
  final DateTime reportedAt;
  final String violationDescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = lead.session;
    final c = t.status.of(lead.intent);
    final initials = s.userName.trim().isEmpty
        ? '?'
        : s.userName.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();

    final when = '${s.plateNumber == null ? '' : '${s.plateNumber} · '}'
        'in ${_time.format(manila(s.entryTime))}'
        '${s.exitTime == null ? ', still inside' : ', out ${_time.format(manila(s.exitTime!))}'}'
        ' · ${_confirmation(s, slotCode)}';

    final userId = s.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x2),
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        border: Border.all(color: lead.insideAtReport ? c.border : t.border.subtle),
        borderRadius: AppRadii.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
                child: Text(initials,
                    style: text.labelMedium?.copyWith(color: c.fg, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.x2,
                      runSpacing: AppSpacing.x1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(s.isVisitor ? '${s.userName} (visitor)' : s.userName,
                            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                        StatusPill.of(
                          lead.insideAtReport
                              ? 'Inside when reported'
                              : 'Left ${_ago(lead.leftBefore ?? Duration.zero)} before',
                          intent: lead.insideAtReport ? StatusIntent.danger : StatusIntent.neutral,
                          showDot: false,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(when, style: text.bodySmall?.copyWith(color: t.text.secondary)),
                  ],
                ),
              ),
            ],
          ),
          if (userId != null) ...[
            const SizedBox(height: AppSpacing.x2),
            Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline, size: AppSizes.iconSm),
                  label: const Text('View profile'),
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.go('/users/$userId');
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.status.danger.fg,
                    side: BorderSide(color: t.status.danger.border),
                  ),
                  icon: const Icon(Icons.gavel_outlined, size: AppSizes.iconSm),
                  label: const Text('Create violation'),
                  onPressed: () => showIssueViolationDialog(
                    context,
                    ref,
                    description: violationDescription,
                    user: PickedUser(userId: userId, fullName: s.userName, email: ''),
                    parkingLogId: s.logId,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
