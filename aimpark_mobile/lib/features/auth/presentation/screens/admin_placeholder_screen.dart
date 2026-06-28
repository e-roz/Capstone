import 'package:flutter/material.dart';

import '../widgets/role_dashboard_scaffold.dart';

class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardScaffold(
      dashboardTitle: 'ADMIN DASHBOARD',
    );
  }
}
