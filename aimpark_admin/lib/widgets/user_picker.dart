import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/admin_user.dart';
import '../core/utils/responsive.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// The result of picking a user — the id the API needs, plus the name to show
/// back to the operator so they can confirm they picked the right person.
class PickedUser {
  const PickedUser({required this.userId, required this.fullName, required this.email});

  final String userId;
  final String fullName;
  final String email;
}

/// Opens a searchable list of users and returns the chosen one, or null if
/// cancelled. Exists so admins never have to paste a raw user GUID.
Future<PickedUser?> showUserPicker(BuildContext context) {
  return showDialog<PickedUser>(
    context: context,
    builder: (_) => const _UserPickerDialog(),
  );
}

class _UserPickerDialog extends ConsumerStatefulWidget {
  const _UserPickerDialog();

  @override
  ConsumerState<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends ConsumerState<_UserPickerDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<AdminUser> _results = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String term) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(ApiEndpoints.users, queryParameters: {
        'page': 1,
        'pageSize': 25,
        // Only approved members can park, so only they can be given a parking
        // entry or a violation. Rejected/pending/suspended accounts and staff
        // (Admin/Security) are filtered out server-side so paging stays correct.
        'status': 'Active',
        'role': 'User',
        if (term.isNotEmpty) 'search': term,
      });
      final page = UserListPage.fromJson(response.data as Map<String, dynamic>);

      if (!mounted) return;
      setState(() {
        _results = page.users.where((u) => !u.isDeleted).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.data is Map
            ? (e.response!.data as Map)['message']?.toString() ?? 'Search failed.'
            : e.message ?? 'Search failed.';
        _isLoading = false;
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select User'),
      content: SizedBox(
        width: context.dialogWidth(420),
        height: context.dialogHeight(420),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search name, email, or plate number',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: TextStyle(color: context.tokens.status.danger.fg)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
          child: Text(
            'No matching members.\nOnly approved users appear here — '
            'pending, rejected, suspended, and staff accounts are excluded.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.tokens.text.secondary),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final user = _results[i];
        return ListTile(
          dense: true,
          title: Text(user.fullName),
          subtitle: Text(user.email),
          onTap: () => Navigator.pop(
            context,
            PickedUser(
              userId: user.userId,
              fullName: user.fullName,
              email: user.email,
            ),
          ),
        );
      },
    );
  }
}

/// A read-only field that shows the currently selected user and opens the
/// picker when tapped. Keeps the GUID out of sight while still surfacing
/// exactly who was chosen.
class UserPickerField extends StatelessWidget {
  const UserPickerField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.label = 'User',
    this.errorText,
    this.isRequired = false,
  });

  final PickedUser? selected;
  final ValueChanged<PickedUser> onChanged;
  final String label;
  final String? errorText;

  /// Marks the label with the asterisk the rest of the forms use.
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showUserPicker(context);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          label: AppFieldLabel(label, isRequired: isRequired),
          errorText: errorText,
          suffixIcon: const Icon(Icons.search),
        ),
        child: Text(
          selected == null ? 'Tap to select a user' : selected!.fullName,
          style: TextStyle(
            color: selected == null ? context.tokens.text.tertiary : null,
          ),
        ),
      ),
    );
  }
}
