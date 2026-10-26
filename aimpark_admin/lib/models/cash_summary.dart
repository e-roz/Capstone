/// Cash taken today, for counting the drawer at the end of a shift.
class CashSummary {
  final double total;
  final int count;

  /// What the signed-in person took themselves.
  final double mineTotal;
  final int mineCount;

  const CashSummary({
    required this.total,
    required this.count,
    required this.mineTotal,
    required this.mineCount,
  });

  factory CashSummary.fromJson(Map<String, dynamic> json) {
    final mine = (json['mine'] as Map<String, dynamic>?) ?? const {};
    return CashSummary(
      total: (json['total'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      mineTotal: (mine['total'] as num?)?.toDouble() ?? 0,
      mineCount: (mine['count'] as num?)?.toInt() ?? 0,
    );
  }
}
