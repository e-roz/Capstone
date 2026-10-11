import '../../../core/theme/theme.dart';

/// Where a report stands, in the words a person would use.
///
/// The API sends the status as a bare enum name — `UnderReview`, not "Under
/// review" — and the badge used to print it as it came. Everything the app says
/// about a status lives here, so the list, the report and the tracker cannot
/// describe the same stage three ways.
///
/// The five stages are the server's own. The tracker only ever shows the three a
/// report can *progress* through; [dismissed] and [withdrawn] are ways it ends.
enum IncidentStage {
  submitted,
  underReview,
  resolved,
  dismissed,
  withdrawn;

  /// Reads the API's status string, in any casing or spacing it might arrive in.
  /// Anything unrecognised is treated as submitted — the earliest, least
  /// committal stage — rather than guessed to be finished.
  static IncidentStage fromApi(String status) =>
      switch (status.toLowerCase().replaceAll(' ', '')) {
        'underreview' => underReview,
        'resolved' => resolved,
        'dismissed' => dismissed,
        'withdrawn' => withdrawn,
        _ => submitted,
      };

  String get label => switch (this) {
        submitted => 'Submitted',
        underReview => 'Under review',
        resolved => 'Resolved',
        dismissed => 'Dismissed',
        withdrawn => 'Withdrawn',
      };

  /// Still in play: waiting for, or in the middle of, a decision.
  bool get isActive => this == submitted || this == underReview;

  /// Can still be edited or taken back. Mirrors the server's rule — it refuses
  /// both once anyone has started reviewing — so the buttons never offer
  /// something that will fail.
  bool get canModify => this == submitted;

  /// The colour that goes with the stage.
  ///
  /// Dismissed and withdrawn are grey: neither is an error and neither is a
  /// penalty. A dismissed report was looked at and closed without further action,
  /// and a withdrawn one was the reporter's own choice; red would say something
  /// had gone wrong, and blue — what a withdrawn report used to be, by default —
  /// made it look the same as one still waiting.
  StatusIntent get intent => switch (this) {
        submitted => StatusIntent.info,
        underReview => StatusIntent.warning,
        resolved => StatusIntent.success,
        dismissed || withdrawn => StatusIntent.neutral,
      };

  /// What this means for the person, in a sentence or two.
  String get explanation => switch (this) {
        submitted =>
          "We've received your report. The parking office hasn't looked at it "
              'yet. You can still edit or withdraw it.',
        underReview =>
          'The parking office is looking into your report. It can no longer be '
              "changed. We'll notify you when it's decided.",
        resolved => 'Your report was dealt with. Thank you for flagging it.',
        dismissed =>
          'The parking office reviewed your report and closed it without '
              'further action.',
        withdrawn => 'You withdrew this report, so it will not be reviewed.',
      };
}
