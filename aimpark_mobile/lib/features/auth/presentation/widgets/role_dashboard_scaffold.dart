import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class RoleDashboardScaffold extends ConsumerWidget {
  const RoleDashboardScaffold({
    super.key,
    required this.dashboardTitle,
  });

  final String dashboardTitle;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(authRepositoryProvider);

    try {
      await repo.logout();
    } catch (_) {
      // Clear local session even if the server call fails.
    }

    await repo.clearToken();
    await repo.clearSessionToken();

    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AimPark'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dashboardTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _logout(context, ref),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
