import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';
import '../../theme/emotion/emotion.dart';
import 'availability_confidence.dart';

/// Brief §8, item 4 — one cell of a slot map: [AvailabilityConfidence]'s
/// three colours plus a fourth, independent `selected` state.
///
/// The two states are drawn as two separate layers on purpose. The inner
/// border is always [AvailabilityConfidence.colorOf] — a truthful status
/// signal that must never change just because the user tapped the cell.
/// Selection is a UI/interaction state, not a status, so per brief §3's hard
/// rule it gets [EmotionTokens.signal] instead: a blue outer ring laid
/// around the untouched status cell, never a recolour of it. A cell that
/// went blue-instead-of-red on selection would be lying about whether the
/// slot is actually available.
///
/// [label] plus [AvailabilityConfidence.label] together satisfy brief §9's
/// "pair every availability colour with a label" — the state name is always
/// on screen as text, never colour alone.
class SlotMapCell extends StatelessWidget {
  const SlotMapCell({
    super.key,
    required this.label,
    required this.confidence,
    this.selected = false,
    this.onTap,
    this.size = 84,
  });

  /// e.g. "B-14".
  final String label;

  final AvailabilityConfidence confidence;

  final bool selected;

  /// Left null for a read-only cell (e.g. a legend swatch).
  final VoidCallback? onTap;

  /// Comfortably above brief §9's 48dp tap-target floor by default — this
  /// cell carries two lines of text, not just an icon.
  final double size;

  @override
  Widget build(BuildContext context) {
    final e = context.emotion;
    final statusColor = confidence.colorOf(e);

    Widget cell = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: e.surface.raised,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: e.typography.slotId.copyWith(color: e.paint.white),
          ),
          const SizedBox(height: 2),
          Text(
            confidence.label,
            style: e.typography.caption.copyWith(color: e.paint.muted),
          ),
        ],
      ),
    );

    if (selected) {
      cell = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: e.signal.blue, width: 3),
        ),
        child: cell,
      );
    }

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '$label. ${confidence.label}${selected ? ', selected' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: ExcludeSemantics(child: cell),
        ),
      ),
    );
  }
}
