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
      );

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
