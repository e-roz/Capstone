/// One line in the review queue.
///
/// Carries counts rather than the checks themselves: the list only needs to say
/// which applications deserve time, and the detail screen holds the evidence.
class PendingRegistration {
  final String userId;
  final String fullName;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `Clear`, `LookCloser`, `Unreadable`, or `None` when nothing was submitted.
  final String checksVerdict;

  /// Ready to render — "2 need attention", "All 6 passed".
  final String checksSummary;

  final int checksNeedingAttention;
  final int checksUnreadable;

  /// Whole days since submission. Nothing else on the screen says this.
  final int waitingDays;

  const PendingRegistration({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    required this.checksVerdict,
    required this.checksSummary,
    required this.checksNeedingAttention,
    required this.checksUnreadable,
    required this.waitingDays,
  });

  /// Worst first, so sorting the column puts the applications that need a human
  /// at the top rather than sorting them alphabetically by their summary text.
  int get concernRank => switch (checksVerdict) {
        'LookCloser' => 3,
        'Unreadable' => 2,
        'Clear' => 1,
        _ => 0,
      };

  factory PendingRegistration.fromJson(Map<String, dynamic> json) =>
      PendingRegistration(
        userId: json['userId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'].toString()),
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
        checksVerdict: json['checksVerdict']?.toString() ?? 'None',
        checksSummary: json['checksSummary']?.toString() ?? '',
        checksNeedingAttention:
            (json['checksNeedingAttention'] as num?)?.toInt() ?? 0,
        checksUnreadable: (json['checksUnreadable'] as num?)?.toInt() ?? 0,
        waitingDays: (json['waitingDays'] as num?)?.toInt() ?? 0,
      );
}
