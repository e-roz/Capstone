/// AimPark spacing and radius scale — mirrors the Figma Spacing/Radius
/// variable collections.
abstract class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const full = 9999.0;
}

/// Vertical offset of the pressed-shadow layer behind buttons/cards that use
/// the Duolingo-style tactile depth effect.
const double kPressedShadowOffset = 5.0;
