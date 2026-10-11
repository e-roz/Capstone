import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../incident_categories.dart';

/// A report's category as a round icon in its own colour — the same icon and hue
/// the report form's tiles use, so a report is recognisable here by sight as well
/// as by its name.
class IncidentCategoryDisc extends StatelessWidget {
  const IncidentCategoryDisc({
    super.key,
    required this.category,
    this.size = AppSizes.rowIcon,
  });

  /// The API's category name, e.g. `BlockedSlot`.
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.of(incidentCategoryIntent(category));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
      child: Icon(
        incidentCategoryIcon(category),
        size: size * 0.5,
        color: c.fg,
      ),
    );
  }
}
