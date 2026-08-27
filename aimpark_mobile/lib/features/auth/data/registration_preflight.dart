import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/name_matching.dart';

/// One thing that will cost the applicant their submission, found before they
/// make it.
class PreflightFinding {
  const PreflightFinding({
    required this.message,
    required this.intent,
  });

  final String message;

  /// [StatusIntent.danger] for something an admin will certainly reject,
  /// [StatusIntent.warning] for something they will look twice at.
  final StatusIntent intent;

  bool get isBlocking => intent == StatusIntent.danger;
}

/// How close an expiry has to be before it is worth mentioning.
///
/// Mirrors `RegistrationChecks.ExpiringSoonDays` on the server, which warns the
/// reviewer on the same threshold. Nothing re-checks a document after approval,
/// so a licence lapsing next month means an RFID card that keeps opening the
/// gate against a dead licence.
const int expiringSoonDays = 30;

/// Everything the app can tell about a submission before sending it.
///
/// All of this was already known at this point and none of it was being used:
/// the expiry dates and both names sit on the confirmation screen, editable,
/// while the server's own checks — which do compare them — only run once the
/// application is in the queue. So an applicant with an expired licence
/// submitted, waited days, and was rejected for something the phone in their
/// hand could have told them immediately.
///
/// Deliberately advisory. A finding is not a reason to refuse the submission:
/// OCR misreads dates, the applicant may have a renewal in progress, and the
/// reviewer decides in the end. The purpose is to stop someone spending a week
/// finding out something they could have known now.
///
/// Recomputed on every keystroke from the *current* field values, not from what
/// the scan returned, so correcting a misread expiry clears its warning.
List<PreflightFinding> registrationPreflight({
  required DateTime? licenseExpiry,
  required DateTime? registrationExpiry,
  required String? documentName,
  required String? licenseName,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final findings = <PreflightFinding>[];

  void checkExpiry(DateTime? date, String what, String advice) {
    if (date == null) return;

    // Whole days, on the calendar date rather than the instant — an expiry is a
    // day, and "expires in 0 days" should mean today, not fourteen hours.
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(today.year, today.month, today.day);
    final days = day.difference(start).inDays;

    if (days < 0) {
      findings.add(PreflightFinding(
        message: 'Your $what expired on ${Formatters.date(date)}. $advice',
        intent: StatusIntent.danger,
      ));
    } else if (days <= expiringSoonDays) {
      findings.add(PreflightFinding(
        message: 'Your $what expires on ${Formatters.date(date)}'
            '${days == 0 ? ' — today' : ', in $days day${days == 1 ? '' : 's'}'}. '
            'It may be worth renewing it before you apply.',
        intent: StatusIntent.warning,
      ));
    }
  }

  checkExpiry(
    licenseExpiry,
    'licence',
    'An expired licence is normally refused — check the date is right, or renew '
        'it before applying.',
  );

  checkExpiry(
    registrationExpiry,
    'vehicle registration',
    'An expired registration is normally refused — check the date is right, or '
        'renew it before applying.',
  );

  // Both names have to be readable before a difference means anything. A blank
  // one is a field OCR missed, which the field's own warning already covers —
  // saying it twice, in different words, would read as two separate problems.
  //
  // The receipt's owner name is deliberately not compared anywhere: campus users
  // commonly drive a vehicle registered to a parent, so a mismatch there is
  // expected and proves nothing.
  final left = documentName?.trim() ?? '';
  final right = licenseName?.trim() ?? '';

  if (left.isNotEmpty &&
      right.isNotEmpty &&
      !isProbableNameMatch(left, right)) {
    findings.add(PreflightFinding(
      message: 'The name on your licence ($right) does not look like the name '
          'on your other document ($left). If one of them was read wrong, '
          'correct it above.',
      intent: StatusIntent.warning,
    ));
  }

  return findings;
}
