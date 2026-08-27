/// The design system's public surface.
///
/// Import this — `import '../../../core/theme/theme.dart';` — and you get the
/// semantic tokens, the spacing/radius/motion scales and the theme builders.
///
/// `app_palette.dart` is deliberately **not** exported. Primitives are an
/// implementation detail of the token layer; if a screen needs a colour that
/// tokens cannot express, the fix is to add a token, not to reach past it.
library;

export 'app_dimensions.dart';
export 'app_theme.dart';
export 'app_tokens.dart';
export 'app_typography.dart';
export 'theme_mode.dart';
