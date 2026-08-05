import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The terms a user agrees to at registration.
///
/// Held as content in the app rather than a remote link so it is readable
/// offline and cannot silently change after someone has agreed to it. Acceptance
/// is recorded server-side on the user as `TermsAcceptedAt`.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const _sections = <(String, String)>[
    (
      '1. Eligibility',
      'The AimPark parking facility is available to enrolled students, faculty '
          'and staff whose registration has been reviewed and approved by an '
          'administrator. You must register a vehicle you are authorised to use.',
    ),
    (
      '2. Accurate information',
      'You agree that the details you submit — your name, contact number, plate '
          'number, vehicle details and supporting documents — are accurate and '
          'belong to you. Submitting false or another person\'s information may '
          'result in your access being suspended.',
    ),
    (
      '3. RFID access',
      'Your RFID tag is issued to you personally and must not be lent, copied or '
          'transferred. Entry and exit are logged against the account the tag '
          'belongs to, so anything done with your tag is recorded as yours.',
    ),
    (
      '4. Slot assignment',
      'The system assigns a parking bay appropriate to your registered vehicle '
          'type. Assignment depends on availability and is not guaranteed. Bays '
          'are not reserved in advance — an assignment given in the app may be '
          'taken before you arrive.',
    ),
    (
      '5. Fees',
      'Parking is charged by time at the posted hourly rate, calculated when you '
          'exit. Fees are payable by the due date shown with each charge. '
          'Outstanding balances may affect your access.',
    ),
    (
      '6. Violations and appeals',
      'Breaches of the posted parking rules may result in a penalty and, in some '
          'cases, temporary or permanent suspension of RFID access. You will be '
          'notified of any violation issued against you and may submit one appeal '
          'per violation, with supporting evidence, for administrator review.',
    ),
    (
      '7. Incident reporting',
      'You may report incidents observed in the facility. Reports are reviewed by '
          'administrators. Knowingly filing false reports may itself be treated as '
          'a violation.',
    ),
    (
      '8. Data and privacy',
      'We collect and store the registration details, documents, vehicle '
          'information, entry and exit logs, payment records and incident reports '
          'described above, for the purpose of operating and securing the parking '
          'facility. Your documents are visible only to administrators reviewing '
          'your registration.',
    ),
    (
      '9. Liability',
      'Parking is at your own risk. The facility operator is not responsible for '
          'loss of or damage to vehicles or their contents, except where required '
          'by law.',
    ),
    (
      '10. Changes',
      'These terms and the posted parking rules and rates may be updated. '
          'Material changes will be announced through the app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        title: Text('Terms & Conditions', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('AimPark Parking Terms', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Please read these before completing your registration.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final (heading, body) in _sections) ...[
              Text(
                heading,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(body, style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
