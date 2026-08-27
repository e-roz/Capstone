// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appThemeModeHash() => r'11179bca8f59dde32b171b2f03becb0542971485';

/// The user's appearance preference, remembered between launches.
///
/// Defaults to [ThemeMode.system], which is the right default: someone who has
/// put their phone into dark mode at night has already said what they want, and
/// asking again is a setting nobody should have to find.
///
/// The explicit Light and Dark options exist anyway for one practical reason —
/// showing both themes during the defence should not require leaving the app to
/// change a system setting.
///
/// Copied from [AppThemeMode].
@ProviderFor(AppThemeMode)
final appThemeModeProvider = NotifierProvider<AppThemeMode, ThemeMode>.internal(
  AppThemeMode.new,
  name: r'appThemeModeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appThemeModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppThemeMode = Notifier<ThemeMode>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
