import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../theme/theme.dart';

/// Tells the guard about the guard PC updating itself, on every screen.
///
/// The site server downloads a new version by itself and installs it when the
/// gates are quiet (SiteUpdater.cs). Until then this shows "Update ready"
/// with an Update now button; while it installs, that the gates are paused
/// for about a minute. When the server comes back on a new version, the page
/// reloads itself so the guard is on the new panel without pressing Ctrl+F5.
///
/// Only the guard post's server reports updates. Opened from the cloud, the
/// first answer says so and this checks back rarely and draws nothing.
class SiteUpdateBanner extends ConsumerStatefulWidget {
  const SiteUpdateBanner({super.key});

  @override
  ConsumerState<SiteUpdateBanner> createState() => _SiteUpdateBannerState();
}

class _SiteUpdateBannerState extends ConsumerState<SiteUpdateBanner> {
  static const _atGuardPost = Duration(seconds: 15);
  static const _installing = Duration(seconds: 5);
  static const _elsewhere = Duration(minutes: 5);

  Timer? _timer;
  Duration? _every;

  /// The server version this page was loaded against.
  String? _loadedVersion;

  String _state = 'UpToDate';
  String? _available;
  String? _error;
  bool _updateNowRequested = false;
  bool _canInstall = false;
  bool _unreachable = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _schedule(_atGuardPost);
    _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule(Duration every) {
    if (_every == every) return;
    _every = every;
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => _check());
  }

  Future<void> _check() async {
    try {
      final d = (await ref.read(dioProvider).get(ApiEndpoints.siteStatus)).data as Map;
      if (d['mode'] != 'Site') {
        _schedule(_elsewhere);
        return;
      }

      final version = d['version'] as String?;
      _loadedVersion ??= version;
      if (version != null && version != _loadedVersion) {
        // Back on a new version: load the panel that came with it.
        web.window.location.reload();
        return;
      }

      final u = (d['update'] as Map?) ?? const {};
      if (!mounted) return;
      setState(() {
        _unreachable = false;
        _state = u['state'] as String? ?? 'UpToDate';
        _available = u['availableVersion'] as String?;
        _error = u['lastError'] as String?;
        _updateNowRequested = u['updateNowRequested'] == true;
        _canInstall = u['canInstall'] == true;
      });
      _schedule(_state == 'Installing' ? _installing : _atGuardPost);
    } on DioException catch (e) {
      if (e.response != null) {
        // The cloud panel: not the guard post.
        _schedule(_elsewhere);
      } else if (_state == 'Installing' && mounted) {
        // The server is down for the update; keep watching for it.
        setState(() => _unreachable = true);
        _schedule(_installing);
      }
    }
  }

  Future<void> _updateNow() async {
    setState(() => _busy = true);
    String? message;
    try {
      await ref.read(dioProvider).post(ApiEndpoints.siteUpdateInstall);
    } on DioException catch (e) {
      final data = e.response?.data;
      message = data is Map ? data['message'] as String? : null;
      message ??= 'Couldn\'t start the update. Try again.';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (StatusColors? intent, IconData icon, String text, bool showButton) =
        switch (_state) {
      'Ready' when _updateNowRequested => (
          t.status.info,
          Icons.system_update_alt,
          'Update $_available starts as soon as no car has tapped for a minute. '
              'The gates pause for about a minute while it installs.',
          false,
        ),
      'Ready' => (
          t.status.info,
          Icons.system_update_alt,
          _canInstall
              ? 'Update $_available is ready. It installs by itself tonight, or '
                  'when the gates are quiet.'
              : 'Update $_available is downloaded. Only the installed guard PC '
                  'server installs updates.',
          _canInstall,
        ),
      'Installing' => (
          t.status.warning,
          Icons.hourglass_top,
          _unreachable
              ? 'Updating to $_available… The gates are paused. This page '
                  'reloads by itself when it is done.'
              : 'Updating to $_available… The gates pause for about a minute.',
          false,
        ),
      'Failed' => (
          t.status.danger,
          Icons.error_outline,
          _error ?? 'The last update didn\'t install.',
          false,
        ),
      _ => (null, Icons.check, '', false),
    };

    if (intent == null) return const SizedBox.shrink();

    return Material(
      color: intent.bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: intent.fg),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: intent.fg),
              ),
            ),
            if (showButton) ...[
              const SizedBox(width: AppSpacing.x2),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: intent.fg),
                onPressed: _busy ? null : _updateNow,
                child: const Text('Update now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
