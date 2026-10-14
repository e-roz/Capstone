import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/ph_time.dart';
import '../models/gate_tap_event.dart';
import '../models/investigation.dart';
import '../models/violation.dart';
import '../providers/investigation_provider.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

final _when = DateFormat('MMM d, yyyy · h:mm:ss a');
final _short = DateFormat('MMM d, h:mm a');
final _peso = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

/// Opens the investigation panel over the page, from the right.
///
/// [subject] says whose profile to load. [tap] is the one gate tap that led
/// here, if any: it gets its own box at the top so the question that brought
/// the admin ("why was this refused?") is answered before the history. Pass a
/// null [subject] when the tap points at nobody (no card, no plate): only the
/// tap is shown.
Future<void> showInvestigationPanel(
  BuildContext context, {
  InvestigationSubject? subject,
  GateTapEvent? tap,
  String? title,
}) {
  assert(subject != null || tap != null);
  final router = GoRouter.of(context);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black38,
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        elevation: 16,
        color: context.tokens.surface.card,
        child: SizedBox(
          width: 480,
          height: double.infinity,
          child: InvestigationPanel(
            subject: subject,
            tap: tap,
            title: title,
            onOpenRoute: (location) {
              Navigator.of(context).pop();
              router.go(location);
            },
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: AppMotion.standard),
      ),
      child: child,
    ),
  );
}

/// What the system holds about one person, visitor card, unknown card or
/// unregistered plate, with the tap that raised the question on top.
class InvestigationPanel extends ConsumerStatefulWidget {
  const InvestigationPanel({
    super.key,
    required this.subject,
    required this.tap,
    required this.onOpenRoute,
    this.title,
  });

  final InvestigationSubject? subject;
  final GateTapEvent? tap;
  final String? title;

  /// Closes the panel and goes to [location].
  final void Function(String location) onOpenRoute;

  @override
  ConsumerState<InvestigationPanel> createState() => _InvestigationPanelState();
}

class _InvestigationPanelState extends ConsumerState<InvestigationPanel> {
  /// The tap in focus. Starts as the one that opened the panel; picking
  /// another from "Other taps" moves it, so the history can be walked.
  GateTapEvent? _focus;

  @override
  void initState() {
    super.initState();
    _focus = widget.tap;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final subject = widget.subject;
    final profile = subject == null
        ? null
        : ref.watch(investigationProfileProvider(subject));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: profile?.valueOrNull?.title ?? widget.title ?? _focus?.who ?? '',
          subtitle: profile?.valueOrNull?.subtitle,
          onClose: () => Navigator.of(context).pop(),
        ),
        Divider(height: 1, color: t.border.subtle),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: [
              if (_focus != null) _TapDetail(tap: _focus!),
              if (_focus != null) const SizedBox(height: AppSpacing.x4),
              if (profile != null)
                AsyncView(
                  value: profile,
                  onRetry: () =>
                      ref.invalidate(investigationProfileProvider(subject!)),
                  loading: const SkeletonList(count: 5),
                  data: (p) => _ProfileBody(
                    profile: p,
                    focusId: _focus?.id,
                    onFocusTap: (tap) => setState(() => _focus = tap),
                    onOpenRoute: widget.onOpenRoute,
                  ),
                )
              else
                Text(
                  'This tap carries no card and no plate, so there is nobody to look up.',
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4, AppSpacing.x4, AppSpacing.x2, AppSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleLarge),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ── The tap that raised the question ─────────────────────────────────────────

class _TapDetail extends StatelessWidget {
  const _TapDetail({required this.tap});

  final GateTapEvent tap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final intent = tap.isManual
        ? StatusIntent.neutral
        : tap.opened
            ? StatusIntent.success
            : tap.serious
                ? StatusIntent.danger
                : StatusIntent.warning;
    final c = t.status.of(intent);

    final plateLine = switch (tap.plateMatches) {
      true => 'Match',
      false => 'Mismatch',
      null => tap.cameraPlate == null ? 'No camera reading' : 'Nothing to compare',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.x3),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: AppRadii.smAll,
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tap.outcomeLabel,
                style: text.labelMedium?.copyWith(color: c.fg, letterSpacing: 0.6),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                tap.message.isEmpty ? 'No reason was recorded.' : tap.message,
                style: text.bodyMedium?.copyWith(color: c.fg),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        _Facts([
          ('When', _when.format(manila(tap.at))),
          ('Gate', tap.readerName == null || tap.readerName!.isEmpty
              ? 'Gate ${tap.gate}'
              : 'Gate ${tap.gate} · ${tap.readerName}'),
          ('Card', tap.rfidTagId ?? 'None'),
          ('Holder', tap.isUnknownCard ? 'Nobody holds this card' : tap.who),
          ('Registered plate', _orNone(tap.registeredPlates)),
          ('Camera read', _orNone(tap.cameraPlate)),
          ('Plate check', plateLine),
        ]),
      ],
    );
  }
}

String _orNone(String? v) => v == null || v.isEmpty ? 'None' : v;

/// Label / value rows.
class _Facts extends StatelessWidget {
  const _Facts(this.rows);

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        for (final (label, value) in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.border.subtle)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 128,
                  child: Text(label,
                      style: text.bodySmall?.copyWith(color: t.text.tertiary)),
                ),
                Expanded(child: SelectableText(value, style: text.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

// ── The profile ──────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.focusId,
    required this.onFocusTap,
    required this.onOpenRoute,
  });

  final InvestigationProfile profile;
  final String? focusId;
  final ValueChanged<GateTapEvent> onFocusTap;
  final void Function(String location) onOpenRoute;

  /// What the Gate Taps page is asked to search for to show this subject's
  /// taps: the card when there is one, else a plate, else the name.
  String? get _tapSearch {
    final person = profile.person;
    final visitor = profile.visitor;
    return profile.card ??
        profile.plate ??
        person?.rfidTagId ??
        (person != null && person.vehicles.isNotEmpty
            ? person.vehicles.first.plate
            : null) ??
        visitor?.rfidTagId ??
        person?.fullName ??
        visitor?.visitorName;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final others = [for (final x in profile.taps) if (x.id != focusId) x];
    final search = _tapSearch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(_whoTitle(profile)),
        _WhoFacts(profile: profile),
        if (profile.isUnknown) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            profile.kind == 'card'
                ? 'Nobody holds this card, so there is no owner, vehicle or violation to show. Only its taps.'
                : 'No vehicle or visitor pass carries this plate, so there is no owner to show. Only what the camera read.',
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        ],
        const SizedBox(height: AppSpacing.x4),
        _Totals(profile.totals, unknown: profile.isUnknown),
        const SizedBox(height: AppSpacing.x4),

        _SectionTitle(
          'Other taps',
          trailing: search == null
              ? null
              : TextButton(
                  onPressed: () => onOpenRoute(
                      '/gate-taps?search=${Uri.encodeQueryComponent(search)}'),
                  child: Text('Show all ${profile.totals.taps} in Gate Taps'),
                ),
        ),
        if (others.isEmpty)
          _Muted('No other taps.')
        else
          for (final x in others.take(6))
            _TapRow(tap: x, onTap: () => onFocusTap(x)),

        if (profile.sessions.isNotEmpty || profile.totals.sessions > 0) ...[
          const SizedBox(height: AppSpacing.x4),
          _SectionTitle('Parking sessions · ${profile.totals.sessions}'),
          for (final s in profile.sessions.take(5)) _SessionRow(session: s),
        ],

        if (!profile.isUnknown && profile.kind != 'visitor') ...[
          const SizedBox(height: AppSpacing.x4),
          _SectionTitle(
            'Violations · ${profile.totals.violations}',
            trailing: profile.totals.violations == 0
                ? null
                : TextButton(
                    onPressed: () => onOpenRoute('/violations'),
                    child: const Text('Open Violations'),
                  ),
          ),
          if (profile.violations.isEmpty)
            _Muted('No violations.')
          else
            for (final v in profile.violations.take(5)) _ViolationRow(violation: v),

          const SizedBox(height: AppSpacing.x4),
          _SectionTitle(
            'Incidents filed by this person · ${profile.totals.incidents}',
            trailing: profile.totals.incidents == 0
                ? null
                : TextButton(
                    onPressed: () => onOpenRoute('/incidents'),
                    child: const Text('Open Incidents'),
                  ),
          ),
          if (profile.incidents.isEmpty)
            _Muted('None filed.')
          else
            for (final i in profile.incidents.take(3)) _IncidentRow(incident: i),
        ],
      ],
    );
  }

  static String _whoTitle(InvestigationProfile p) => switch (p.kind) {
        'person' => 'Who',
        'visitor' => 'Visitor card',
        'card' => 'Card',
        _ => 'Plate',
      };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x1),
      child: Row(
        children: [
          Expanded(child: Text(title, style: text.titleSmall)),
          ?trailing,
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: t.text.tertiary),
      ),
    );
  }
}

class _WhoFacts extends StatelessWidget {
  const _WhoFacts({required this.profile});

  final InvestigationProfile profile;

  @override
  Widget build(BuildContext context) {
    final person = profile.person;
    final visitor = profile.visitor;

    if (person != null) {
      return _Facts([
        ('Role', person.role == 'User' ? person.affiliation : person.role),
        if (person.studentNumber != null) ('Student no.', person.studentNumber!),
        ('Email', person.email),
        ('Account', person.archived ? 'Archived' : person.accountStatus),
        ('Card', person.rfidTagId == null
            ? 'None'
            : '${person.rfidTagId} · ${person.rfidStatus}'),
        (
          'Vehicles',
          person.vehicles.isEmpty
              ? 'None registered'
              : person.vehicles
                  .map((v) => '${v.plate} (${v.vehicleType}, ${v.color})')
                  .join('\n'),
        ),
      ]);
    }
    if (visitor != null) {
      return _Facts([
        ('Plate', visitor.plateNumber),
        ('Card', visitor.rfidTagId),
        if (visitor.purpose != null && visitor.purpose!.isNotEmpty)
          ('Purpose', visitor.purpose!),
        ('Issued', _short.format(manila(visitor.issuedAt))),
        ('Expires', _short.format(manila(visitor.expiresAt))),
        (
          'Returned',
          visitor.returnedAt == null
              ? 'Not yet'
              : _short.format(manila(visitor.returnedAt!)),
        ),
      ]);
    }
    return _Facts([
      if (profile.card != null) ('Card', profile.card!),
      if (profile.plate != null) ('Plate', profile.plate!),
    ]);
  }
}

/// How much sits behind the lists below.
class _Totals extends StatelessWidget {
  const _Totals(this.totals, {required this.unknown});

  final ProfileTotals totals;
  final bool unknown;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: [
        _Chip('${totals.taps}', 'taps'),
        _Chip('${totals.deniedTaps}', 'denied'),
        _Chip('${totals.seriousDeniedTaps}', 'serious denials',
            hot: totals.seriousDeniedTaps > 0),
        _Chip('${totals.sessions}', 'sessions'),
        if (!unknown) ...[
          _Chip('${totals.violations}', 'violations'),
          _Chip('${totals.incidents}', 'incidents filed'),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.value, this.label, {this.hot = false});

  final String value;
  final String label;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(hot ? StatusIntent.danger : StatusIntent.neutral);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3, vertical: AppSpacing.x1),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: text.titleSmall?.copyWith(color: c.fg)),
          const SizedBox(width: AppSpacing.x1),
          Text(label, style: text.bodySmall?.copyWith(color: c.fg)),
        ],
      ),
    );
  }
}

// ── Linked records ───────────────────────────────────────────────────────────

class _RowShell extends StatelessWidget {
  const _RowShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.smAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.border.subtle)),
        ),
        child: child,
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({required this.tap, required this.onTap});

  final GateTapEvent tap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = tap.isManual
        ? t.text.tertiary
        : tap.opened
            ? t.status.success.solid
            : tap.serious
                ? t.status.danger.solid
                : t.status.warning.solid;

    return _RowShell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${tap.outcomeLabel} · Gate ${tap.gate}',
                    style: text.bodyMedium),
                Text(
                  tap.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Text(_short.format(manila(tap.at)),
              style: text.labelSmall?.copyWith(color: t.text.tertiary)),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final ProfileSession session;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final inside = session.exitTime == null;

    return _RowShell(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In ${_short.format(manila(session.entryTime))}'
                  '${session.gate == null ? '' : ' · Gate ${session.gate}'}',
                  style: text.bodyMedium,
                ),
                Text(
                  inside
                      ? 'Still inside'
                      : 'Out ${_short.format(manila(session.exitTime!))}',
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
          if (session.plate != null)
            Text(session.plate!,
                style: text.labelMedium?.copyWith(color: t.text.secondary)),
          if (session.plateMatched == false) ...[
            const SizedBox(width: AppSpacing.x2),
            const StatusPill.of('Mismatch',
                intent: StatusIntent.danger, showDot: false, dense: true),
          ],
        ],
      ),
    );
  }
}

class _ViolationRow extends StatelessWidget {
  const _ViolationRow({required this.violation});

  final ProfileViolation violation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return _RowShell(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(violation.ruleTitle, style: text.bodyMedium),
                Text(
                  '${_short.format(manila(violation.createdAt))} · ${_peso.format(violation.penaltyAmount)}',
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
              ],
            ),
          ),
          StatusPill.of(
            ViolationStatuses.label(violation.status),
            intent: StatusIntents.violation(violation.status),
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.incident});

  final ProfileIncident incident;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return _RowShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(incident.category, style: text.bodyMedium),
                Text(
                  incident.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
                Text(
                  _short.format(manila(incident.createdAt)),
                  style: text.labelSmall?.copyWith(color: t.text.tertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          StatusPill.of(incident.status,
              intent: StatusIntents.incident(incident.status), dense: true),
        ],
      ),
    );
  }
}
