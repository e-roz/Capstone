import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/utils/jwt_utils.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../notifications/presentation/providers/push_registration_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../screens/account_status_screen.dart';

/// One Google client for the whole app.
///
/// Top-level rather than per-screen: two screens now offer Google, and a second
/// instance would mean a second native client with its own idea of who is
/// signed in.
final _googleSignIn = GoogleSignIn(
  serverClientId:
      '396722417831-3ldllppvag9pccpk9vupf20829f6be4h.apps.googleusercontent.com',
  scopes: ['email', 'profile'],
);

/// Which of the two buttons this is.
///
/// The app had one Google button, on the sign-in screen, running the sign-up
/// path. Pressing it with an unknown address quietly created an account;
/// pressing it with a known one produced a message about the account already
/// existing. It could create an account but never open one, and the label said
/// the opposite of what it did.
enum GoogleAuthIntent {
  /// On the sign-in screen. Never creates an account.
  login('login', 'Log in with Google'),

  /// On the first registration step, beside the email field.
  signup('signup', 'Sign up with Google');

  const GoogleAuthIntent(this.wireName, this.label);

  /// Sent to the server, which uses it for exactly one decision: whether an
  /// address with no account gets one created for it.
  final String wireName;

  final String label;
}

/// The Google button, and the whole exchange behind it.
///
/// Lives here rather than on a screen because both screens run the identical
/// flow — native sheet, ID token, server exchange, routing — and differ only in
/// the [intent] they send and what they offer when it does not work out.
class GoogleAuthButton extends ConsumerStatefulWidget {
  const GoogleAuthButton({
    super.key,
    required this.intent,
    this.enabled = true,
    this.onBusyChanged,
  });

  final GoogleAuthIntent intent;

  /// False while the host screen is busy with something of its own.
  final bool enabled;

  /// Lets the host screen disable its own controls for the duration.
  final ValueChanged<bool>? onBusyChanged;

  @override
  ConsumerState<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends ConsumerState<GoogleAuthButton> {
  bool _isLoading = false;

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() => _isLoading = value);
    widget.onBusyChanged?.call(value);
  }

  Future<void> _run() async {
    _setLoading(true);

    try {
      final googleUser = await _googleSignIn.signIn();
      // The user dismissed the account sheet. Not an error, and nothing to say
      // about it.
      if (googleUser == null) return;

      final idToken = (await googleUser.authentication).idToken;
      if (idToken == null) {
        if (mounted) {
          showAppMessage(
            context,
            'Could not obtain Google token. Please try again.',
            isError: true,
          );
        }
        return;
      }

      final repo = ref.read(authRepositoryProvider);
      final response = await repo.googleSignIn(
        idToken,
        intent: widget.intent.wireName,
      );
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String?;

      if (token == null || token.isEmpty) {
        throw Exception(data['message']?.toString() ?? 'Google sign-in failed.');
      }

      await repo.saveToken(token);

      // A brand-new Google account enters at the profile step with no password
      // to set — the flag is what tells that screen to hide the password fields
      // and pre-fill the name Google gave us.
      if (JwtUtils.isRegistrationOnly(token) &&
          JwtUtils.getRegistrationStep(token) == 'ProfileSetup') {
        final fullName =
            data['fullName'] as String? ?? googleUser.displayName ?? '';
        final registration = ref.read(registrationNotifierProvider.notifier);
        // This route into registration skips the email step, and with it the
        // point that normally drops an abandoned draft. Safe unconditionally
        // here: nothing reaches the profile step with documents already taken,
        // so there is never a draft at this point worth keeping.
        registration.startFresh();
        registration.setOAuthFlow(displayName: fullName);
      } else {
        // Only a full auth token can call the authenticated register endpoint —
        // users still mid-registration get registered once they finish and log
        // in.
        await ref.read(pushRegistrationProvider.notifier).registerAfterLogin();
      }

      if (mounted) context.go(JwtUtils.routeAfterLogin(token));
    } catch (e) {
      if (mounted) await _explain(e);
    } finally {
      // Always sign out of the Google SDK so the picker shows next time.
      await _googleSignIn.signOut();
      _setLoading(false);
    }
  }

  /// Turns a refusal into something with a way forward.
  ///
  /// Every one of these used to be a bar that named a problem and offered
  /// nothing — which is how "this account already exists" ended up being the
  /// response to someone trying to sign in to the account that exists.
  Future<void> _explain(Object error) async {
    final status = error is DioException ? error.response?.statusCode : null;

    // Pending, rejected or suspended: the status screen says which, and when
    // they may re-apply.
    if (status == 403 && _showAccountStatus(error)) return;

    final message = apiErrorMessage(error);

    // Nothing to log in to. Only reachable from the login button — the sign-up
    // intent creates the account instead of refusing.
    if (status == 404) {
      await _offer(
        title: 'No account yet',
        body: message,
        actionLabel: 'Sign up',
        onAction: () => context.go('/register/email'),
      );
      return;
    }

    // A different Google account is already attached to this address. Since an
    // account created with a password now links on first Google sign-in, this
    // no longer means "your email is taken" — it means this particular Google
    // account is not the one connected, and the password is the way in.
    if (status == 409) {
      await _offer(
        title: "Can't use this Google account",
        body: message,
        actionLabel:
            widget.intent == GoogleAuthIntent.login ? 'OK' : 'Go to log in',
        onAction: widget.intent == GoogleAuthIntent.login
            ? null
            : () => context.go('/login/sign-in'),
      );
      return;
    }

    if (mounted) showApiError(context, error);
  }

  bool _showAccountStatus(Object error) {
    if (error is! DioException) return false;

    final data = error.response?.data;
    if (data is! Map) return false;

    final status = data['registrationStatus'];
    final accountStatus =
        status is Map ? status['accountStatus']?.toString() : null;
    if (accountStatus == null) return false;

    final canReapplyRaw = status is Map ? status['canReapplyAt'] : null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountStatusScreen(
          accountStatus: accountStatus,
          message: data['message']?.toString(),
          rejectionReason: data['rejectionReason']?.toString() ??
              (status is Map ? status['rejectionReason']?.toString() : null),
          canReapplyAt: canReapplyRaw == null
              ? null
              : DateTime.tryParse(canReapplyRaw.toString()),
        ),
      ),
    );

    return true;
  }

  /// A dialog that states the problem and offers the one thing that fixes it.
  Future<void> _offer({
    required String title,
    required String body,
    required String actionLabel,
    VoidCallback? onAction,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        // The server's own wording. It knows which of several refusals this is,
        // and a sentence written here would have to guess.
        content: Text(body),
        actions: [
          if (onAction != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onAction?.call();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: widget.intent.label,
      style: AppButtonStyle.ghost,
      isLoading: _isLoading,
      icon: const Icon(Icons.g_mobiledata_rounded),
      onPressed: widget.enabled && !_isLoading ? _run : null,
    );
  }
}
