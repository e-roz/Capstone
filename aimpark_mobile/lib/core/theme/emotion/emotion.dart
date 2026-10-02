/// The emotional design system's public surface (brief §1–§6).
///
/// Import this and read tokens off `context.emotion`. `emotion_palette.dart`
/// is deliberately **not** exported, for the same reason `app_palette.dart`
/// isn't: a screen reaching for a raw hex value has hardcoded a decision the
/// token layer exists to own.
library;

export 'emotion_haptics.dart';
export 'emotion_motion.dart';
export 'emotion_tokens.dart';
export 'emotion_typography.dart';
