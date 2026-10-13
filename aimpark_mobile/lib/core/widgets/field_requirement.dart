import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Whether a field has to be filled in.
///
/// Said on the field itself rather than in a paragraph above the form. A
/// sentence that explains what is required is read once, if at all; a tag beside
/// the label is read every time the label is.
///
/// [none] is the default and changes nothing — the many existing forms keep
/// their plain small label until someone opts them in.
enum FieldRequirement { none, required, optional }

/// The small marker that goes beside a label: a brand-coloured "Required" pill,
/// or a quiet "Optional".
///
/// Required is the louder of the two on purpose. On a form where most things can
/// be skipped, it is the required ones that need finding.
class RequirementTag extends StatelessWidget {
  const RequirementTag({super.key, required this.requirement})
      : assert(requirement != FieldRequirement.none);

  final FieldRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (requirement == FieldRequirement.optional) {
      return Text('Optional', style: context.text.bodySmall);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.brand.subtle,
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        'Required',
        style: context.text.labelMedium?.copyWith(color: t.brand.subtleText),
      ),
    );
  }
}
