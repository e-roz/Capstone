import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up Firebase and the notification channel up front so a push tapped from
  // a cold start is handled correctly. Failures are swallowed inside init().
  await PushService.instance.init();

  runApp(const ProviderScope(child: AimParkApp()));
}

class AimParkApp extends ConsumerWidget {
  const AimParkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'AimPark',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
