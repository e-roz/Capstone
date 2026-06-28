import 'package:flutter/material.dart';

import '../widgets/role_dashboard_scaffold.dart';

class UserPlaceholderScreen extends StatelessWidget {
  const UserPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardScaffold(
      dashboardTitle: 'USER DASHBOARD',
    );
  }
}
