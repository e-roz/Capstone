import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/jwt_utils.dart';
import '../../../notifications/presentation/providers/push_registration_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  static const _minDisplayDuration = Duration(milliseconds: 1700);

  late final AnimationController _controller;
  late final Animation<double> _mascotScale;
  late final Animation<double> _mascotOpacity;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Mascot "booms" in with a bouncy overshoot, slightly after the
    // background color has already filled the screen.
    _mascotScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.70, curve: Curves.elasticOut),
    ).drive(Tween(begin: 0.3, end: 1.0));

    _mascotOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.35, curve: Curves.easeOut),
    );

    // Wordmark settles in only once the mascot has landed.
    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
    );

    _wordmarkSlide = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
    ).drive(Tween(begin: const Offset(0, 0.4), end: Offset.zero));

    _controller.forward();
    _resolveDestination();
  }

  Future<void> _resolveDestination() async {
    final stopwatch = Stopwatch()..start();

    final token = await _storage.read(key: authTokenKey);
    final hasValidToken = token != null && JwtUtils.isValid(token);
    final destination = hasValidToken
        ? JwtUtils.homeRouteForRole(JwtUtils.getRole(token)) ?? '/login'
        : '/login';

    final remaining = _minDisplayDuration - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (mounted) {
      context.go(destination);
    }

    // A returning user with a stored session never passes through the login
    // screen, so this is the only place their device gets (re)registered for
    // push. Registering is idempotent, and running it every launch also picks
    // up rotated tokens and permission granted after a previous refusal.
    // Fired after navigation so the OS permission prompt lands on the home
    // screen rather than over the splash animation.
    if (hasValidToken && !JwtUtils.isRegistrationOnly(token)) {
      unawaited(ref.read(pushRegistrationProvider.notifier).registerAfterLogin());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.accentDefault,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _mascotOpacity,
              child: ScaleTransition(
                scale: _mascotScale,
                child: Image.asset('assets/images/owl_mascot.png', width: 180),
              ),
            ),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: _wordmarkOpacity,
              child: SlideTransition(
                position: _wordmarkSlide,
                child: Text(
                  'AimPark',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
