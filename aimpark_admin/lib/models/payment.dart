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

class ParkingRate {
  final String rateId;
  final String? vehicleType;
  final double ratePerHour;
  final DateTime updatedAt;

  const ParkingRate({
    required this.rateId,
    required this.vehicleType,
    required this.ratePerHour,
    required this.updatedAt,
  });

  factory ParkingRate.fromJson(Map<String, dynamic> json) => ParkingRate(
        rateId: json['rateId']?.toString() ?? '',
        vehicleType: json['vehicleType']?.toString(),
        ratePerHour: (json['ratePerHour'] as num?)?.toDouble() ?? 0,
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
      );
}
