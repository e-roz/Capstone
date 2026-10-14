/// What the automated checks found on one application.
///
/// The API sends this already arranged for reading — a group for the person, a
/// group per vehicle, and the findings pulled out into [headlines]. Nothing is
/// recomputed here: a panel that disagreed with the summary above it would be
/// worse than no panel at all.
class RegistrationChecks {
  /// `Clear`, `LookCloser`, or `Unreadable`.
  final String verdict;

  /// The banner's line, written by the API.
  final String summary;

  final int total;
  final int needsAttention;
  final int unreadable;

  /// Every finding worth saying out loud, already in reviewer's words.
  final List<String> headlines;

  final CheckGroup? person;
  final List<CheckGroup> vehicles;
  final List<ValueEdit> edits;

  /// Every check and edit as one list, already most serious first.
  final List<Finding> findings;

  /// The values the review screen's key facts grid shows.
  final RegistrationFacts facts;

  /// What the phone read, per document, in the order the API sent them.
  final List<DocumentReading> readings;

  const RegistrationChecks({
    required this.verdict,
    required this.summary,
    required this.total,
    required this.needsAttention,
    required this.unreadable,
    required this.headlines,
    required this.person,
    required this.vehicles,
    required this.edits,
    this.findings = const [],
    this.facts = const RegistrationFacts(),
    this.readings = const [],
  });

  factory RegistrationChecks.fromJson(Map<String, dynamic> json) =>
      RegistrationChecks(
        verdict: json['verdict']?.toString() ?? 'Unreadable',
        summary: json['summary']?.toString() ?? '',
        total: (json['total'] as num?)?.toInt() ?? 0,
        needsAttention: (json['needsAttention'] as num?)?.toInt() ?? 0,
        unreadable: (json['unreadable'] as num?)?.toInt() ?? 0,
        headlines: (json['headlines'] as List<dynamic>? ?? [])
            .map((h) => h.toString())
            .toList(),
        person: json['person'] == null
            ? null
            : CheckGroup.fromJson(json['person'] as Map<String, dynamic>),
        vehicles: (json['vehicles'] as List<dynamic>? ?? [])
            .map((v) => CheckGroup.fromJson(v as Map<String, dynamic>))
            .toList(),
        edits: (json['edits'] as List<dynamic>? ?? [])
            .map((e) => ValueEdit.fromJson(e as Map<String, dynamic>))
            .toList(),
        findings: (json['findings'] as List<dynamic>? ?? [])
            .map((f) => Finding.fromJson(f as Map<String, dynamic>))
            .toList(),
        facts: json['facts'] == null
            ? const RegistrationFacts()
            : RegistrationFacts.fromJson(json['facts'] as Map<String, dynamic>),
        readings: (json['readings'] as List<dynamic>? ?? [])
            .map((r) => DocumentReading.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  /// What the summary box counts and the findings list shows above its
  /// collapsed "passed" row. One list feeds both, so they cannot disagree.
  List<Finding> get open =>
      findings.where((f) => f.category != FindingCategory.passed).toList();

  List<Finding> get passed =>
      findings.where((f) => f.category == FindingCategory.passed).toList();

  /// Whether anything is red or amber — what decides how Approve is offered.
  bool get hasSerious => findings.any((f) => f.severity.isSerious);

  /// The most serious finding about [keys] — a pass only when nothing worse
  /// exists — so a key fact can say its state in the same words as the list.
  Finding? findingFor(Set<String> keys) {
    Finding? worst;
    for (final f in findings) {
      if (!keys.contains(f.key)) continue;
      if (worst == null || f.severity.index < worst.severity.index) worst = f;
    }
    return worst;
  }

  /// Whether the applicant typed over the phone's reading of [field]
  /// (`Edit.Name`, `Edit.Licencenumber`, …).
  bool edited(String key) => findings.any((f) => f.key == key);

  /// Every check across every group, for the rare caller that wants them flat.
  Iterable<CheckItem> get all sync* {
    if (person case final group?) yield* group.checks;
    for (final group in vehicles) {
      yield* group.checks;
    }
  }

  /// The first failing check of a kind, so the reject dialog can suggest the
  /// preset that matches what actually went wrong.
  CheckItem? firstFailing(Set<String> keys) {
    for (final check in all) {
      if (keys.contains(check.key) && check.state == CheckState.failed) {
        return check;
      }
    }
    return null;
  }
}

class CheckGroup {
  final String title;

  /// Which documents these came from — shown so the reviewer knows where to look.
  final String source;

  final List<CheckItem> checks;

  const CheckGroup({
    required this.title,
    required this.source,
    required this.checks,
  });

  factory CheckGroup.fromJson(Map<String, dynamic> json) => CheckGroup(
        title: json['title']?.toString() ?? '',
        source: json['source']?.toString() ?? '',
        checks: (json['checks'] as List<dynamic>? ?? [])
            .map((c) => CheckItem.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// The four things a check can say.
///
/// [notChecked] is not a soft failure — a value was missing, so the check could
/// not form an opinion. That is the reason a human is looking at this at all,
/// and it is coloured neutral rather than red for exactly that reason.
enum CheckState { passed, expiringSoon, failed, notChecked }

class CheckItem {
  /// Stable key from the API (`NameMatch`, `LicenseValidity`, …). Match on this,
  /// never on [label], which is wording and may change.
  final String key;

  final String label;
  final CheckState state;

  /// The finding in plain words, or null when there is nothing to report.
  final String? detail;

  /// The values compared, so the reviewer sees the evidence and not just a verdict.
  final List<CheckValue> values;

  const CheckItem({
    required this.key,
    required this.label,
    required this.state,
    required this.detail,
    required this.values,
  });

  factory CheckItem.fromJson(Map<String, dynamic> json) => CheckItem(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        state: _state(json['state']?.toString()),
        detail: json['detail']?.toString(),
        values: (json['values'] as List<dynamic>? ?? [])
            .map((v) => CheckValue.fromJson(v as Map<String, dynamic>))
            .toList(),
      );

  // An unknown state from a newer API reads as "could not check" rather than
  // throwing — a grey row is survivable, a crashed review screen is not.
  static CheckState _state(String? raw) => switch (raw) {
        'Passed' => CheckState.passed,
        'ExpiringSoon' => CheckState.expiringSoon,
        'Failed' => CheckState.failed,
        _ => CheckState.notChecked,
      };
}

class CheckValue {
  final String label;
  final String value;

  const CheckValue({required this.label, required this.value});

  factory CheckValue.fromJson(Map<String, dynamic> json) => CheckValue(
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
      );
}

/// A value the applicant typed over what the phone read.
class ValueEdit {
  final String field;

  /// Null when nothing readable came off the document.
  final String? read;

  final String submitted;

  /// Name and student number. A typed identity value proves nothing about who
  /// the applicant is, which is why these are called out rather than listed.
  final bool isIdentity;

  const ValueEdit({
    required this.field,
    required this.read,
    required this.submitted,
    required this.isIdentity,
  });

  factory ValueEdit.fromJson(Map<String, dynamic> json) => ValueEdit(
        field: json['field']?.toString() ?? '',
        read: json['read']?.toString(),
        submitted: json['submitted']?.toString() ?? '',
        isIdentity: (json['isIdentity'] as bool?) ?? false,
      );
}

// ── Findings ─────────────────────────────────────────────────────────────────

enum FindingCategory { identity, validity, edited, notChecked, passed }

/// Ordered most serious first, so `index` compares.
enum FindingSeverity {
  danger,
  warning,
  neutral,
  passed;

  bool get isSerious => this == danger || this == warning;
}

/// One row of the review screen's findings list.
class Finding {
  final String key;
  final FindingCategory category;
  final FindingSeverity severity;
  final String title;
  final String? detail;

  /// `Raf`, `License` or `OfficialReceipt`: which tab to open.
  final String? document;

  const Finding({
    required this.key,
    required this.category,
    required this.severity,
    required this.title,
    this.detail,
    this.document,
  });

  factory Finding.fromJson(Map<String, dynamic> json) => Finding(
        key: json['key']?.toString() ?? '',
        category: findingCategory(json['category']?.toString()),
        severity: findingSeverity(json['severity']?.toString()),
        title: json['title']?.toString() ?? '',
        detail: json['detail']?.toString(),
        document: json['document']?.toString(),
      );
}

// Unknown values from a newer API read as grey, never as a pass.
FindingCategory findingCategory(String? raw) => switch (raw) {
      'Identity' => FindingCategory.identity,
      'Validity' => FindingCategory.validity,
      'Edited' => FindingCategory.edited,
      'Passed' => FindingCategory.passed,
      _ => FindingCategory.notChecked,
    };

FindingSeverity findingSeverity(String? raw) => switch (raw) {
      'Danger' => FindingSeverity.danger,
      'Warning' => FindingSeverity.warning,
      'Passed' => FindingSeverity.passed,
      _ => FindingSeverity.neutral,
    };

// ── Facts ────────────────────────────────────────────────────────────────────

/// Read from the submission rather than the account: the account only gets
/// its student number on approval, which is why it used to show nowhere.
class RegistrationFacts {
  final String? schoolFormName;
  final String? licenseName;
  final String? studentNumber;
  final bool studentNumberTyped;
  final String? section;
  final String? semester;

  /// Masked by the API except the last four characters.
  final String? licenseNumberMasked;
  final bool licenseNumberTyped;
  final DateTime? licenseExpiry;
  final List<VehicleFacts> vehicles;

  const RegistrationFacts({
    this.schoolFormName,
    this.licenseName,
    this.studentNumber,
    this.studentNumberTyped = false,
    this.section,
    this.semester,
    this.licenseNumberMasked,
    this.licenseNumberTyped = false,
    this.licenseExpiry,
    this.vehicles = const [],
  });

  factory RegistrationFacts.fromJson(Map<String, dynamic> json) =>
      RegistrationFacts(
        schoolFormName: json['schoolFormName']?.toString(),
        licenseName: json['licenseName']?.toString(),
        studentNumber: json['studentNumber']?.toString(),
        studentNumberTyped: (json['studentNumberTyped'] as bool?) ?? false,
        section: json['section']?.toString(),
        semester: json['semester']?.toString(),
        licenseNumberMasked: json['licenseNumberMasked']?.toString(),
        licenseNumberTyped: (json['licenseNumberTyped'] as bool?) ?? false,
        licenseExpiry: _date(json['licenseExpiry']),
        vehicles: (json['vehicles'] as List<dynamic>? ?? [])
            .map((v) => VehicleFacts.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}

class VehicleFacts {
  final String? plateNumber;
  final DateTime? registrationExpiry;

  const VehicleFacts({this.plateNumber, this.registrationExpiry});

  factory VehicleFacts.fromJson(Map<String, dynamic> json) => VehicleFacts(
        plateNumber: json['plateNumber']?.toString(),
        registrationExpiry: _date(json['registrationExpiry']),
      );
}

DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw.toString());

// ── Readings ─────────────────────────────────────────────────────────────────

/// What the phone read off one document.
class DocumentReading {
  final String document;

  /// Empty when the phone read nothing from the document.
  final List<ReadingValue> values;

  const DocumentReading({required this.document, required this.values});

  factory DocumentReading.fromJson(Map<String, dynamic> json) =>
      DocumentReading(
        document: json['document']?.toString() ?? '',
        values: (json['values'] as List<dynamic>? ?? [])
            .map((v) => ReadingValue.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}

class ReadingValue {
  final String label;

  /// Null when nothing readable came off the document.
  final String? read;

  /// Null when the applicant kept what was read.
  final String? submitted;

  const ReadingValue({required this.label, this.read, this.submitted});

  factory ReadingValue.fromJson(Map<String, dynamic> json) => ReadingValue(
        label: json['label']?.toString() ?? '',
        read: json['read']?.toString(),
        submitted: json['submitted']?.toString(),
      );
}
