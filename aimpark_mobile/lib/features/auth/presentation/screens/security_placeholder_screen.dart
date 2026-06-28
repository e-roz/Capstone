import 'package:flutter/material.dart';

import '../widgets/role_dashboard_scaffold.dart';

class SecurityPlaceholderScreen extends StatelessWidget {
  const SecurityPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardScaffold(
      dashboardTitle: 'SECURITY DASHBOARD',
    );
  }
}
