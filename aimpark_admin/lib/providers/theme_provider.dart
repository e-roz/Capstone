import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which brightness the panel renders in.
///
/// Deliberately **not** [ThemeMode.system]. The theme layer supports dark fully,
/// and every screen migrated so far reads its colours from `AppTokens` — but
/// Violations, Incidents, Policy Rules, Notifications and the two detail screens
/// still hardcode `Colors.white` and `Colors.black54`. Following the operating
/// system would hand a dark-mode user six screens of white text on white.
///
/// So dark is reachable from the sidebar, and becomes the default the moment
/// those six screens are migrated — at which point this line changes to
/// `ThemeMode.system` and nothing else has to.
final themeModeProvider =
    StateProvider<ThemeMode>((ref) => ThemeMode.light);
