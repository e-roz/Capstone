/// What the open session costs right now, from
/// `GET /api/parking/sessions/{logId}/live-fee`.
///
/// Every amount is the server's. The app never works out a fee itself: the
/// server prices it the same way as pay-ahead and the exit gate, so the number
/// on the phone is the number at the barrier.
class LiveFee {
  const LiveFee({
    required this.asOf,
    required this.durationMinutes,
    required this.ratePerHour,
    required this.minimumFee,
    required this.totalSoFar,
    required this.meteredSoFar,
    required this.alreadyPaid,
    required this.owedNow,
    required this.paymentProcessing,
    this.leaveBy,
    this.nextChangeAt,
    this.nextTotal,
  });

  /// The server's clock when this was priced.
  final DateTime asOf;
  final int durationMinutes;
  final double ratePerHour;
  final double minimumFee;

  /// What the whole stay costs if the driver left now.
  final double totalSoFar;

  /// Minutes × rate, before any minimum: the working shown under the amount.
  final double meteredSoFar;

  /// Paid or waived already for this session.
  final double alreadyPaid;

  /// [totalSoFar] less [alreadyPaid].
  final double owedNow;

  /// A checkout is open and the provider has not answered yet.
  final bool paymentProcessing;

  /// Paid ahead: the barrier opens on a tap until this time.
  final DateTime? leaveBy;

  /// When [totalSoFar] next goes up, by the server's clock. Null: never.
  final DateTime? nextChangeAt;
  final double? nextTotal;

  bool get isFree => ratePerHour <= 0 && totalSoFar <= 0;

  /// How long until the price changes, measured on the server's clock
  /// (`nextChangeAt - asOf`), so a phone whose clock is wrong still refetches
  /// at the right moment.
  Duration? get untilNextChange => nextChangeAt?.difference(asOf);

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  factory LiveFee.fromJson(Map<String, dynamic> json) => LiveFee(
    asOf: DateTime.parse(json['asOf'] as String),
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    ratePerHour: _num(json['ratePerHour']),
    minimumFee: _num(json['minimumFee']),
    totalSoFar: _num(json['totalSoFar']),
    // An older server does not send it; the total is the working then.
    meteredSoFar: json['meteredSoFar'] == null
        ? _num(json['totalSoFar'])
        : _num(json['meteredSoFar']),
    alreadyPaid: _num(json['alreadyPaid']),
    owedNow: _num(json['owedNow']),
    paymentProcessing: json['paymentProcessing'] as bool? ?? false,
    leaveBy: _date(json['leaveBy']),
    nextChangeAt: _date(json['nextChangeAt']),
    nextTotal: (json['nextTotal'] as num?)?.toDouble(),
  );
}
