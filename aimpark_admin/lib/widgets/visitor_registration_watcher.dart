import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/alert_sound.dart';
import '../core/utils/responsive.dart';
import '../models/visitor_card.dart';
import '../providers/security_provider.dart';
import '../providers/visitor_cards_provider.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';
import 'visitor_details_fields.dart';

/// Asks the guard who is in the car whenever an idle visitor card is tapped
/// at a gate, wherever in the panel they happen to be.
///
/// The gate can't wait for a form — it gives up after 15 seconds — so the
/// tap is refused straight away and the site server holds it. This polls for
/// those taps once a second and pops the form for the oldest one; saving it
/// lends the card and opens that barrier. Two guards may see the same form:
/// whoever saves first wins, and the other's form says so.
///
/// Only the guard post's server holds taps. Pointed at the cloud, the first
/// poll is refused and this checks back rarely instead.
class VisitorRegistrationWatcher extends ConsumerStatefulWidget {
  const VisitorRegistrationWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VisitorRegistrationWatcher> createState() =>
      _VisitorRegistrationWatcherState();
}

class _VisitorRegistrationWatcherState
    extends ConsumerState<VisitorRegistrationWatcher> {
  static const _atGuardPost = Duration(seconds: 1);
  static const _elsewhere = Duration(seconds: 30);

  Timer? _timer;
  bool _inFlight = false;
  bool _slow = false;

  /// The tap whose form is open, and whether it has since been handled
  /// somewhere else (another guard, or timed out).
  String? _openId;
  final _gone = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _schedule(_atGuardPost);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gone.dispose();
    super.dispose();
  }

  void _schedule(Duration every) {
    _slow = every == _elsewhere;
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final res =
          await ref.read(dioProvider).get(ApiEndpoints.visitorRegistrations);
      if (!mounted) return;
      if (_slow) _schedule(_atGuardPost);

      final pending = [
        for (final p in res.data as List? ?? const [])
          PendingVisitorRegistration.fromJson(p as Map<String, dynamic>),
      ];

      if (_openId != null) {
        if (!pending.any((p) => p.id == _openId)) _gone.value = true;
        return;
      }
      if (pending.isNotEmpty) _ask(pending.first);
    } on DioException catch (e) {
      // Any answer at all is the cloud saying "not the guard post"; no
      // answer is the server being briefly out of reach.
      if (mounted && !_slow && e.response != null) {
        _schedule(_elsewhere);
      }
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _ask(PendingVisitorRegistration pending) async {
    _openId = pending.id;
    _gone.value = false;
    AlertSound.beep();

    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RegistrationDialog(pending: pending, gone: _gone),
    );

    _openId = null;
    if (!mounted) return;

    ref.invalidate(visitorPassListProvider);
    ref.invalidate(visitorsOnSiteCountProvider);
    ref.invalidate(visitorCardsProvider);
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RegistrationDialog extends ConsumerStatefulWidget {
  const _RegistrationDialog({required this.pending, required this.gone});

  final PendingVisitorRegistration pending;
  final ValueListenable<bool> gone;

  @override
  ConsumerState<_RegistrationDialog> createState() =>
      _RegistrationDialogState();
}

class _RegistrationDialogState extends ConsumerState<_RegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final _plate =
      TextEditingController(text: widget.pending.cameraPlate ?? '');
  final _purpose = TextEditingController();
  var _vehicleType = 'Car';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final (ok, message) = await ref
        .read(visitorRegistrationActionsProvider.notifier)
        .complete(
          widget.pending.id,
          visitorName: _name.text.trim(),
          plateNumber: _plate.text.trim(),
          vehicleType: _vehicleType,
          purpose: _purpose.text.trim(),
        );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, message);
    } else {
      setState(() {
        _busy = false;
        _error = message;
      });
    }
  }

  Future<void> _turnAway() async {
    setState(() => _busy = true);
    final (_, message) = await ref
        .read(visitorRegistrationActionsProvider.notifier)
        .dismiss(widget.pending.id);
    if (mounted) Navigator.pop(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final p = widget.pending;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.gone,
      builder: (context, gone, _) => AlertDialog(
        title: Text('Visitor card ${p.cardLabel} at Gate ${p.gate}'),
        content: SizedBox(
          width: context.dialogWidth(440),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tapped ${DateFormat('HH:mm:ss').format(p.tappedAt.toLocal())}. '
                    'The barrier stays shut until you save. Saving lends the '
                    'card to this visitor and opens the gate.',
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                  if (p.cameraPlate != null) ...[
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      'Plate filled in from the gate camera. Check it against '
                      'the car.',
                      style: text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ],
                  if (gone) ...[
                    const SizedBox(height: AppSpacing.x3),
                    _Notice(
                      'Another guard already handled this card, or it timed '
                      'out. Close this and ask the visitor to tap again if '
                      'they are still at the gate.',
                      intent: t.status.warning,
                    ),
                  ],
                  if (_error case final error?) ...[
                    const SizedBox(height: AppSpacing.x3),
                    _Notice(error, intent: t.status.danger),
                  ],
                  const SizedBox(height: AppSpacing.x3),
                  const AppRequiredNote(),
                  VisitorDetailsFields(
                    name: _name,
                    plate: _plate,
                    purpose: _purpose,
                    vehicleType: _vehicleType,
                    onVehicleTypeChanged: (v) =>
                        setState(() => _vehicleType = v),
                    autofocusName: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: gone
            ? [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ]
            : [
                TextButton(
                  onPressed: _busy ? null : _turnAway,
                  child: const Text('Turn away'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.login),
                  label: const Text('Save and open gate'),
                ),
              ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {required this.intent});

  final String message;
  final StatusColors intent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: intent.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: intent.fg),
      ),
    );
  }
}
