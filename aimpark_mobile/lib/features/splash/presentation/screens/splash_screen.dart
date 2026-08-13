import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/jwt_utils.dart';
import '../../../../core/widgets/app_loading_bar.dart';
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

  /// Width the comp draws the mascot at, on a 390pt-wide frame.
  static const _mascotMaxWidth = 260.0;

  late final AnimationController _controller;
  late final Animation<double> _mascotScale;
  late final Animation<double> _mascotOpacity;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;
  late final Animation<double> _loaderOpacity;

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
      curve: const Interval(0.10, 0.65, curve: Curves.elasticOut),
    ).drive(Tween(begin: 0.3, end: 1.0));

    _mascotOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.10, 0.30, curve: Curves.easeOut),
    );

    // Wordmark settles in only once the mascot has landed...
    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
    );

    _wordmarkSlide = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
    ).drive(Tween(begin: const Offset(0, 0.4), end: Offset.zero));

    // ...and the loader is last, so the eye travels top-to-bottom. It fades in
    // mid-sweep (its own cycle runs from mount) so it reads as already busy.
    _loaderOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );

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
    // 260 / 390 in the comp, capped so it never overscales on large phones.
    final mascotWidth =
        (MediaQuery.sizeOf(context).width * 0.667).clamp(160.0, _mascotMaxWidth);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status/nav icons over the full-bleed orange canvas.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.splashBackground,
      ),
      child: Scaffold(
        backgroundColor: AppColors.splashBackground,
        body: SafeArea(
          child: Column(
            children: [
              // The comp centres the mascot within the space above the
              // wordmark rather than within the whole screen.
              Expanded(
                child: Center(
                  child: FadeTransition(
                    opacity: _mascotOpacity,
                    child: ScaleTransition(
                      scale: _mascotScale,
                      // Head crop, not the full-body owl used elsewhere: the
                      // comp frames the face, and the shared asset carries a
                      // baked-in cream outline that only shows on orange.
                      child: Image.asset(
                        'assets/images/owl_mascot_head.png',
                        width: mascotWidth,
                      ),
                    ),
                  ),
                ),
              ),
              FadeTransition(
                opacity: _wordmarkOpacity,
                child: SlideTransition(
                  position: _wordmarkSlide,
                  child: Text(
                    'aimpark',
                    style: GoogleFonts.baloo2(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textOnBrand,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FadeTransition(
                opacity: _loaderOpacity,
                child: const AppLoadingBar(),
              ),
              const SizedBox(height: 44),
            ],
          ),
        ),
      ),
    );
  }
}
