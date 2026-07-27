import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/registrations_provider.dart';
import '../widgets/page_header.dart';

class PendingRegistrationsScreen extends ConsumerWidget {
  const PendingRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingRegistrationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Pending Registrations',
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.invalidate(pendingRegistrationsProvider),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Failed to load: $e'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(pendingRegistrationsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (registrations) {
                  if (registrations.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 48, color: Colors.green),
                          SizedBox(height: 8),
                          Text('No pending registrations.',
                              style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.hardEdge,
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            Colors.grey.shade100),
                        columns: const [
                          DataColumn(label: Text('Full Name')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Submitted')),
                          DataColumn(label: Text('Last Updated')),
                        ],
                        rows: registrations.map((reg) {
                          return DataRow(
                            cells: [
                              DataCell(Text(reg.fullName)),
                              DataCell(Text(reg.email)),
                              DataCell(Text(_fmt(reg.createdAt))),
                              DataCell(Text(_fmt(reg.updatedAt))),
                            ],
                            onSelectChanged: (_) =>
                                context.go('/pending/${reg.userId}'),
                          );
                        }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      DateFormat('MMM d, yyyy HH:mm').format(dt.toLocal());
}
