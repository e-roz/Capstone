import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'field_requirement.dart';

/// The heading of one step of a form: a numbered disc, a bold title, and — on
/// the right — whether the step has to be completed.
///
/// A long form read as one strip of equally weighted fields. Numbering the steps
/// gives it a shape the eye can follow, and the disc is the one touch of brand
/// colour that says "this is where you are".
class AppFormSectionHeader extends StatelessWidget {
  const AppFormSectionHeader({
    super.key,
    required this.number,
    required this.title,
    this.requirement = FieldRequirement.none,
  });

  final int number;
  final String title;

  /// Shows a "Required" or "Optional" marker at the trailing end. [none] shows
  /// nothing — for a step whose fields each carry their own marker.
  final FieldRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.brand.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppTypography.tabular(
                context.text.labelLarge!.copyWith(
                  color: t.brand.onSolid,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              title,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (requirement != FieldRequirement.none) ...[
            const SizedBox(width: AppSpacing.sm),
            RequirementTag(requirement: requirement),
          ],
        ],
      ),
    );
  }
}
