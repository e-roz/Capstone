import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/scan_result.dart';

/// Plain-language note under a field explaining why it wants a look.
///
/// A confidence score would mean nothing to someone holding a receipt, and
/// there is no different action to take at 0.62 than at 0.71 — so the two
/// reasons get different sentences instead of a number.
String? flagText(FieldFlag? flag) => switch (flag) {
      FieldFlag.notFound => "We couldn't read this one — please type it in.",
      FieldFlag.derived =>
        'Worked out from your plate number rather than read. Check it.',
      null => null,
    };

/// Whether a field the rules couldn't read is still empty.
///
/// The server's flag is a snapshot from the moment the screen opened; it never
/// changes. Only the user's typing does — so this, re-evaluated on every
/// keystroke, is what lets the warning clear the instant they fill the field in
/// rather than sitting there calling a now-answered field unread.
bool fieldStillMissing(FieldFlag? flag, bool isEmpty) =>
    flag == FieldFlag.notFound && isEmpty;

/// Whether a value arrived from the document and so starts out locked.
///
/// A missed field has nothing to protect, and a derived one was worked out
/// rather than read, so neither is the machine's reading to defend.
bool startsLocked(FieldFlag? flag, bool hasValue) => hasValue && flag == null;

/// Asks before a value the OCR read is changed.
///
/// The wording is deliberately the whole message. The reviewer is told about the
/// edit anyway; this is only a pause so a read value is not changed by a stray tap.
Future<bool> confirmEditingReadValue(BuildContext context, String label) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Edit $label?'),
      content: const Text(
        'This is what the OCR read. Are you sure you want to edit it?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Edit'),
        ),
      ],
    ),
  );

  return confirmed == true;
}

const _typedNote = 'Typed by you. The admin will check it.';
const _editedNote = 'Edited by you. The admin will see this change.';

/// A value the document scan produced, with the reason it needs attention if it
/// does.
///
/// A value that was read cleanly starts locked: it shows what the OCR read, and
/// changing it means tapping it and answering a question first. One the rules
/// missed is open with a red note, and one that was inferred is open with a
/// muted note asking for a glance. Editing is never removed, only slowed down —
/// the reviewer is told about every change either way.
class ScannedField extends StatefulWidget {
  const ScannedField({
    super.key,
    required this.label,
    required this.controller,
    this.flag,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.words,
  });

  final String label;
  final TextEditingController controller;
  final FieldFlag? flag;
  final bool enabled;
  final TextCapitalization textCapitalization;

  @override
  State<ScannedField> createState() => _ScannedFieldState();
}

class _ScannedFieldState extends State<ScannedField> {
  late bool _locked;

  /// Whether this value began as something the OCR read. Decides which note an
  /// open field carries: a changed reading, or a value typed from nothing.
  late final bool _wasRead;

  /// What the OCR read, kept to tell an unlocked-but-untouched field from one
  /// that was actually changed.
  late final String _original;

  @override
  void initState() {
    super.initState();
    _original = widget.controller.text;
    _wasRead = startsLocked(widget.flag, widget.controller.text.trim().isNotEmpty);
    _locked = _wasRead;
    // Typing into the controller doesn't otherwise rebuild this widget — the
    // parent screen only rebuilds on its own setState calls — so without this
    // listener a "we couldn't read this" warning would outlive the value the
    // user just typed to answer it.
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ScannedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _askToEdit() async {
    if (!await confirmEditingReadValue(context, widget.label)) return;
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_locked) {
      // Disabled underneath and caught on top: a disabled field swallows taps,
      // and the tap is the whole point of this one.
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _askToEdit : null,
          child: AbsorbPointer(
            child: AppTextField(
              label: widget.label,
              controller: widget.controller,
              enabled: false,
              textCapitalization: widget.textCapitalization,
              suffixIcon: Icon(
                Icons.lock_outline_rounded,
                size: AppSizes.iconMd,
                color: t.text.secondary,
              ),
            ),
          ),
        ),
      );
    }

    final note = flagText(widget.flag);
    final empty = widget.controller.text.trim().isEmpty;
    final missing = fieldStillMissing(widget.flag, empty);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppTextField(
        label: widget.label,
        controller: widget.controller,
        enabled: widget.enabled,
        textCapitalization: widget.textCapitalization,
        // Someone who just said yes to editing is about to type.
        autofocus: _wasRead,
        // A missed field is an error the user has to fix; an inferred one is
        // only worth a glance. Routing them to errorText and helperText makes
        // the field itself carry the difference, instead of the pale grey line
        // underneath that both used to share.
        errorText: missing ? note : null,
        helperText: widget.flag == FieldFlag.derived
            ? note
            : _wasRead
                ? (widget.controller.text != _original ? _editedNote : null)
                : widget.flag == FieldFlag.notFound && !empty
                    ? _typedNote
                    : null,
      ),
    );
  }
}

/// The date equivalent of [ScannedField].
class ScannedDateField extends StatefulWidget {
  const ScannedDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.flag,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime>? onChanged;
  final FieldFlag? flag;
  final bool enabled;

  @override
  State<ScannedDateField> createState() => _ScannedDateFieldState();
}

class _ScannedDateFieldState extends State<ScannedDateField> {
  late bool _locked;
  late final bool _wasRead;
  late final DateTime? _original;

  @override
  void initState() {
    super.initState();
    _original = widget.value;
    _wasRead = startsLocked(widget.flag, widget.value != null);
    _locked = _wasRead;
  }

  Future<void> _askToEdit() async {
    if (!await confirmEditingReadValue(context, widget.label)) return;
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _askToEdit : null,
          child: AbsorbPointer(
            child: AppDateField(
              label: widget.label,
              value: widget.value,
              onChanged: null,
              enabled: false,
              locked: true,
              format: Formatters.date,
            ),
          ),
        ),
      );
    }

    final note = flagText(widget.flag);
    final missing = fieldStillMissing(widget.flag, widget.value == null);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppDateField(
        label: widget.label,
        value: widget.value,
        onChanged: widget.onChanged,
        enabled: widget.enabled,
        format: Formatters.date,
        errorText: missing ? note : null,
        helperText: widget.flag == FieldFlag.derived
            ? note
            : _wasRead
                ? (widget.value != _original ? _editedNote : null)
                : widget.flag == FieldFlag.notFound && widget.value != null
                    ? _typedNote
                    : null,
      ),
    );
  }
}
