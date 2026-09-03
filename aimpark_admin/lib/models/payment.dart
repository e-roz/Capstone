class PaymentTransaction {
  final String paymentId;
  final String source;
  final String? slotCode;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final int durationMinutes;
  final double ratePerHourApplied;
  final double amountDue;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;

  /// When the payer was sent to the provider. Null unless the bill is, or once
  /// was, Processing — this is how long a checkout has been sitting there.
  final DateTime? checkoutStartedAt;

  /// Cash, GCash, Maya or Card. Null while the bill is unsettled.
  final String? method;

  /// The number the payer can quote: a provider's payment id, or an OR number
  /// typed in by whoever took the cash.
  final String? referenceNumber;

  /// Which provider handled it, or `Simulated`. Null for cash, which no
  /// provider ever sees.
  final String? provider;

  /// The admin who took the money, on payments settled in person.
  final String? confirmedBy;

  const PaymentTransaction({
    required this.paymentId,
    required this.source,
    required this.slotCode,
    required this.entryTime,
    required this.exitTime,
    required this.durationMinutes,
    required this.ratePerHourApplied,
    required this.amountDue,
    required this.status,
    required this.createdAt,
    required this.paidAt,
    this.checkoutStartedAt,
    this.method,
    this.referenceNumber,
    this.provider,
    this.confirmedBy,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) =>
      PaymentTransaction(
        paymentId: json['paymentId']?.toString() ?? '',
        source: json['source']?.toString() ?? '',
        slotCode: json['slotCode']?.toString(),
        entryTime: json['entryTime'] == null
            ? null
            : DateTime.parse(json['entryTime'].toString()),
        exitTime: json['exitTime'] == null
            ? null
            : DateTime.parse(json['exitTime'].toString()),
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        ratePerHourApplied:
            (json['ratePerHourApplied'] as num?)?.toDouble() ?? 0,
        amountDue: (json['amountDue'] as num?)?.toDouble() ?? 0,
        status: json['status']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'].toString()),
        paidAt: json['paidAt'] == null
            ? null
            : DateTime.parse(json['paidAt'].toString()),
        checkoutStartedAt: json['checkoutStartedAt'] == null
            ? null
            : DateTime.parse(json['checkoutStartedAt'].toString()),
        method: json['method']?.toString(),
        referenceNumber: json['referenceNumber']?.toString(),
        provider: json['provider']?.toString(),
        confirmedBy: json['confirmedBy']?.toString(),
      );
}

class PaymentListPage {
  final List<PaymentTransaction> payments;
  final int totalCount;
  final int page;
  final int pageSize;

  const PaymentListPage({
    required this.payments,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory PaymentListPage.fromJson(Map<String, dynamic> json) =>
      PaymentListPage(
        payments: (json['payments'] as List<dynamic>? ?? [])
            .map((p) => PaymentTransaction.fromJson(p as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}

/// An unpaged pull of every transaction matching a filter, for download.
class PaymentExportResult {
  final List<PaymentTransaction> payments;

  /// How many rows matched the filter, before the export cap was applied.
  final int matchingCount;

  /// True when [matchingCount] exceeds how many rows actually came back.
  final bool truncated;

  const PaymentExportResult({
    required this.payments,
    required this.matchingCount,
    required this.truncated,
  });

  factory PaymentExportResult.fromJson(Map<String, dynamic> json) =>
      PaymentExportResult(
        payments: (json['payments'] as List<dynamic>? ?? [])
            .map((p) => PaymentTransaction.fromJson(p as Map<String, dynamic>))
            .toList(),
        matchingCount: (json['matchingCount'] as num?)?.toInt() ?? 0,
        truncated: json['truncated'] as bool? ?? false,
      );
}

class ParkingRate {
  final String rateId;
  final String? vehicleType;
  final double ratePerHour;

  /// The least a finished session can cost.
  ///
  /// A flat first block, the way parking is priced everywhere — and the
  /// reason online payment works at all, since no gateway accepts a charge
  /// under twenty pesos.
  final double minimumFee;

  final DateTime updatedAt;

  const ParkingRate({
    required this.rateId,
    required this.vehicleType,
    required this.ratePerHour,
    required this.minimumFee,
    required this.updatedAt,
  });

  factory ParkingRate.fromJson(Map<String, dynamic> json) => ParkingRate(
        rateId: json['rateId']?.toString() ?? '',
        vehicleType: json['vehicleType']?.toString(),
        ratePerHour: (json['ratePerHour'] as num?)?.toDouble() ?? 0,
        minimumFee: (json['minimumFee'] as num?)?.toDouble() ?? 0,
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
      );
}
