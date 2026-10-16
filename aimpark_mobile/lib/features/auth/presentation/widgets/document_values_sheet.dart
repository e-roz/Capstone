import 'package:flutter/material.dart';

import '../../../../core/ocr/ocr_payload.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/document_spec.dart';
import '../../data/models/scan_result.dart';
import 'scanned_field.dart';

/// What the user decided on the sheet.
class DocumentSheetOutcome {
  const DocumentSheetOutcome.retake({this.forgiveTry = false}) : values = null;

  const DocumentSheetOutcome.confirmed(Map<String, String> this.values)
    : forgiveTry = false;

  /// The values agreed to, by the server's field name. Null for a retake.
  final Map<String, String>? values;

  /// The retake is for a different document, not a better photo of this one,
  /// so it should not use up a try. Set when the document was expired.
  final bool forgiveTry;

  bool get isRetake => values == null;
}

/// One value a document gives, as the sheet shows it.
class _FieldSpec {
  const _FieldSpec(
    this.field,
    this.label, {
    this.isDate = false,
    this.capitalization = TextCapitalization.words,
  });

  /// The server's field name, e.g. `LicenseNumber`.
  final String field;
  final String label;
  final bool isDate;
  final TextCapitalization capitalization;
}

/// The values each document is read for. Vehicle type is not here: it is a
/// two-way choice, made on the last screen with the colour swatches beside it.
const _fieldsFor = <ScanDocumentType, List<_FieldSpec>>{
  ScanDocumentType.raf: [
    _FieldSpec(
      'StudentNumber',
      'Student number',
      capitalization: TextCapitalization.characters,
    ),
    _FieldSpec('StudentName', 'Full name'),
    _FieldSpec(
      'Section',
      'Section',
      capitalization: TextCapitalization.characters,
    ),
    _FieldSpec('Semester', 'Term'),
  ],
  ScanDocumentType.license: [
    _FieldSpec('LicenseName', 'Name on licence'),
    _FieldSpec(
      'LicenseNumber',
      'Licence number',
      capitalization: TextCapitalization.characters,
    ),
    _FieldSpec('LicenseExpiry', 'Licence expiry', isDate: true),
  ],
  ScanDocumentType.officialReceipt: [
    _FieldSpec(
      'PlateNumber',
      'Plate number',
      capitalization: TextCapitalization.characters,
    ),
    _FieldSpec('RegistrationExpiry', 'Registration expiry', isDate: true),
    _FieldSpec('Color', 'Colour'),
  ],
};

String? _textOf(ExtractedValues e, String field) => switch (field) {
  'StudentNumber' => e.studentNumber,
  'StudentName' => e.studentName,
  'Section' => e.section,
  'Semester' => e.semester,
  'LicenseName' => e.licenseName,
  'LicenseNumber' => e.licenseNumber,
  'PlateNumber' => e.plateNumber,
  'Color' => e.color,
  _ => null,
};

DateTime? _dateOf(ExtractedValues e, String field) => switch (field) {
  'LicenseExpiry' => e.licenseExpiry,
  'RegistrationExpiry' => e.registrationExpiry,
  _ => null,
};

/// Shows what was read from one document, right after it was photographed.
///
/// Three things can happen here. The photo did not read, or a value is
/// missing, and tries remain: the user takes it again, and the sheet says
/// which try this was. The tries are spent: the missing values open for
/// typing, and the admin sees they were typed. Everything read: the user checks
/// each value, and a value the OCR read is only changed after "Are you sure?".
///
/// An expired licence or receipt stops here with the date that was read, so a
/// misread can be corrected. A corrected date is checked again. Using another
/// document instead does not cost a try.
class DocumentValuesSheet extends StatefulWidget {
  const DocumentValuesSheet({
    super.key,
    required this.spec,
    required this.result,
    required this.attempt,
    required this.maxAttempts,
  });

  final DocumentSpec spec;
  final DocumentReadResult result;

  /// Which photo of this document this was, from 1.
  final int attempt;
  final int maxAttempts;

  static Future<DocumentSheetOutcome?> show(
    BuildContext context, {
    required DocumentSpec spec,
    required DocumentReadResult result,
    required int attempt,
    required int maxAttempts,
  }) {
    return showModalBottomSheet<DocumentSheetOutcome>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DocumentValuesSheet(
        spec: spec,
        result: result,
        attempt: attempt,
        maxAttempts: maxAttempts,
      ),
    );
  }

  @override
  State<DocumentValuesSheet> createState() => _DocumentValuesSheetState();
}

class _DocumentValuesSheetState extends State<DocumentValuesSheet> {
  final _controllers = <String, TextEditingController>{};
  final _dates = <String, DateTime?>{};

  List<_FieldSpec> get _fields => _fieldsFor[widget.spec.type] ?? const [];

  ExtractedValues get _extracted => widget.result.extracted;

  bool get _triesLeft => widget.attempt < widget.maxAttempts;

  /// Another photo of the same document would help: it did not read, or a
  /// value is missing, and the user still has tries.
  bool get _mustRetake => widget.result.diagnosis != null && _triesLeft;

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      if (f.isDate) {
        _dates[f.field] = _dateOf(_extracted, f.field);
      } else {
        final controller = TextEditingController(
          text: _textOf(_extracted, f.field) ?? '',
        );
        controller.addListener(() => setState(() {}));
        _controllers[f.field] = controller;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// The expiry date as it now stands, and whether it still stops registration.
  ///
  /// Checked here as well as on the server so a corrected date clears the block
  /// at once. A calculated receipt date never blocks; only an unchanged one is
  /// known to be calculated.
  ({DateTime? date, bool expired, bool blocks})? get _expiryState {
    final expiry = widget.result.expiry;
    if (expiry == null) return null;

    final date = _dates[expiry.field];
    if (date == null) return (date: null, expired: false, blocks: false);

    final today = DateUtils.dateOnly(DateTime.now());
    final expired = DateUtils.dateOnly(date).isBefore(today);
    final unchanged =
        expiry.date != null &&
        DateUtils.isSameDay(DateUtils.dateOnly(date), DateUtils.dateOnly(expiry.date!));
    final calculated = expiry.isCalculated && unchanged;

    return (date: date, expired: expired, blocks: expired && !calculated);
  }

  bool get _allFilled {
    for (final f in _fields) {
      if (f.isDate ? _dates[f.field] == null : _controllers[f.field]!.text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  String get _documentWord => switch (widget.spec.type) {
    ScanDocumentType.license => 'licence',
    ScanDocumentType.officialReceipt => 'receipt',
    ScanDocumentType.raf => 'registration form',
  };

  void _confirm() {
    final values = <String, String>{
      for (final f in _fields)
        if (f.isDate)
          f.field: _dates[f.field]!.toIso8601String()
        else
          f.field: _controllers[f.field]!.text.trim(),
    };
    Navigator.of(context).pop(DocumentSheetOutcome.confirmed(values));
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = widget.result.diagnosis;
    final expiry = _expiryState;
    final blocked = expiry?.blocks ?? false;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _mustRetake
                    ? 'Take the ${widget.spec.label} again'
                    : 'This is what we read from your ${widget.spec.label}',
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Try ${widget.attempt} of ${widget.maxAttempts}',
                style: context.text.labelMedium?.copyWith(
                  color: context.tokens.text.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_mustRetake) ..._retakeBody(diagnosis!) else ..._valuesBody(diagnosis, expiry, blocked),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _retakeBody(DocumentDiagnosis diagnosis) => [
    AppNotice(message: diagnosis.message, intent: StatusIntent.danger),
    const SizedBox(height: AppSpacing.sm),
    Text(
      'You can take this photo ${widget.maxAttempts} times. After that you '
      'can type what we could not read, and the admin will see it was typed.',
      style: context.text.bodySmall,
    ),
    const SizedBox(height: AppSpacing.lg),
    AppButton(
      label: 'Take it again (try ${widget.attempt + 1} of ${widget.maxAttempts})',
      onPressed: () =>
          Navigator.of(context).pop(const DocumentSheetOutcome.retake()),
    ),
  ];

  List<Widget> _valuesBody(
    DocumentDiagnosis? diagnosis,
    ({DateTime? date, bool expired, bool blocks})? expiry,
    bool blocked,
  ) {
    final calculatedWarning =
        expiry != null && expiry.expired && !expiry.blocks;

    return [
      if (diagnosis != null) ...[
        AppNotice(
          title: 'You have used all ${widget.maxAttempts} tries',
          message: 'Type what we could not read. The admin will see it was '
              'typed, not read.',
          intent: StatusIntent.warning,
        ),
        const SizedBox(height: AppSpacing.md),
      ] else ...[
        Text(
          'Check each one. A lock means we read it. Tap it to change it. The '
          'admin will see anything you change.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      for (final f in _fields)
        if (f.isDate)
          ScannedDateField(
            label: f.label,
            value: _dates[f.field],
            flag: _extracted.flagFor(f.field),
            onChanged: (d) => setState(() => _dates[f.field] = d),
          )
        else
          ScannedField(
            label: f.label,
            controller: _controllers[f.field]!,
            flag: _extracted.flagFor(f.field),
            textCapitalization: f.capitalization,
          ),
      if (widget.spec.type == ScanDocumentType.officialReceipt &&
          _extracted.vehicleType != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Vehicle type: ${_extracted.vehicleType}. You choose this on the '
          'last screen.',
          style: context.text.bodySmall,
        ),
      ],
      if (blocked) ...[
        const SizedBox(height: AppSpacing.md),
        AppNotice(
          title: 'This $_documentWord is expired',
          message: _expiredMessage(expiry!.date!),
          intent: StatusIntent.danger,
        ),
      ] else if (calculatedWarning && widget.result.expiry?.message != null) ...[
        const SizedBox(height: AppSpacing.md),
        AppNotice(
          message: widget.result.expiry!.message!,
          intent: StatusIntent.warning,
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      if (blocked)
        AppButton(
          label: 'Use another $_documentWord',
          onPressed: () => Navigator.of(context).pop(
            const DocumentSheetOutcome.retake(forgiveTry: true),
          ),
        )
      else
        AppButton(
          label: 'This is correct',
          onPressed: _allFilled ? _confirm : null,
        ),
      if (!blocked && !_allFilled)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            'Fill in every value to continue.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ),
    ];
  }

  /// The server's own sentence while the date is the one it read; a fresh one
  /// once the user has changed it.
  String _expiredMessage(DateTime date) {
    final read = widget.result.expiry;
    if (read?.message != null &&
        read?.date != null &&
        DateUtils.isSameDay(DateUtils.dateOnly(read!.date!), DateUtils.dateOnly(date))) {
      return read.message!;
    }
    return 'The date you entered, ${Formatters.date(date)}, has passed. This '
        '$_documentWord is expired. Please use a valid one.';
  }
}
