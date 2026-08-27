import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/jwt_utils.dart';
import '../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import '../theme/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.login, data: {
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
      });

      final data = res.data as Map<String, dynamic>;
      final token = data['token']?.toString();

      if (token == null || token.isEmpty) {
        setState(() => _error = data['message']?.toString() ?? 'Login failed.');
        return;
      }

      if (JwtUtils.staffRole(token) == null) {
        setState(() => _error =
            'Access denied. This panel is for staff accounts only.');
        return;
      }

      await ref.read(authNotifierProvider.notifier).saveToken(token);
      if (mounted) context.go('/dashboard');
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map ? data['message']?.toString() : null) ??
          'Login failed. Check your credentials.';
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var otpSent = false;
    var loading = false;
    String? error;
    String? info;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Reset Password'),
          content: SizedBox(
            width: ctx.dialogWidth(400),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) ...[
                    _DialogBanner(error!, intent: StatusIntent.danger),
                    const SizedBox(height: AppSpacing.x3),
                  ],
                  if (info != null) ...[
                    _DialogBanner(info!, intent: StatusIntent.success),
                    const SizedBox(height: AppSpacing.x3),
                  ],
                  TextFormField(
                    controller: emailCtrl,
                    enabled: !otpSent,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Email is required' : null,
                  ),
                  if (otpSent) ...[
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: otpCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reset code',
                        helperText: 'Check your email',
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Code is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    TextFormField(
                      controller: newPassCtrl,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'New password'),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'At least 6 characters'
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        final dio = ref.read(dioProvider);
                        if (!otpSent) {
                          final res = await dio.post(ApiEndpoints.forgotPassword,
                              data: {'email': emailCtrl.text.trim()});
                          setState(() {
                            otpSent = true;
                            info = (res.data as Map<String, dynamic>)['message']
                                ?.toString();
                          });
                        } else {
                          final res = await dio.post(ApiEndpoints.resetPassword, data: {
                            'email': emailCtrl.text.trim(),
                            'otp': otpCtrl.text.trim(),
                            'newPassword': newPassCtrl.text,
                          });
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text((res.data as Map<String, dynamic>)['message']
                                    ?.toString() ??
                                'Password reset successful.'),
                          ));
                        }
                      } on DioException catch (e) {
                        final data = e.response?.data;
                        setState(() => error = (data is Map
                                ? data['message']?.toString()
                                : null) ??
                            'Something went wrong.');
                      } finally {
                        setState(() => loading = false);
                      }
                    },
              child: Text(otpSent ? 'Reset Password' : 'Send Code'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.surface.canvas,
      // Two panels on a monitor, form only on a laptop or phone. The brand
      // panel is the first thing anyone sees of this product, so it gets the
      // larger half of the screen rather than a logo above a form.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final form = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.x8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _LoginForm(
                  formKey: _formKey,
                  emailCtrl: _emailCtrl,
                  passCtrl: _passCtrl,
                  obscure: _obscure,
                  loading: _loading,
                  error: _error,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  onSubmit: _submit,
                  onForgot: () => _showForgotPasswordDialog(context),
                ),
              ),
            ),
          );

          if (constraints.maxWidth < 940) return form;

          // Equal halves. The brand panel used to take the larger share, which
          // read as lopsided rather than as emphasis — the gradient already
          // carries the weight without needing extra width.
          return Row(
            children: [
              const Expanded(child: _BrandPanel()),
              Expanded(child: form),
            ],
          );
        },
      ),
    );
  }
}

/// The left half of the sign-in screen.
///
/// Deliberately the only place in the panel with a gradient: a marketing
/// flourish on a data screen is noise, but on the one screen that has no data
/// it is the difference between a product and a form.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.brand.pressed, t.brand.primary],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        // The block is centred in the panel and capped at a readable width.
        // Left-aligned against a 48px edge it hugged one side and left a wide
        // empty gutter on the other, which is what made the split look uneven
        // even before the flex was corrected.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
            Row(
              children: [
                // Solid white plate rather than the 14%-white wash it had:
                // against a blue gradient that tint was almost invisible, so
                // the mark read as a smudge instead of a logo.
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: t.text.onDark,
                    borderRadius: AppRadii.lgAll,
                  ),
                  child: Icon(Icons.local_parking,
                      size: 36, color: t.brand.primary),
                ),
                const SizedBox(width: AppSpacing.x4),
                // The product name is the largest thing on the page. It used to
                // sit at headlineSmall under a displaySmall tagline, so the
                // strapline outshouted the name of the system.
                Expanded(
                  child: Text(
                    'AimPark',
                    style: text.displaySmall?.copyWith(
                      color: t.text.onDark,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              'STI College Baliuag',
              style: text.titleMedium?.copyWith(color: t.text.onDarkMuted),
            ),
            const SizedBox(height: AppSpacing.x10),
            Text(
              'RFID parking, run from one screen.',
              style: text.headlineSmall?.copyWith(
                color: t.text.onDark,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              'Registrations, bay occupancy, payments and enforcement for '
              'STI Baliuag — live, in one place.',
              style: text.bodyLarge?.copyWith(color: t.text.onDarkMuted),
            ),
            const SizedBox(height: AppSpacing.x12),
            const _BrandPoint(
                icon: Icons.sensors, label: 'Gate readers report in real time'),
            const SizedBox(height: AppSpacing.x4),
            const _BrandPoint(
                icon: Icons.fact_check_outlined,
                label: 'Documents verified before a card is issued'),
            const SizedBox(height: AppSpacing.x4),
            const _BrandPoint(
                icon: Icons.receipt_long_outlined,
                label: 'Every charge traced to a session'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tinted message block inside a dialog, replacing the bare red and green
/// `Text` the reset flow used — which on a dark theme was unreadable.
class _DialogBanner extends StatelessWidget {
  const _DialogBanner(this.message, {required this.intent});

  final String message;
  final StatusIntent intent;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.of(intent);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: c.border),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.fg),
      ),
    );
  }
}

class _BrandPoint extends StatelessWidget {
  const _BrandPoint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      children: [
        Icon(icon, size: AppSizes.iconMd, color: t.text.onDarkMuted),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: t.text.onDarkMuted),
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onForgot,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign in', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Administrator and security access to the AimPark panel.',
            style: text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          const SizedBox(height: AppSpacing.x8),
          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.x3),
              decoration: BoxDecoration(
                color: t.status.danger.bg,
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: t.status.danger.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline,
                      size: AppSizes.iconSm, color: t.status.danger.fg),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      error!,
                      style: text.bodySmall?.copyWith(color: t.status.danger.fg),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
          ],
          TextFormField(
            controller: emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline, size: AppSizes.iconMd),
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Email is required' : null,
          ),
          const SizedBox(height: AppSpacing.x4),
          TextFormField(
            controller: passCtrl,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: AppSizes.iconMd),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  size: AppSizes.iconMd,
                ),
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: onToggleObscure,
              ),
            ),
            obscureText: obscure,
            autofillHints: const [AutofillHints.password],
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: AppSpacing.x2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgot,
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: loading ? null : onSubmit,
              child: loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.text.onBrand,
                      ),
                    )
                  : const Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }
}
