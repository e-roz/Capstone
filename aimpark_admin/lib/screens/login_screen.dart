import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/jwt_utils.dart';
import '../providers/auth_provider.dart';
import '../core/network/dio_client.dart';
import '../core/constants/api_endpoints.dart';
import 'package:dio/dio.dart';

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

      if (!JwtUtils.isAdmin(token)) {
        setState(() =>
            _error = 'Access denied. This panel is for Admins only.');
        return;
      }

      await ref.read(authNotifierProvider.notifier).saveToken(token);
      if (mounted) context.go('/pending');
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
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null) ...[
                  Text(error!, style: TextStyle(color: Colors.red.shade700)),
                  const SizedBox(height: 12),
                ],
                if (info != null) ...[
                  Text(info!, style: TextStyle(color: Colors.green.shade700)),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: emailCtrl,
                  enabled: !otpSent,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Email is required' : null,
                ),
                if (otpSent) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: otpCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reset code (check your email)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Code is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'At least 6 characters'
                        : null,
                  ),
                ],
              ],
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
                            backgroundColor: Colors.green,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(40),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'AimPark Admin',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to the internal admin panel',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Email is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    obscureText: _obscure,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Password is required' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 16)),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _showForgotPasswordDialog(context),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
