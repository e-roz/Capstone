class Payment {
  const Payment({
    required this.paymentId,
    required this.source,
    required this.durationMinutes,
    required this.ratePerHourApplied,
    required this.amountDue,
    required this.status,
    required this.createdAt,
    this.parkingLogId,
    this.violationId,
    this.slotCode,
    this.entryTime,
    this.exitTime,
    this.paidAt,
    this.dueAt,
    this.method,
    this.referenceNumber,
    this.provider,
  });

  final String paymentId;
  final String source;
  final String? parkingLogId;
  final String? violationId;
  final String? slotCode;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final int durationMinutes;
  final double ratePerHourApplied;
  final double amountDue;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;

  /// When settlement is expected. Null on older records created before due
  /// dates existed, so every read has to tolerate its absence.
  final DateTime? dueAt;

  /// Cash, GCash, Maya or Card. Null until the bill is settled.
  final String? method;

  /// What the payer can quote if a payment is ever disputed.
  final String? referenceNumber;

  /// Which provider handled it, or `Simulated`.
  final String? provider;

  bool get isPaid => paidAt != null;

  /// A checkout is open and nothing has come back from the provider yet.
  ///
  /// The gap between leaving for GCash and the money being confirmed is real,
  /// and short, and the screen has to say something honest during it. Not
  /// "paid" — nobody has told us that — and not "unpaid" either, or the
  /// payer pays a second time.
  bool get isProcessing => !isPaid && status.toLowerCase() == 'processing';

  bool get isOverdue =>
      !isPaid && dueAt != null && DateTime.now().isAfter(dueAt!);

  /// Whole days until the deadline. Negative once it has passed.
  int? get daysUntilDue {
    if (dueAt == null) return null;
    final due = DateTime(dueAt!.year, dueAt!.month, dueAt!.day);
    final now = DateTime.now();
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Short human phrasing for the deadline, or null when there is nothing to say.
  String? get dueLabel {
    if (isPaid || dueAt == null) return null;

    final days = daysUntilDue!;
    if (days < 0) return 'Overdue by ${-days} day(s)';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      paymentId: json['paymentId'] as String,
      source: json['source'] as String,
      parkingLogId: json['parkingLogId'] as String?,
      violationId: json['violationId'] as String?,
      slotCode: json['slotCode'] as String?,
      entryTime: json['entryTime'] == null ? null : DateTime.parse(json['entryTime'] as String),
      exitTime: json['exitTime'] == null ? null : DateTime.parse(json['exitTime'] as String),
      durationMinutes: json['durationMinutes'] as int,
      ratePerHourApplied: (json['ratePerHourApplied'] as num).toDouble(),
      amountDue: (json['amountDue'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      paidAt: json['paidAt'] == null ? null : DateTime.parse(json['paidAt'] as String),
      dueAt: json['dueAt'] == null ? null : DateTime.parse(json['dueAt'] as String),
      method: json['method'] as String?,
      referenceNumber: json['referenceNumber'] as String?,
      provider: json['provider'] as String?,
    );
  }
}

class PaymentListResult {
  const PaymentListResult({required this.payments, required this.totalCount});

  final List<Payment> payments;
  final int totalCount;

  factory PaymentListResult.fromJson(Map<String, dynamic> json) {
    return PaymentListResult(
      payments: (json['payments'] as List<dynamic>)
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int,
    );
  }
}

/// An open checkout: the page to send the payer to, and who is hosting it.
class Checkout {
  const Checkout({
    required this.paymentId,
    required this.checkoutUrl,
    required this.provider,
    required this.amountDue,
  });

  final String paymentId;
  final String checkoutUrl;

  /// `PayMongo`, or `Simulated` while the school has no merchant account.
  final String provider;

  final double amountDue;

  /// True while no real provider is connected.
  ///
  /// Worth saying on screen. A test payment that looks exactly like a real one
  /// is how somebody ends up believing a bill is settled when no money moved.
  bool get isSimulated => provider.toLowerCase() == 'simulated';

  factory Checkout.fromJson(Map<String, dynamic> json) {
    return Checkout(
      paymentId: json['paymentId'] as String,
      checkoutUrl: json['checkoutUrl'] as String,
      provider: json['provider'] as String? ?? '',
      amountDue: (json['amountDue'] as num?)?.toDouble() ?? 0,
    );
  }
}
