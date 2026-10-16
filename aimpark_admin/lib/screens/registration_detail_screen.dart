import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/audit_log_entry.dart';
import '../models/registration_checks.dart';
import '../models/registration_detail.dart';
import '../providers/audit_logs_provider.dart';
import '../providers/queue_counts_provider.dart';
import '../providers/registrations_provider.dart';
import '../theme/theme.dart';
import '../widgets/checks_panel.dart';
import '../widgets/ebike_inspection_dialog.dart';
import '../widgets/review_documents.dart';
import '../widgets/ui/ui.dart';

String _fmt(DateTime dt) => DateFormat('MMM d, yyyy HH:mm').format(dt.toLocal());

class RegistrationDetailScreen extends ConsumerWidget {
  const RegistrationDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(registrationDetailProvider(userId));
    final detail = async.valueOrNull;

    return AppPage(
      title: detail?.fullName ?? 'Registration',
      subtitle: detail == null
          ? 'Reviewing a submitted registration.'
          : _headline(detail),
      scrollable: true,
      onBack: () => context.go('/pending'),
      actions: [
        // Only offered while the application is actually awaiting a decision —
        // an already-approved record showing a live Approve button invites a
        // second, meaningless write.
        //
        // Gated on the *account* status, which is what the pending queue itself
        // selects on. Gating on `verificationStatus == 'Pending'` hid these
        // buttons on every single application: submitting sets that field to
        // `ManualReview`, and nothing in the API ever writes `Pending`.
        if (detail != null && detail.accountStatus == 'PendingReview') ...[
          // Most refusals are not "this person may not park here" but "I
          // cannot read this receipt", and rejection was the only tool for
          // both — which cost the applicant all their documents and a
          // cooldown to fix one photograph.
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_camera_outlined, size: AppSizes.iconSm),
            label: const Text('Ask to retake'),
            onPressed: () => _showRetakeDialog(context, ref, detail),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: AppSizes.iconSm),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.tokens.status.danger.fg,
              side: BorderSide(color: context.tokens.status.danger.border),
            ),
            onPressed: () => _showRejectDialog(context, ref, detail),
          ),
          // An e-bike has no receipt to read; it is approved by recording the
          // in-person inspection, which then approves through the same path.
          if (detail.isEBike)
            FilledButton.icon(
              icon: const Icon(Icons.pedal_bike_outlined, size: AppSizes.iconSm),
              label: const Text('Inspect e-bike…'),
              onPressed: () => _inspectEBike(context, ref, detail),
            )
          // A filled Approve beside a red finding reads as the expected next
          // step. Over anything red or amber it steps down to a secondary
          // button and says what it is.
          else if (detail.checks?.hasSerious ?? false)
            OutlinedButton.icon(
              icon: const Icon(Icons.check, size: AppSizes.iconSm),
              label: const Text('Approve anyway…'),
              onPressed: () => _approve(context, ref, detail),
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.check, size: AppSizes.iconSm),
              label: const Text('Approve'),
              onPressed: () => _approve(context, ref, detail),
            ),
        ],
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(registrationDetailProvider(userId)),
        ),
      ],
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(registrationDetailProvider(userId)),
        loading: const _ReviewSkeleton(),
        data: (detail) => _DetailView(detail: detail),
      ),
    );
  }

  static String _headline(RegistrationDetail detail) {
    final waited = switch (detail.waitingDays) {
      0 => 'waiting since today',
      1 => 'waiting 1 day',
      final n => 'waiting $n days',
    };
    return '${detail.affiliation} · Applied '
        '${DateFormat('MMM d, yyyy').format(detail.createdAt.toLocal())} · $waited'
        ' · ${detail.email}';
  }

  /// Approving used to be one dialog regardless of what the checks found — a
  /// "Clear" application and one that needed a look got the same plain
  /// confirm/cancel. This shows the actual findings when they need attention
  /// and asks for a reason before letting the button through, so the checks
  /// this system already computes are not simply ignored at the one moment
  /// they matter most.
  Future<void> _approve(
      BuildContext context, WidgetRef ref, RegistrationDetail detail) async {
    final needsOverride =
        detail.checks != null && detail.checks!.verdict != 'Clear';

    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<({String? overrideNote})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Approve Registration'),
          content: SizedBox(
            width: ctx.dialogWidth(420),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approve ${detail.fullName}\'s registration? This will '
                    'activate their account.',
                  ),
                  if (needsOverride) ...[
                    const SizedBox(height: AppSpacing.x3),
                    for (final headline in detail.checks!.headlines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.x1),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: AppSizes.iconSm,
                              color: ctx.tokens.status.warning.fg,
                            ),
                            const SizedBox(width: AppSpacing.x1),
                            Expanded(child: Text(headline)),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.x2),
                    TextFormField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason for approving despite the above',
                      ),
                      maxLines: 2,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'A reason is required'
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx, (
                  overrideNote: needsOverride ? noteCtrl.text.trim() : null,
                ));
              },
              child: const Text('Approve'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    final msg = await ref.read(registrationActionsProvider.notifier).approve(
          userId,
          overrideNote: result.overrideNote,
        );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Approved successfully')));
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(pendingRegistrationsProvider);
    ref.invalidate(pendingQueueCountProvider);
  }

  Future<void> _inspectEBike(
      BuildContext context, WidgetRef ref, RegistrationDetail detail) async {
    final message = await showEBikeInspectionDialog(context, detail);
    if (message == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(pendingRegistrationsProvider);
    ref.invalidate(pendingQueueCountProvider);
  }

  /// The documents a reviewer can send back, in the order the applicant took
  /// them. The registration form is offered only for a student: faculty and
  /// staff never send one.
  static const _retakeDocuments = <String, String>{
    'Raf': 'Registration form',
    'License': "Driver's licence",
    'OfficialReceipt': 'Official receipt',
  };

  /// Common reasons, offered as one tap each.
  ///
  /// The reason reaches the applicant on the capture screen for that document,
  /// so it is written as an instruction to somebody standing in front of the
  /// thing — not as a note to a colleague.
  static const _retakeReasons = <String>[
    'Too blurry to read.',
    'Too dark — try again in better light.',
    'Part of it is cut off by the frame.',
    'Glare is covering the printed details.',
    'This is not the document we asked for.',
  ];

  Future<void> _showRetakeDialog(
      BuildContext context, WidgetRef ref, RegistrationDetail detail) async {
    final reasons = <String, TextEditingController>{};
    final selected = <String>{};
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final canSend = selected.isNotEmpty &&
              selected.every(
                  (key) => reasons[key]?.text.trim().isNotEmpty ?? false);

          return AlertDialog(
            title: const Text('Ask for documents again'),
            content: SizedBox(
              width: ctx.dialogWidth(520),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'They keep their place in the queue and their other '
                      'documents. No cooldown — they can answer straight away.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    for (final entry in _retakeDocuments.entries.where(
                        (e) =>
                            !(detail.isEBike && e.key == 'OfficialReceipt') &&
                            !(detail.affiliation != 'Student' && e.key == 'Raf'),
                    )) ...[
                      CheckboxListTile(
                        value: selected.contains(entry.key),
                        title: Text(entry.value),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        onChanged: (on) => setState(() {
                          if (on == true) {
                            selected.add(entry.key);
                            reasons.putIfAbsent(
                                entry.key, () => TextEditingController());
                          } else {
                            selected.remove(entry.key);
                          }
                        }),
                      ),
                      if (selected.contains(entry.key)) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              left: AppSpacing.x6, bottom: AppSpacing.x2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: AppSpacing.x1,
                                children: [
                                  for (final preset in _retakeReasons)
                                    ActionChip(
                                      label: Text(preset,
                                          style: Theme.of(context).textTheme.labelSmall),
                                      onPressed: () => setState(() =>
                                          reasons[entry.key]!.text = preset),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.x1),
                              TextField(
                                controller: reasons[entry.key],
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'What was wrong with it?',
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.x2),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note to the applicant (optional)',
                        isDense: true,
                      ),
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
                // Every chosen document needs a reason. One sent back without
                // one gets retaken identically, because nothing told them what
                // to change.
                onPressed:
                    canSend ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Send back'),
              ),
            ],
          );
        },
      ),
    );

    final documents = {
      for (final key in selected) key: reasons[key]!.text.trim(),
    };

    for (final controller in reasons.values) {
      controller.dispose();
    }
    final note = noteCtrl.text;
    noteCtrl.dispose();

    if (confirmed != true || documents.isEmpty || !context.mounted) return;

    final msg = await ref
        .read(registrationActionsProvider.notifier)
        .requestRetake(userId, documents, note: note);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? 'Sent back to the applicant')));
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(pendingRegistrationsProvider);
    ref.invalidate(pendingQueueCountProvider);
  }

  static const _rejectPresets = <String, String>{
    'Blurred document':
        'One or more of your uploaded documents is too blurry to verify.',
    'Mismatched information':
        'The information you provided does not match your uploaded documents.',
    'Expired ID':
        'Your uploaded ID/license has expired.',
    'Suspicious/altered document':
        'One or more of your uploaded documents appears to be altered or invalid. Please contact the administration office for assistance.',
  };

  /// Which preset the checks point at, and why.
  ///
  /// A suggestion, filled in and still editable — the admin may have opened the
  /// documents and found a better reason than the one a rule inferred. Ordered
  /// by how specific the finding is: an expired document is a fact, a mismatch
  /// is a comparison, and an unreadable value is only ever a guess at blur.
  static ({String preset, String why})? _suggestPreset(RegistrationChecks? checks) {
    if (checks == null) return null;

    if (checks.firstFailing({'LicenseValidity', 'RegistrationValidity'})
        case final expired?) {
      return (preset: 'Expired ID', why: 'the ${expired.label} check failed');
    }

    if (checks.firstFailing({'NameMatch', 'PlateMatch'})
        case final mismatch?) {
      return (
        preset: 'Mismatched information',
        why: 'the ${mismatch.label} check failed'
      );
    }

    // An identity value the applicant typed is a mismatch in substance: the
    // document and the account do not agree, we just never got to compare them.
    if (checks.edits.any((e) => e.isIdentity)) {
      return (
        preset: 'Mismatched information',
        why: 'an identity field was typed by the applicant'
      );
    }

    if (checks.unreadable > 0) {
      return (preset: 'Blurred document', why: 'a value could not be read');
    }

    return null;
  }

  Future<void> _showRejectDialog(
      BuildContext context, WidgetRef ref, RegistrationDetail detail) async {
    final suggestion = _suggestPreset(detail.checks);

    final reasonCtrl = TextEditingController(
        text: suggestion == null ? '' : _rejectPresets[suggestion.preset]);
    final formKey = GlobalKey<FormState>();
    String? selectedPreset = suggestion?.preset;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Reject Registration'),
          content: SizedBox(
            width: ctx.dialogWidth(420),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'A rejection is final: this email can no longer be used to '
                    'register. If the problem can be fixed with a new photo, '
                    'ask for a retake instead.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPreset,
                    decoration: InputDecoration(
                      labelText: 'Reason preset (optional)',
                      helperText: suggestion == null
                          ? null
                          : 'Chosen because ${suggestion.why}.',
                    ),
                    items: [
                      ..._rejectPresets.keys.map((label) =>
                          DropdownMenuItem(value: label, child: Text(label))),
                      const DropdownMenuItem(
                          value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (label) {
                      setState(() => selectedPreset = label);
                      if (label != null && label != 'Other') {
                        reasonCtrl.text = _rejectPresets[label]!;
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  TextFormField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rejection Reason',
                      helperText:
                          'Sent to the applicant by email — edit as needed.',
                    ),
                    maxLines: 3,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Reason is required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: ctx.tokens.status.danger.solid),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, reasonCtrl.text.trim());
                }
              },
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    final msg = await ref
        .read(registrationActionsProvider.notifier)
        .reject(userId, result);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Rejected')));
    ref.invalidate(registrationDetailProvider(userId));
    ref.invalidate(pendingRegistrationsProvider);
    ref.invalidate(pendingQueueCountProvider);
  }
}

// ── Detail view ──────────────────────────────────────────────────────────────

/// Below this the findings and the documents stack instead of sitting side by
/// side; two columns any narrower leave the image too small to read.
const double _twoColumnWidth = 960;

/// Top to bottom: what the checks found, the handful of values to check, then
/// the findings next to the documents they are about.
///
/// The Status, Personal and Vehicle cards that used to sit here are gone. Their
/// useful values are in the key facts grid; the rest were enum names
/// (`PendingReview`, `ManualReview`) that told the reviewer nothing.
class _DetailView extends StatefulWidget {
  const _DetailView({required this.detail});

  final RegistrationDetail detail;

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final checks = detail.checks;
    final tabs = ReviewDocumentTab.forDetail(detail);

    void openDocument(String type) {
      final i = tabs.indexWhere((t) => t.type == type);
      if (i >= 0) setState(() => _tab = i);
    }

    final findings = checks == null
        ? null
        : FindingsCard(checks: checks, onOpenDocument: openDocument);
    final documents = ReviewDocuments(
      tabs: tabs,
      selected: _tab,
      onSelect: (i) => setState(() => _tab = i),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A rejection is the one thing on this page that changes what the
        // reviewer should do next, so it sits above everything else.
        if (detail.rejectionReason case final reason?) ...[
          _RejectionBanner(
            reason: reason,
            count: detail.rejectionCount,
            canReapplyAt: detail.canReapplyAt,
          ),
          const SizedBox(height: AppSpacing.gutter),
        ],
        if (detail.isEBike && detail.accountStatus == 'PendingReview') ...[
          _EBikeBanner(deadline: detail.eBikeInspectionDeadline),
          const SizedBox(height: AppSpacing.gutter),
        ],
        if (checks != null)
          FindingsSummaryBox(checks: checks)
        else
          const _NoDocumentsBox(),
        const SizedBox(height: AppSpacing.gutter),
        _KeyFacts(detail: detail),
        const SizedBox(height: AppSpacing.gutter),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _twoColumnWidth || findings == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (findings != null) ...[
                    findings,
                    const SizedBox(height: AppSpacing.gutter),
                  ],
                  documents,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: findings),
                const SizedBox(width: AppSpacing.gutter),
                Expanded(flex: 6, child: documents),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.gutter),
        _HistoryCard(userId: detail.userId),
      ],
    );
  }
}

/// Says what an e-bike application is waiting on, and how long it has had.
class _EBikeBanner extends StatelessWidget {
  const _EBikeBanner({required this.deadline});

  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final due = deadline?.toLocal();
    var overdue = false;
    String when = '';
    if (due != null) {
      final today = DateTime.now();
      final days = DateTime(due.year, due.month, due.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      overdue = days < 0;
      when = overdue
          ? ' Due ${DateFormat('MMM d').format(due)}, overdue by ${-days} ${-days == 1 ? 'day' : 'days'}.'
          : days == 0
              ? ' Due today.'
              : ' Due ${DateFormat('MMM d').format(due)}, $days ${days == 1 ? 'day' : 'days'} left.';
    }

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.pedal_bike_outlined,
              size: AppSizes.iconMd,
              color: overdue ? t.status.danger.fg : t.status.info.fg),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              'E-bike application. There is no receipt to read: the applicant '
              'brings the e-bike to the office, and you inspect it with Inspect '
              'e-bike. Their licence and school form are checked below as usual.$when',
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDocumentsBox extends StatelessWidget {
  const _NoDocumentsBox();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        children: [
          Icon(Icons.info_outline, size: AppSizes.iconMd, color: t.text.secondary),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              'No documents submitted yet, so nothing has been checked.',
              style: text.bodyMedium?.copyWith(color: t.text.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Key facts ────────────────────────────────────────────────────────────────

/// Columns for the key facts grid at a given width. Shared with the skeleton
/// so the loading state is the same shape as what replaces it. The name cell
/// takes two of them.
int _factColumns(double width) => width >= 900 ? 4 : 2;

/// A key fact's state, said in words. Colour backs the words up; it is never
/// the only signal, so "Jan 31, 2026" in red also reads "Expired 8 months ago".
class _FactStatus {
  const _FactStatus(this.text, this.intent, this.icon);

  final String text;
  final StatusIntent intent;
  final IconData icon;

  static _FactStatus of(String text, FindingSeverity severity) => _FactStatus(
        text,
        intentOfSeverity(severity),
        switch (severity) {
          FindingSeverity.danger => Icons.cancel_outlined,
          FindingSeverity.warning => Icons.error_outline,
          FindingSeverity.neutral => Icons.info_outline,
          FindingSeverity.passed => Icons.check_circle_outline,
        },
      );

  static const notRead = _FactStatus('Not read', StatusIntent.neutral, Icons.info_outline);
}

/// "8 months", "12 days", "2 years" — the gap between today and [date].
String _span(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final days = DateUtils.dateOnly(date).difference(today).inDays.abs();
  String unit(int n, String word) => '$n ${n == 1 ? word : '${word}s'}';
  if (days < 31) return unit(days, 'day');
  if (days < 365) return unit(days ~/ 30, 'month');
  return unit(days ~/ 365, 'year');
}

/// An expiry date's state, worded from the finding's severity and the date.
_FactStatus _expiryStatus(Finding? finding, DateTime? date) {
  if (date == null || finding == null) return _FactStatus.notRead;
  final today = DateUtils.dateOnly(DateTime.now());
  final isToday = DateUtils.dateOnly(date) == today;

  return switch (finding.severity) {
    FindingSeverity.danger => _FactStatus.of('Expired ${_span(date)} ago', FindingSeverity.danger),
    FindingSeverity.warning => _FactStatus.of(
        isToday ? 'Expires today' : 'Expires in ${_span(date)}', FindingSeverity.warning),
    FindingSeverity.passed => _FactStatus.of('Valid · ${_span(date)} left', FindingSeverity.passed),
    FindingSeverity.neutral => _FactStatus.notRead,
  };
}

/// Where a value came from, as a small tag beside it.
enum _Source {
  signUp('Sign-up', StatusIntent.neutral),
  read('Read', StatusIntent.info),
  changed('Changed', StatusIntent.warning),
  typed('Typed', StatusIntent.warning);

  const _Source(this.label, this.intent);
  final String label;
  final StatusIntent intent;
}

/// The values a reviewer checks against the documents, each saying where it
/// came from and what state it is in. Read from the submission — the account
/// only receives the student number on approval, which is why it used to
/// show nowhere here.
class _KeyFacts extends StatelessWidget {
  const _KeyFacts({required this.detail});

  final RegistrationDetail detail;

  @override
  Widget build(BuildContext context) {
    final checks = detail.checks;
    final facts = checks?.facts ?? const RegistrationFacts();
    final isStudent = detail.affiliation == 'Student';

    Finding? about(Set<String> keys) => checks?.findingFor(keys);
    bool edited(String key) => checks?.edited(key) ?? false;
    String date(DateTime? d) =>
        d == null ? 'Not read' : DateFormat('MMM d, yyyy').format(d);

    final vehicle = detail.vehicles.isEmpty ? null : detail.vehicles.first;
    final vehicleFacts = facts.vehicles.isEmpty ? null : facts.vehicles.first;

    // ── Name: three sources side by side ──
    final nameFinding = about({
      'NameMatch',
      'Edit.Name',
      'Edit.Licencename',
      'DuplicateUpload',
    });
    final nameStatus = switch (nameFinding) {
      null => null,
      Finding(key: 'NameMatch', severity: FindingSeverity.danger) =>
        _FactStatus.of('Names do not match', FindingSeverity.danger),
      Finding(key: 'NameMatch', severity: FindingSeverity.passed) =>
        _FactStatus.of('Name found on the licence', FindingSeverity.passed),
      final f => _FactStatus.of(f.title, f.severity),
    };

    // "Typed" when the phone read nothing, "Changed" when it read something
    // the applicant then overwrote — the edit finding's title says which.
    _Source readOrChanged(String? value, String editKey) {
      if (value == null || !edited(editKey)) return _Source.read;
      final edit = about({editKey});
      return edit != null && edit.title.contains('typed')
          ? _Source.typed
          : _Source.changed;
    }

    final name = _NameCell(
      rows: [
        (
          label: 'Account name',
          hint: 'Typed at sign-up',
          value: detail.fullName,
          source: _Source.signUp,
        ),
        if (isStudent)
          (
            label: 'School form',
            hint: 'Read by the phone',
            value: facts.schoolFormName,
            source: readOrChanged(facts.schoolFormName, 'Edit.Name'),
          ),
        (
          label: 'Licence',
          hint: 'Read by the phone',
          value: facts.licenseName,
          source: readOrChanged(facts.licenseName, 'Edit.Licencename'),
        ),
      ],
      status: nameStatus,
    );

    // ── The rest ──
    final cells = <Widget>[
      if (isStudent) ...[
        _FactCell(
          label: 'Student number',
          value: facts.studentNumber ?? detail.studentNumber ?? 'Not read',
          note: switch (facts.section ?? detail.section) {
            final s? => 'Section $s',
            null => null,
          },
          status: facts.studentNumber == null
              ? _FactStatus.notRead
              : facts.studentNumberTyped
                  ? _FactStatus.of('Typed by applicant', FindingSeverity.warning)
                  : const _FactStatus(
                      'Read from school form', StatusIntent.info, Icons.document_scanner_outlined),
        ),
        _FactCell(
          label: 'Term',
          value: facts.semester ?? 'Not read',
          // Never green: the system does not know the current term.
          status: facts.semester == null
              ? _FactStatus.notRead
              : _FactStatus.of('Confirm it yourself', FindingSeverity.neutral),
        ),
      ] else ...[
        _FactCell(
          label: 'Affiliation',
          value: detail.affiliation,
          status: _FactStatus.of('No term to check', FindingSeverity.neutral),
        ),
      ],
      _FactCell(
        label: 'Licence number',
        value: facts.licenseNumberMasked ?? 'Not given',
        note: 'Only the last 4 shown',
        status: facts.licenseNumberMasked == null
            ? _FactStatus.notRead
            : facts.licenseNumberTyped
                ? _FactStatus.of('Typed by applicant', FindingSeverity.warning)
                : const _FactStatus(
                    'Read from licence', StatusIntent.info, Icons.document_scanner_outlined),
      ),
      _FactCell(
        label: 'Licence valid until',
        value: date(facts.licenseExpiry),
        status: _expiryStatus(about({'LicenseValidity'}), facts.licenseExpiry),
      ),
      _FactCell(
        label: 'Plate',
        value: vehicleFacts?.plateNumber ?? vehicle?.plateNumber ?? 'Not read',
        note: [
          if (vehicle != null)
            [vehicle.vehicleType, vehicle.color]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .join(' · '),
          if (detail.vehicles.length > 1) '+${detail.vehicles.length - 1} more',
        ].where((s) => s.isNotEmpty).join(' · '),
        status: switch (about({'PlateMatch', 'Edit.Platenumber'})) {
          null => _FactStatus.notRead,
          Finding(key: 'PlateMatch', severity: FindingSeverity.passed) =>
            _FactStatus.of('Read from receipt', FindingSeverity.passed),
          final f => _FactStatus.of(f.title, f.severity),
        },
      ),
      _FactCell(
        label: 'Registration valid until',
        value: date(vehicleFacts?.registrationExpiry),
        note: detail.vehicles.length > 1 ? 'First vehicle' : null,
        status: _expiryStatus(
            about({'RegistrationValidity'}), vehicleFacts?.registrationExpiry),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _factColumns(constraints.maxWidth);
        final cell =
            (constraints.maxWidth - AppSpacing.gutter * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.gutter,
          runSpacing: AppSpacing.gutter,
          children: [
            SizedBox(width: cell * 2 + AppSpacing.gutter, child: name),
            for (final c in cells) SizedBox(width: cell, child: c),
          ],
        );
      },
    );
  }
}

/// The card both fact cells share: white, with a thin bar in the status
/// colour down the left edge and the status in words at the bottom.
class _FactFrame extends StatelessWidget {
  const _FactFrame({required this.label, required this.child, this.status});

  final String label;
  final Widget child;
  final _FactStatus? status;

  static const double minHeight = 116;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = status == null ? null : t.status.of(status!.intent);

    // Only states worth a glance get the bar; "read" and "not read" do not.
    final bar = switch (status?.intent) {
      StatusIntent.danger || StatusIntent.warning || StatusIntent.success => c!.solid,
      _ => null,
    };

    return Container(
      constraints: const BoxConstraints(minHeight: minHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface.card,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: t.border.normal),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bar != null) Container(width: 3, color: bar),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.labelSmall?.copyWith(color: t.text.tertiary)),
                    const SizedBox(height: AppSpacing.x1),
                    child,
                    if (status case final s?) ...[
                      const Spacer(),
                      const SizedBox(height: AppSpacing.x2),
                      Row(
                        children: [
                          Icon(s.icon, size: AppSizes.iconSm, color: c!.fg),
                          const SizedBox(width: AppSpacing.x1),
                          Flexible(
                            child: Text(
                              s.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelLarge?.copyWith(color: c.fg),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactCell extends StatelessWidget {
  const _FactCell({
    required this.label,
    required this.value,
    this.note,
    this.status,
  });

  final String label;
  final String value;
  final String? note;
  final _FactStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return _FactFrame(
      label: label,
      status: status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: text.titleMedium),
          if (note case final n? when n.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                n,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: t.text.secondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// The name as each source has it, so a mismatch is visible as two different
/// lines rather than inferred from a red box.
class _NameCell extends StatelessWidget {
  const _NameCell({required this.rows, this.status});

  final List<({String label, String hint, String? value, _Source source})> rows;
  final _FactStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return _FactFrame(
      label: 'Name',
      status: status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 128,
                    child: Tooltip(
                      message: r.hint,
                      child: Text(
                        r.label,
                        style: text.bodyMedium?.copyWith(color: t.text.secondary),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.value ?? 'Nothing read',
                      style: r.value == null
                          ? text.bodyMedium?.copyWith(color: t.text.tertiary)
                          : text.titleSmall,
                    ),
                  ),
                  if (r.value != null) ...[
                    const SizedBox(width: AppSpacing.x2),
                    StatusPill(
                      label: r.source.label,
                      intent: r.source.intent,
                      dense: true,
                      showDot: false,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Loading ──────────────────────────────────────────────────────────────────

/// The review screen's own shape: summary box, the fact cells, findings beside
/// the document. Built from the shared skeleton pieces, never by wrapping card
/// chrome in a shimmer.
class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final columns = _factColumns(w);
        final cell = (w - AppSpacing.gutter * (columns - 1)) / columns;

        const findings = SkeletonDetail(sections: 1, fieldsPerSection: 4);
        const documents = SkeletonBlock(height: 460);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SkeletonBlock(height: 92),
            const SizedBox(height: AppSpacing.gutter),
            Wrap(
              spacing: AppSpacing.gutter,
              runSpacing: AppSpacing.gutter,
              children: [
                SizedBox(
                  width: cell * 2 + AppSpacing.gutter,
                  child: const SkeletonBlock(height: _FactFrame.minHeight),
                ),
                for (var i = 0; i < 6; i++)
                  SizedBox(
                    width: cell,
                    child: const SkeletonBlock(height: _FactFrame.minHeight),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.gutter),
            if (w < _twoColumnWidth) ...[
              findings,
              const SizedBox(height: AppSpacing.gutter),
              documents,
            ] else
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: findings),
                  SizedBox(width: AppSpacing.gutter),
                  Expanded(flex: 6, child: documents),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// What's been done to this application so far — retakes asked for,
/// approvals, rejections — read without leaving for the separate System Logs
/// screen and losing the record on screen.
class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userAuditLogsProvider(userId));

    // Failing quietly here is deliberate: this card is supporting context for
    // a decision the reviewer can still make without it, not a reason to
    // break the page a rejection or approval already depends on.
    return async.when(
      loading: () => const AppSectionCard(
        title: 'Review History',
        icon: Icons.history,
        child: SkeletonDetail(sections: 1, fieldsPerSection: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (page) {
        if (page.logs.isEmpty) return const SizedBox.shrink();

        return AppSectionCard(
          title: 'Review History',
          subtitle: 'Actions taken on this application, most recent first.',
          icon: Icons.history,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in page.logs) _HistoryRow(entry: entry),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final hasReason = entry.reason != null && entry.reason!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            label: _actionLabel(entry.action),
            intent: StatusIntents.auditAction(entry.action),
            dense: true,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.adminName} · ${_fmt(entry.createdAt)}',
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                ),
                if (hasReason)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.labelGap),
                    child: Text(entry.reason!, style: text.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The audit log's action names, as a reviewer would say them.
String _actionLabel(String action) => switch (action) {
      'Approve' => 'Approved',
      'Reject' => 'Rejected',
      'RequestDocumentRetake' => 'Asked to retake',
      'ResetStep' => 'Step reset',
      'ResetReapply' => 'Rejection lifted',
      _ => action,
    };

class _RejectionBanner extends StatelessWidget {
  const _RejectionBanner({
    required this.reason,
    required this.count,
    required this.canReapplyAt,
  });

  final String reason;
  final int count;
  final DateTime? canReapplyAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.danger;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_bad_outlined, size: AppSizes.iconMd, color: c.fg),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 1
                      ? 'Previously rejected $count times'
                      : 'Previously rejected',
                  style: text.titleSmall?.copyWith(color: c.fg),
                ),
                const SizedBox(height: AppSpacing.labelGap),
                Text(reason, style: text.bodySmall?.copyWith(color: c.fg)),
                if (canReapplyAt case final at?)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.x2),
                    child: Text(
                      'Can reapply from ${_fmt(at)}',
                      style: text.labelSmall?.copyWith(color: c.fg),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
