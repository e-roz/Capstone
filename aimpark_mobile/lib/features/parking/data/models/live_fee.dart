/// What a visit costs, from `GET /api/parking/sessions/{logId}/live-fee`.
///
/// Every amount is the server's. The app never works out a fee itself: the
/// server prices it the same way as pay-ahead and the exit gate, so the number
/// on the phone is the number at the barrier. The same reply describes a
/// finished visit (then [exitTime] is set and everything is priced at it).
///
/// The rule: the first hour costs one hour's rate, flat. After that every
/// started minute costs the rate ÷ 60. After each payment there is a 7-minute
/// grace period: leave inside it and nothing more is owed; stay past it and
/// it is charged too, from the end of what was paid.
class LiveFee {
  const LiveFee({
    required this.asOf,
    required this.durationMinutes,
    required this.ratePerHour,
    required this.totalSoFar,
    required this.alreadyPaid,
    required this.owedNow,
    required this.paymentProcessing,
    required this.firstHourEndsAt,
    this.leaveBy,
    this.nextChangeAt,
    this.nextTotal,
    this.exitTime,
    this.graceUntil,
    this.meterState = 'Running',
    this.segments = const [],
    this.payments = const [],
    this.breakdownMatchesBills = true,
    this.billedTotal,
  });

  /// The server's clock when this was priced.
  final DateTime asOf;
  final int durationMinutes;
  final double ratePerHour;

  /// What the whole stay costs if the driver left now.
  final double totalSoFar;

  /// Paid or waived already for this session.
  final double alreadyPaid;

  /// [totalSoFar] less [alreadyPaid].
  final double owedNow;

  /// A checkout is open and the provider has not answered yet.
  final bool paymentProcessing;

  /// Nothing owed: the barrier opens on a tap until this time.
  final DateTime? leaveBy;

  /// When [totalSoFar] next goes up, by the server's clock. Null: never.
  final DateTime? nextChangeAt;
  final double? nextTotal;

  /// Set once the visit is over.
  final DateTime? exitTime;

  /// Entry + one hour: the end of the flat first hour.
  final DateTime firstHourEndsAt;

  /// The end of the latest grace, if any payment was made.
  final DateTime? graceUntil;

  /// `Free`, `FirstHour`, `Running` or `Paused`.
  final String meterState;

  /// The visit in time order: first hour, per-minute runs, grace pauses.
  final List<FeeSegment> segments;

  /// Settled bills, oldest first.
  final List<FeePayment> payments;

  /// False for an old finished visit priced under the previous rules.
  final bool breakdownMatchesBills;

  /// What this visit's bills come to, paid or not. Null from an older server.
  final double? billedTotal;

  /// The visit's total as charged: the bills, for an old visit priced under
  /// the earlier rules; otherwise the server's total.
  double get chargedTotal =>
      breakdownMatchesBills ? totalSoFar : (billedTotal ?? totalSoFar);

  /// Still to pay, on the same basis as [chargedTotal].
  double get chargedOwed => breakdownMatchesBills
      ? owedNow
      : (chargedTotal - alreadyPaid).clamp(0, double.infinity).toDouble();

  DateTime get entryTime => firstHourEndsAt.subtract(const Duration(hours: 1));

  bool get isFree => meterState == 'Free';

  /// Paid up: nothing owed, and the barrier opens until [leaveBy].
  bool get isCovered => owedNow <= 0 && alreadyPaid > 0 && leaveBy != null;

  /// The payment that covered [s], if one did.
  FeePayment? paymentFor(FeeSegment s) {
    for (final p in payments) {
      final from = p.coversFrom, to = p.coversTo;
      if (from != null &&
          to != null &&
          !s.from.isBefore(from) &&
          !s.to.isAfter(to)) {
        return p;
      }
    }
    return null;
  }

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
    totalSoFar: _num(json['totalSoFar']),
    alreadyPaid: _num(json['alreadyPaid']),
    owedNow: _num(json['owedNow']),
    paymentProcessing: json['paymentProcessing'] as bool? ?? false,
    leaveBy: _date(json['leaveBy']),
    nextChangeAt: _date(json['nextChangeAt']),
    nextTotal: (json['nextTotal'] as num?)?.toDouble(),
    exitTime: _date(json['exitTime']),
    // An older server does not send it: an hour after entry is the rule anyway.
    firstHourEndsAt:
        _date(json['firstHourEndsAt']) ??
        DateTime.parse(json['entryTime'] as String).add(const Duration(hours: 1)),
    graceUntil: _date(json['graceUntil']),
    meterState: json['meterState'] as String? ?? 'Running',
    segments: [
      for (final s in (json['segments'] as List?) ?? const [])
        FeeSegment.fromJson(s as Map<String, dynamic>),
    ],
    payments: [
      for (final p in (json['payments'] as List?) ?? const [])
        FeePayment.fromJson(p as Map<String, dynamic>),
    ],
    breakdownMatchesBills: json['breakdownMatchesBills'] as bool? ?? true,
    billedTotal: (json['billedTotal'] as num?)?.toDouble(),
  );
}

/// One stretch of a visit: the flat first hour, a per-minute run, or a grace
/// period after a payment (the driver left inside it, or it is still running).
class FeeSegment {
  const FeeSegment({
    required this.kind,
    required this.from,
    required this.to,
    required this.minutes,
    required this.amount,
  });

  /// `FirstHour`, `PerMinute` or `Grace`.
  final String kind;
  final DateTime from;
  final DateTime to;
  final int minutes;
  final double amount;

  bool get isGrace => kind == 'Grace';
  bool get isFirstHour => kind == 'FirstHour';

  factory FeeSegment.fromJson(Map<String, dynamic> json) => FeeSegment(
    kind: json['kind'] as String,
    from: DateTime.parse(json['from'] as String),
    to: DateTime.parse(json['to'] as String),
    minutes: (json['minutes'] as num).toInt(),
    amount: (json['amount'] as num).toDouble(),
  );
}

/// A settled bill on this visit, and the stretch it paid for.
class FeePayment {
  const FeePayment({
    required this.paymentId,
    required this.amount,
    this.paidAt,
    this.method,
    this.coversFrom,
    this.coversTo,
  });

  final String paymentId;
  final double amount;
  final DateTime? paidAt;
  final String? method;
  final DateTime? coversFrom;
  final DateTime? coversTo;

  factory FeePayment.fromJson(Map<String, dynamic> json) => FeePayment(
    paymentId: json['paymentId'] as String,
    amount: (json['amount'] as num).toDouble(),
    paidAt: LiveFee._date(json['paidAt']),
    method: json['method'] as String?,
    coversFrom: LiveFee._date(json['coversFrom']),
    coversTo: LiveFee._date(json['coversTo']),
  );
}
