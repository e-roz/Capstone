import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../account/presentation/providers/account_provider.dart';
import '../../../vehicles/presentation/providers/vehicles_provider.dart';
import '../providers/renewals_provider.dart';
import '../widgets/document_expiry_rows.dart';
import '../widgets/expiry_banner.dart';

/// Every document with an expiry, and where to renew it.
///
/// Also where the "expires in 30 days" push lands.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(myVehiclesProvider);
    ref.invalidate(myRenewalsProvider);
    await ref.read(profileNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen(
      title: 'Documents',
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: kScreenListPadding,
          children: [
            const ExpiryBanner(),
            const AppSectionHeader(
              title: 'Expiry dates',
              subtitle:
                  'Tap a document to upload its renewal. An admin reviews it '
                  'before the new date counts.',
            ),
            const DocumentExpiryRows(),
          ],
        ),
      ),
    );
  }
}
