import 'package:flutter/material.dart';

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
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton,
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Step $step of 5',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: step / 5,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
