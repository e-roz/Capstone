import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/step_progress_bar.dart';

class RegistrationStepScaffold extends StatelessWidget {
  const RegistrationStepScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    this.showBackButton = true,
  });

  final int step;
  final String title;
  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton,
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title, style: AppTextStyles.h3),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset('assets/images/owl_mascot.png', width: 64),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Step $step of 5',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.brandPressed),
              ),
              const SizedBox(height: AppSpacing.sm),
              StepProgressBar(currentStep: step, totalSteps: 5),
              const SizedBox(height: AppSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
