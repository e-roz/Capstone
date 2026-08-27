import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The chrome shared by every input in the app: the label above, the rounded
/// bordered container, and the error or helper line below.
///
/// Extracted so a field that is not a [TextField] — a date, a colour, a
/// picker — can sit in a form without visibly being a different kind of thing.
/// The registration confirmation screen's date field was built on a raw
/// [InputDecorator] with Material's default border and was the one input in the
/// app that did not match the four directly above it.
class AppFieldShell extends StatelessWidget {
  const AppFieldShell({
    super.key,
    required this.label,
    required this.child,
    this.focused = false,
    this.enabled = true,
    this.errorText,
    this.helperText,
  });

  final String label;

  /// The control itself, rendered inside the bordered container.
  final Widget child;

  /// Drives the focus ring. A field with no focus concept passes false.
  final bool focused;

  final bool enabled;

  /// Shown in red below the field. Null or empty means no error.
  final String? errorText;

  /// Shown muted below the field when there is no error. For explaining what a
  /// value is for *before* the user gets it wrong, rather than after.
  final String? helperText;

  bool get _hasError => errorText != null && errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final borderColor = !enabled
        ? t.border.subtle
        : _hasError
            ? t.status.danger.solid
            : (focused ? t.border.focus : t.border.normal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.text.labelSmall),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            color: enabled ? t.surface.card : t.surface.muted,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: borderColor, width: focused ? 2 : 1.5),
          ),
          child: child,
        ),
        if (_hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: context.text.labelSmall?.copyWith(color: t.status.danger.fg),
          ),
        ] else if (helperText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(helperText!, style: context.text.labelSmall),
        ],
      ],
    );
  }
}

/// AimPark text field — rounded border, brand focus ring, flat fill.
///
/// Wraps the standard [TextField] so every form across the app shares one
/// visual treatment instead of each screen hand-rolling an [InputDecoration].
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.prefixIcon,
    this.suffixIcon,
    this.onSubmitted,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _isFocused = _focusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppFieldShell(
      label: widget.label,
      focused: _isFocused,
      enabled: widget.enabled,
      errorText: widget.errorText,
      helperText: widget.helperText,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        autofillHints: widget.autofillHints,
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        maxLength: widget.maxLength,
        style: context.text.bodyLarge,
        cursorColor: t.brand.primary,
        decoration: InputDecoration(
          // The shell draws the border. Anything but `none` here paints a
          // second outline a pixel inside the first.
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
          // The counter would otherwise reserve a line under every field that
          // sets maxLength, breaking alignment with the fields beside it.
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, color: t.text.secondary)
              : null,
          suffixIcon: widget.suffixIcon,
        ),
      ),
    );
  }
}

/// A password field with a reveal toggle.
///
/// Four password inputs across the app — sign-in, and the three on Change
/// Password — were plain obscured fields with no way to check what had been
/// typed. On a phone keyboard that turns one mistyped character into starting
/// over, and it is the single most common reason a correct password gets
/// reported as rejected.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.label,
    this.controller,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String? helperText;
  final bool enabled;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      obscureText: _obscured,
      enabled: widget.enabled,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      errorText: widget.errorText,
      helperText: widget.helperText,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: AppSizes.iconMd,
        ),
        tooltip: _obscured ? 'Show password' : 'Hide password',
      ),
    );
  }
}

/// A field that opens a date picker instead of a keyboard.
///
/// Looks exactly like [AppTextField] because it shares [AppFieldShell] with it,
/// which is the point: a form should not visibly change construction halfway
/// down.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.format,
    this.firstDate,
    this.lastDate,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.hint = 'Tap to choose',
  });

  final String label;
  final DateTime? value;

  /// Null leaves the field readable but not editable.
  final ValueChanged<DateTime>? onChanged;

  /// How to render a chosen date — pass `Formatters.date`. Required rather
  /// than defaulted, so a screen cannot accidentally ship an ISO string.
  final String Function(DateTime) format;

  /// Defaults to a twenty-year window either side of today — wide enough for a
  /// licence renewed years ago and one valid for years yet.
  final DateTime? firstDate;
  final DateTime? lastDate;

  final String? helperText;
  final String? errorText;
  final bool enabled;
  final String hint;

  bool get _interactive => enabled && onChanged != null;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(now.year - 20),
      lastDate: lastDate ?? DateTime(now.year + 20),
    );
    if (picked == null) return;

    // Normalised to UTC midnight on the chosen calendar day, and this is not
    // cosmetic — it is the difference between the form saving and returning a
    // 500.
    //
    // `showDatePicker` returns a *local* DateTime, and `toIso8601String()`
    // appends `Z` only for UTC values. A local date therefore serialises as
    // `2028-08-22T00:00:00.000` with no zone, System.Text.Json deserialises
    // that to `DateTimeKind.Unspecified`, and Npgsql refuses to write an
    // Unspecified DateTime into a `timestamp with time zone` column. Dates the
    // server sent us survive the round trip because they arrive with a `Z`
    // already; only the ones a user picks by hand blow up, which is why this
    // only ever failed on a field OCR had missed.
    //
    // `.toUtc()` would be the wrong repair: midnight in Manila is 16:00 the
    // *previous* day in UTC, so a licence expiring on the 22nd would be stored
    // as the 21st. An expiry is a calendar date, not an instant, so the day is
    // what has to survive — hence rebuilding it rather than converting it.
    onChanged?.call(DateTime.utc(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasValue = value != null;

    return AppFieldShell(
      label: label,
      enabled: enabled,
      helperText: helperText,
      errorText: errorText,
      child: InkWell(
        onTap: _interactive ? () => _pick(context) : null,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? format(value!) : hint,
                  style: context.text.bodyLarge?.copyWith(
                    color: hasValue ? t.text.primary : t.text.secondary,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                size: AppSizes.iconMd,
                color: t.text.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
