import '../data/models/parking_slot.dart';

/// Where each bay goes in the drawing of the lot.
///
/// The lot is built as two columns of nine bays facing each other across a drive
/// lane, with Gate 1's barrier at the top and Gate 2's at the bottom. Gate 1's
/// bays fill the left column and Gate 2's the right; the four-wheel bays sit at
/// the top of the left column and, mirrored, at the bottom of the right one — as
/// they are painted on the ground.
///
/// This is the same placement the admin and guard-post map uses, ported rather
/// than imported: the two apps do not share code, and the rule is small. If the
/// lot is ever rebuilt, both have to change together.
///
/// A gate with more than [rows] bays does not lose the extras. The overflow comes
/// from the non-car bays — so the four-wheel bays always keep their painted
/// spots — and anything that does not fit the drawing at all, a third gate or a
/// tenth bay, is returned in [unplaced] to be listed beneath it.
class LotLayout {
  const LotLayout({
    required this.left,
    required this.right,
    required this.unplaced,
  });

  /// Bays per column on the model.
  static const int rows = 9;

  /// Gate 1's bays, top to bottom.
  final List<ParkingSlot> left;

  /// Gate 2's bays, top to bottom — the mirror of Gate 1's.
  final List<ParkingSlot> right;

  /// Bays the drawing has no room for.
  final List<ParkingSlot> unplaced;

  factory LotLayout.of(List<ParkingSlot> slots) {
    final left = _column(slots, gate: 1, mirrored: false);
    final right = _column(slots, gate: 2, mirrored: true);

    final placed = {...left, ...right}.map((s) => s.slotId).toSet();
    final unplaced = slots.where((s) => !placed.contains(s.slotId)).toList()
      ..sort((a, b) => naturalCompare(a.slotCode, b.slotCode));

    return LotLayout(left: left, right: right, unplaced: unplaced);
  }

  static bool isCar(ParkingSlot s) =>
      (s.vehicleType ?? '').toLowerCase() == 'car';

  static List<ParkingSlot> _column(
    List<ParkingSlot> slots, {
    required int gate,
    required bool mirrored,
  }) {
    int byCode(ParkingSlot a, ParkingSlot b) =>
        naturalCompare(a.slotCode, b.slotCode);

    final atGate = slots.where((s) => s.gate == gate).toList();
    final cars = (atGate.where(isCar).toList()..sort(byCode)).take(rows).toList();
    final others = (atGate.where((s) => !isCar(s)).toList()..sort(byCode))
        .take(rows - cars.length)
        .toList();

    final column = [...cars, ...others];
    return mirrored ? column.reversed.toList() : column;
  }

  /// Sorts "M10" after "M9", not after "M1".
  static int naturalCompare(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final pa = re.allMatches(a).map((m) => m.group(0)!).toList();
    final pb = re.allMatches(b).map((m) => m.group(0)!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]);
      final nb = int.tryParse(pb[i]);
      final c = (na != null && nb != null)
          ? na.compareTo(nb)
          : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }
}
