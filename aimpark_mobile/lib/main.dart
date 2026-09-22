import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/push_service.dart';
import 'core/theme/theme.dart';
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
      // The app is light-only by product decision. Both slots get the light
      // theme and [themeMode] is pinned, so a phone set to dark still renders
      // light rather than falling through to a half-built dark theme.
      //
      // The dark token bundles in app_tokens.dart and AppTheme.dark() are left
      // intact on purpose — restoring dark mode later is a matter of pointing
      // these three lines back at appThemeModeProvider, not rebuilding tokens.
      theme: AppTheme.light(),
      darkTheme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
