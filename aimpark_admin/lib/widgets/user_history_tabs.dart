import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/ph_time.dart';
import '../models/investigation.dart';
import '../models/user_history.dart';
import '../providers/investigation_provider.dart';
import '../providers/user_history_provider.dart';
import '../theme/theme.dart';
import '../screens/incidents_screen.dart' show openIncidentReport;
import 'slot_confirmation_pill.dart';
import 'ui/ui.dart';
import 'violation_detail_dialog.dart';

final _when = DateFormat('MMM d, h:mm a');
final _day = DateFormat('MMM d, yyyy');
final _peso = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

/// "UnderReview" as "Under review": the API sends enum names as they are.
String _words(String name) => name
    .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
    .toLowerCase()
    .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase());

/// The tabs on a user's detail page.
enum UserTab { overview, parking, violations, incidents, payments, taps }

/// The four numbers that matter at a glance, and the tab strip under them. The
/// strip carries each list's count, so the admin sees where there is something
/// to read without opening anything.
class UserHistoryHeader extends ConsumerWidget {
  const UserHistoryHeader({
    super.key,
    required this.userId,
    required this.selected,
    required this.onSelect,
  });

  final String userId;
  final UserTab selected;
  final ValueChanged<UserTab> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(userHistorySummaryProvider(userId)).valueOrNull;

    String? count(UserTab tab) {
      if (summary == null) return null;
      return switch (tab) {
        UserTab.overview => null,
        UserTab.parking => '${summary.sessions}',
        UserTab.violations => '${summary.violations}',
        UserTab.incidents => '${summary.incidents}',
        UserTab.payments => summary.owed > 0 ? '${_peso.format(summary.owed)} owed' : null,
        UserTab.taps => '${summary.taps}',
      };
    }

    // What the count pill says about the tab: red when there is something to
    // deal with, amber when it is only a lead, blue for plain history.
    StatusIntent countIntent(UserTab tab) {
      if (summary == null) return StatusIntent.neutral;
      return switch (tab) {
        UserTab.overview => StatusIntent.neutral,
        UserTab.parking => StatusIntent.info,
        UserTab.violations => summary.violations > 0 ? StatusIntent.danger : StatusIntent.neutral,
        UserTab.incidents => summary.incidentsPossible > 0
            ? StatusIntent.warning
            : summary.incidents > 0
                ? StatusIntent.info
                : StatusIntent.neutral,
        UserTab.payments => StatusIntent.danger,
        UserTab.taps => StatusIntent.neutral,
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary != null) _SummaryCards(summary: summary),
        if (summary != null) const SizedBox(height: AppSpacing.x3),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tab in UserTab.values)
                _TabButton(
                  label: _tabLabels[tab]!,
                  icon: _tabIcons[tab]!,
                  color: _tabColors[tab]!,
                  count: count(tab),
                  countIntent: countIntent(tab),
                  selected: tab == selected,
                  onTap: () => onSelect(tab),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: context.tokens.border.subtle),
      ],
    );
  }
}

const _tabLabels = {
  UserTab.overview: 'Overview',
  UserTab.parking: 'Parking history',
  UserTab.violations: 'Violations',
  UserTab.incidents: 'Incidents',
  UserTab.payments: 'Payments',
  UserTab.taps: 'Gate taps',
};

const _tabIcons = {
  UserTab.overview: Icons.dashboard_outlined,
  UserTab.parking: Icons.local_parking_outlined,
  UserTab.violations: Icons.gavel_outlined,
  UserTab.incidents: Icons.report_gmailerrorred_outlined,
  UserTab.payments: Icons.payments_outlined,
  UserTab.taps: Icons.nfc,
};

/// One colour per tab, so the same kind of thing is the same colour here, in
/// the list below it and on the pills.
const _tabColors = {
  UserTab.overview: StatusIntent.accent,
  UserTab.parking: StatusIntent.info,
  UserTab.violations: StatusIntent.danger,
  UserTab.incidents: StatusIntent.warning,
  UserTab.payments: StatusIntent.success,
  UserTab.taps: StatusIntent.accent,
};

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final UserHistorySummary summary;

  @override
  Widget build(BuildContext context) {
    final inside = summary.isInside
        // A bay the driver has not confirmed is only the gate's suggestion, so
        // it is not named as if it were where they are.
        ? (summary.insideSlotCode == null || !summary.insideSlotConfirmed
            ? 'Inside'
            : 'Slot ${summary.insideSlotCode}')
        : 'Not parked';

    return Wrap(
      spacing: AppSpacing.x3,
      runSpacing: AppSpacing.x3,
      children: [
        _Metric(
          label: 'Inside now',
          value: inside,
          icon: Icons.local_parking,
          intent: summary.isInside ? StatusIntent.success : StatusIntent.neutral,
        ),
        _Metric(
          label: 'Sessions',
          value: '${summary.sessions}',
          icon: Icons.history,
          intent: StatusIntent.info,
        ),
        _Metric(
          label: 'Bay confirmed',
          value: '${summary.sessionsConfirmed} of ${summary.sessions}',
          icon: Icons.pin_drop_outlined,
          // Someone who never says where they parked cannot be placed when
          // something happens, so a record of never doing it is worth noticing.
          intent: summary.sessions >= 3 && summary.sessionsConfirmed == 0
              ? StatusIntent.warning
              : StatusIntent.info,
        ),
        _Metric(
          label: 'Violations',
          value: '${summary.violations}',
          icon: Icons.gavel,
          intent: summary.violations > 0 ? StatusIntent.danger : StatusIntent.success,
        ),
        _Metric(
          label: 'Owes',
          value: _peso.format(summary.owed),
          icon: Icons.payments,
          intent: summary.owed > 0 ? StatusIntent.danger : StatusIntent.success,
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.intent,
    this.icon,
  });

  final String label;
  final String value;
  final StatusIntent intent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(intent);

    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconMd, color: c.solid),
            const SizedBox(width: AppSpacing.x2),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall?.copyWith(color: c.fg)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: c.fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.countIntent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final StatusIntent color;
  final String? count;
  final StatusIntent countIntent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final solid = t.status.of(color).solid;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(width: 2, color: selected ? solid : Colors.transparent),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSizes.iconSm, color: solid),
            const SizedBox(width: AppSpacing.x2),
            Text(
              label,
              style: text.bodyMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? t.text.primary : t.text.secondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: AppSpacing.x1),
              StatusPill.of(count!, intent: countIntent, showDot: false, dense: true),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Parking history ──────────────────────────────────────────────────────────

enum _Range {
  week('7 days', 7),
  month('30 days', 30),
  all('All', null);

  const _Range(this.label, this.days);
  final String label;
  final int? days;

  DateTime? start() =>
      days == null ? null : DateTime.now().toUtc().subtract(Duration(days: days!));
}

class UserParkingTab extends ConsumerStatefulWidget {
  const UserParkingTab({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserParkingTab> createState() => _UserParkingTabState();
}

class _UserParkingTabState extends ConsumerState<UserParkingTab> {
  _Range _range = _Range.all;
  int _page = 1;

  // The window is fixed when the range is picked, so the request key does not
  // change on every rebuild.
  DateTime? _from;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userSessionsProvider(
        UserListQuery(widget.userId, page: _page, from: _from)));

    return AppSectionCard(
      title: 'Parking history',
      icon: Icons.local_parking_outlined,
      actions: [
        SegmentedButton<_Range>(
          showSelectedIcon: false,
          segments: [
            for (final r in _Range.values) ButtonSegment(value: r, label: Text(r.label)),
          ],
          selected: {_range},
          onSelectionChanged: (s) => setState(() {
            _range = s.first;
            _from = _range.start();
            _page = 1;
          }),
        ),
      ],
      child: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(userSessionsProvider),
        loading: const _Loading(),
        data: (page) => _ListBody(
          empty: 'No parking sessions in this period.',
          isEmpty: page.items.isEmpty,
          rows: [for (final s in page.items) _SessionRow(session: s)],
          footer: AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.total,
            itemLabel: 'sessions',
            onPage: (p) => setState(() => _page = p),
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final UserSessionItem session;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final inside = session.exitTime == null;

    return _Row(
      intent: inside
          ? StatusIntent.success
          : session.plateMatched == false
              ? StatusIntent.danger
              : session.slotCode != null && !session.slotConfirmed
                  ? StatusIntent.warning
                  : StatusIntent.info,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In ${_when.format(manila(session.entryTime))}'
                  '${session.gate == null ? '' : ' · Gate ${session.gate}'}',
                  style: text.bodyMedium,
                ),
                Text(
                  inside ? 'Still inside' : 'Out ${_when.format(manila(session.exitTime!))}',
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
          if (session.plate != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x3),
              child: Text(session.plate!,
                  style: text.labelMedium?.copyWith(color: t.text.secondary)),
            ),
          if (session.plateMatched == false)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.x2),
              child: StatusPill.of('Mismatch',
                  intent: StatusIntent.danger, showDot: false, dense: true),
            ),
          if (session.slotCode != null) ...[
            StatusPill.of(session.slotCode!,
                intent: StatusIntent.accent, showDot: false, dense: true),
            const SizedBox(width: AppSpacing.x2),
            SlotConfirmationPill(
              confirmedAt: session.slotConfirmedAt,
              exitTime: session.exitTime,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Violations ───────────────────────────────────────────────────────────────

class UserViolationsTab extends ConsumerStatefulWidget {
  const UserViolationsTab({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserViolationsTab> createState() => _UserViolationsTabState();
}

class _UserViolationsTabState extends ConsumerState<UserViolationsTab> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userViolationsProvider(UserListQuery(widget.userId, page: _page)));

    return AppSectionCard(
      title: 'Violations',
      icon: Icons.gavel_outlined,
      child: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(userViolationsProvider),
        loading: const _Loading(),
        data: (page) => _ListBody(
          empty: 'No violations.',
          isEmpty: page.items.isEmpty,
          rows: [for (final v in page.items) _ViolationRow(violation: v, onTap: () => showViolationDetail(context, v.id))],
          footer: AppPagination(
            page: page.page,
            pageSize: page.pageSize,
            total: page.total,
            itemLabel: 'violations',
            onPage: (p) => setState(() => _page = p),
          ),
        ),
      ),
    );
  }
}

class _ViolationRow extends StatelessWidget {
  const _ViolationRow({required this.violation, required this.onTap});

  final UserViolationItem violation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final where = violation.slotCode == null
        ? null
        : 'Slot ${violation.slotCode}'
            '${violation.sessionEntry == null ? '' : ' · session ${_day.format(manila(violation.sessionEntry!))}'}';

    return _Row(
      intent: _violationIntent(violation.status),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(violation.ruleTitle, style: text.bodyMedium),
                Text(
                  [_day.format(manila(violation.createdAt)), ?where].join(' · '),
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
          if (violation.penaltyAmount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x3),
              child: Text(_peso.format(violation.penaltyAmount),
                  style: text.labelMedium?.copyWith(color: t.text.secondary)),
            ),
          StatusPill.of(
            _words(violation.status),
            intent: switch (violation.status) {
              'Accountable' => StatusIntent.danger,
              'Dismissed' => StatusIntent.neutral,
              _ => StatusIntent.warning,
            },
            showDot: false,
            dense: true,
          ),
        ],
      ),
    );
  }
}

// ── Incidents ────────────────────────────────────────────────────────────────

class UserIncidentsTab extends ConsumerWidget {
  const UserIncidentsTab({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userIncidentsProvider(userId));
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppSectionCard(
      title: 'Incidents',
      icon: Icons.report_gmailerrorred_outlined,
      child: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(userIncidentsProvider(userId)),
        loading: const _Loading(),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filed by this person',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.x1),
            if (data.filed.isEmpty)
              Text('No reports filed.',
                  style: text.bodyMedium?.copyWith(color: t.text.secondary))
            else
              for (final i in data.filed) _IncidentRow(incident: i, onTap: () => openIncidentReport(context, ref, i.id, i.status)),
            const SizedBox(height: AppSpacing.x5),
            Text('Possibly involved',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.x1),
            if (data.possiblyInvolved.isEmpty)
              Text('No reports about a bay this person was in.',
                  style: text.bodyMedium?.copyWith(color: t.text.secondary))
            else ...[
              for (final i in data.possiblyInvolved) _IncidentRow(
                incident: i,
                involved: true,
                onTap: () => openIncidentReport(context, ref, i.id, i.status),
              ),
              const SizedBox(height: AppSpacing.x3),
              Container(
                padding: const EdgeInsets.all(AppSpacing.x3),
                decoration: BoxDecoration(
                  color: t.status.warning.bg,
                  borderRadius: AppRadii.smAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: AppSizes.iconSm, color: t.status.warning.fg),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Text(
                        'These are reports about a bay this person was parked in around the '
                        'time it was reported. That is a lead, not proof. The administrator decides.',
                        style: text.bodySmall?.copyWith(color: t.status.warning.fg),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.incident, required this.onTap, this.involved = false});

  final UserIncidentItem incident;
  final VoidCallback onTap;
  final bool involved;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final where = incident.slotCode ?? incident.location;

    return _Row(
      intent: involved ? StatusIntent.warning : _incidentIntent(incident.status),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [incident.category, ?where].join(' · '),
                  style: text.bodyMedium,
                ),
                Text(
                  involved && incident.involvedEntry != null
                      ? 'Reported ${_when.format(manila(incident.createdAt))} · '
                          'in the bay from ${_when.format(manila(incident.involvedEntry!))}'
                          '${incident.involvedExit == null ? ', still inside' : ''}'
                          '${incident.involvedConfirmed ? '' : ' (unconfirmed)'}'
                      : 'Reported ${_when.format(manila(incident.createdAt))}',
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
          StatusPill.of(
            _words(incident.status),
            intent: switch (incident.status) {
              'Resolved' => StatusIntent.success,
              'Dismissed' || 'Withdrawn' => StatusIntent.neutral,
              _ => StatusIntent.warning,
            },
            showDot: false,
            dense: true,
          ),
        ],
      ),
    );
  }
}

// ── Payments ─────────────────────────────────────────────────────────────────

class UserPaymentsTab extends ConsumerStatefulWidget {
  const UserPaymentsTab({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserPaymentsTab> createState() => _UserPaymentsTabState();
}

class _UserPaymentsTabState extends ConsumerState<UserPaymentsTab> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userPaymentsProvider(UserListQuery(widget.userId, page: _page)));
    final summary = ref.watch(userHistorySummaryProvider(widget.userId)).valueOrNull;

    return AppSectionCard(
      title: 'Payments',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary != null) ...[
            Wrap(
              spacing: AppSpacing.x3,
              runSpacing: AppSpacing.x3,
              children: [
                _Metric(
                  label: 'Owed now',
                  value: _peso.format(summary.owed),
                  icon: Icons.account_balance_wallet_outlined,
                  intent: summary.owed > 0 ? StatusIntent.danger : StatusIntent.success,
                ),
                _Metric(
                  label: 'Paid this year',
                  value: _peso.format(summary.paidThisYear),
                  icon: Icons.check_circle_outline,
                  intent: StatusIntent.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),
          ],
          AsyncView(
            value: async,
            onRetry: () => ref.invalidate(userPaymentsProvider),
            loading: const _Loading(),
            data: (page) => _ListBody(
              empty: 'No payments yet.',
              isEmpty: page.items.isEmpty,
              rows: [for (final p in page.items) _PaymentRow(payment: p)],
              footer: AppPagination(
                page: page.page,
                pageSize: page.pageSize,
                total: page.total,
                itemLabel: 'payments',
                onPage: (p) => setState(() => _page = p),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final UserPaymentItem payment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return _Row(
      intent: _paymentIntent(payment.status),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.purpose, style: text.bodyMedium),
                Text(
                  payment.paidAt == null
                      ? _when.format(manila(payment.createdAt))
                      : 'Paid ${_when.format(manila(payment.paidAt!))}',
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.x3),
            child: Text(_peso.format(payment.amount),
                style: text.labelMedium?.copyWith(color: t.text.secondary)),
          ),
          StatusPill.of(
            _words(payment.status),
            intent: switch (payment.status) {
              'Paid' => StatusIntent.success,
              'Pending' => StatusIntent.warning,
              'Processing' => StatusIntent.info,
              _ => StatusIntent.neutral,
            },
            showDot: false,
            dense: true,
          ),
        ],
      ),
    );
  }
}

// ── Gate taps ────────────────────────────────────────────────────────────────

/// The latest taps on this person's card. The full log lives on the Gate Taps
/// page; this is what the profile endpoint already returns.
class UserTapsTab extends ConsumerWidget {
  const UserTapsTab({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
        investigationProfileProvider(InvestigationSubject(userId: userId)));
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppSectionCard(
      title: 'Gate taps',
      icon: Icons.nfc,
      child: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(investigationProfileProvider),
        loading: const _Loading(),
        data: (profile) => _ListBody(
          empty: 'No gate taps.',
          isEmpty: profile.taps.isEmpty,
          rows: [
            for (final tap in profile.taps)
              _Row(
                intent: tap.opened ? StatusIntent.success : StatusIntent.danger,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_when.format(manila(tap.at))} · Gate ${tap.gate}'
                            '${tap.direction == '-' ? '' : ' · ${tap.direction}'}',
                            style: text.bodyMedium,
                          ),
                          Text(tap.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(color: t.text.secondary)),
                        ],
                      ),
                    ),
                    StatusPill.of(
                      tap.opened ? 'Opened' : 'Denied',
                      intent: tap.opened ? StatusIntent.success : StatusIntent.danger,
                      showDot: false,
                      dense: true,
                    ),
                  ],
                ),
              ),
          ],
          footer: Text(
            'Latest ${profile.taps.length} of ${profile.totals.taps}. The Gate Taps page has the full log.',
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        ),
      ),
    );
  }
}

// ── Shared bits ──────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(AppSpacing.x5),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.empty,
    required this.isEmpty,
    required this.rows,
    required this.footer,
  });

  final String empty;
  final bool isEmpty;
  final List<Widget> rows;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
            child: Text(empty, style: text.bodyMedium?.copyWith(color: t.text.secondary)),
          )
        else
          ...rows,
        const SizedBox(height: AppSpacing.x3),
        footer,
      ],
    );
  }
}

/// One line of a list. The coloured edge says at a glance how the row stands:
/// green is fine or still in progress, amber needs a look, red is a problem,
/// blue is plain history.
class _Row extends StatelessWidget {
  const _Row({required this.child, this.intent = StatusIntent.neutral, this.onTap});

  final Widget child;
  final StatusIntent intent;

  /// When set, the whole row opens something and shows a chevron to say so.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2, horizontal: AppSpacing.x3),
      decoration: BoxDecoration(
        color: t.status.of(intent).bg.withValues(alpha: 0.35),
        borderRadius: AppRadii.smAll,
        border: Border(left: BorderSide(width: 3, color: t.status.of(intent).solid)),
      ),
      child: onTap == null
          ? child
          : Row(
              children: [
                Expanded(child: child),
                const SizedBox(width: AppSpacing.x2),
                Icon(Icons.chevron_right, size: AppSizes.iconMd, color: t.text.tertiary),
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x1),
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: AppRadii.smAll, child: content),
    );
  }
}

StatusIntent _violationIntent(String status) => switch (status) {
      'Accountable' => StatusIntent.danger,
      'Dismissed' => StatusIntent.neutral,
      _ => StatusIntent.warning,
    };

StatusIntent _incidentIntent(String status) => switch (status) {
      'Resolved' => StatusIntent.success,
      'Dismissed' || 'Withdrawn' => StatusIntent.neutral,
      'UnderReview' => StatusIntent.info,
      _ => StatusIntent.warning,
    };

StatusIntent _paymentIntent(String status) => switch (status) {
      'Paid' => StatusIntent.success,
      'Pending' => StatusIntent.danger,
      'Processing' => StatusIntent.info,
      _ => StatusIntent.neutral,
    };
