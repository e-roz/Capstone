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

/// An editable value the document scan produced, with the reason it needs
/// attention if it does.
///
/// A field that was read cleanly looks like any other field. One the rules
/// missed carries a red note telling the user to type it; one that was inferred
/// carries a muted note asking them to glance at it. That difference is why
/// extraction accuracy is not load-bearing: a miss costs one line of typing
/// rather than retake after retake.
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
  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final note = flagText(widget.flag);
    final missing =
        fieldStillMissing(widget.flag, widget.controller.text.trim().isEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppTextField(
        label: widget.label,
        controller: widget.controller,
        enabled: widget.enabled,
        textCapitalization: widget.textCapitalization,
        // A missed field is an error the user has to fix; an inferred one is
        // only worth a glance. Routing them to errorText and helperText makes
        // the field itself carry the difference, instead of the pale grey line
        // underneath that both used to share.
        errorText: missing ? note : null,
        helperText: widget.flag == FieldFlag.derived ? note : null,
      ),
    );
  }
}

/// The date equivalent of [ScannedField].
class ScannedDateField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final note = flagText(flag);
    final missing = fieldStillMissing(flag, value == null);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppDateField(
        label: label,
        value: value,
        onChanged: onChanged,
        enabled: enabled,
        format: Formatters.date,
        errorText: missing ? note : null,
        helperText: flag == FieldFlag.derived ? note : null,
      ),
    );
  }
}
