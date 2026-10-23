import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The one sentence a review opens with: where this stands and what to look
/// at, so the administrator does not have to read every section to find out.
///
/// Shared by the incident, violation and registration reviews so they say it
/// the same way. Colour carries the weight: red is a problem, amber needs a
/// look, blue is waiting on someone, green is fine, grey is closed.
class ReviewSummary extends StatelessWidget {
  const ReviewSummary({
    super.key,
    required this.intent,
    required this.icon,
    required this.headline,
    this.detail,
  });

  final StatusIntent intent;
  final IconData icon;
  final String headline;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.of(intent);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconMd, color: c.solid),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline,
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: c.fg)),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail!, style: text.bodySmall?.copyWith(color: c.fg)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
