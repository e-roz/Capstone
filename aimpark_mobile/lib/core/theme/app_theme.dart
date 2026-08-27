import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_dimensions.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// LAYER 3 — Component defaults.
///
/// This file is where tokens meet Material. Every `*ThemeData` below exists so
/// that an *unstyled* widget already looks right: a bare `TextField`, a bare
/// `AlertDialog`, a bare `showDatePicker` should each come out of the box
/// matching the system, with no `style:` argument at the call site.
///
/// That is the whole trick to keeping later features consistent. Consistency
/// enforced by remembering to do it will eventually slip; consistency that is
/// simply the default cannot.
///
/// It matters more here than in the admin panel, because a phone app leans on
/// platform widgets the panel never shows — the date picker on the registration
/// confirmation screen, the OTP field, the permission dialogs. Those are the
/// surfaces that used to give the app away as half-themed.
abstract class AppTheme {
  static ThemeData light() => _build(AppTokens.light, Brightness.light);
  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: t.brand.primary,
      brightness: brightness,
    ).copyWith(
      primary: t.brand.primary,
      onPrimary: t.brand.onSolid,
      primaryContainer: t.brand.subtle,
      onPrimaryContainer: t.brand.subtleText,
      secondary: t.accent.primary,
      onSecondary: t.accent.onSolid,
      secondaryContainer: t.accent.subtle,
      onSecondaryContainer: t.accent.subtleText,
      tertiary: t.tertiary.primary,
      onTertiary: t.tertiary.onSolid,
      surface: t.surface.card,
      onSurface: t.text.primary,
      onSurfaceVariant: t.text.secondary,
      surfaceContainerLowest: t.surface.card,
      surfaceContainerLow: t.surface.canvas,
      surfaceContainer: t.surface.muted,
      surfaceContainerHigh: t.surface.muted,
      surfaceContainerHighest: t.surface.muted,
      error: t.status.danger.solid,
      onError: t.text.onDark,
      errorContainer: t.status.danger.bg,
      onErrorContainer: t.status.danger.fg,
      outline: t.border.normal,
      outlineVariant: t.border.subtle,
      shadow: Colors.black,
      scrim: t.surface.scrim,
      inverseSurface: t.surface.inverse,
      onInverseSurface: t.text.inverse,
    );

    final text = AppTypography.textTheme(
      primary: t.text.primary,
      secondary: t.text.secondary,
    );

    // The status bar sits over the canvas on nearly every screen, so its icons
    // have to invert with the theme or they vanish. Screens that paint their
    // own dark background — the splash, the camera — override this locally.
    final overlay = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: t.surface.canvas,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: t.surface.canvas,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [t],
      scaffoldBackgroundColor: t.surface.canvas,
      canvasColor: t.surface.card,
      textTheme: text,
      fontFamily: AppTypography.body,

      iconTheme: IconThemeData(color: t.text.secondary, size: AppSizes.iconLg),
      primaryIconTheme: IconThemeData(color: t.brand.onSolid),

      dividerTheme: DividerThemeData(
        color: t.border.subtle,
        thickness: 1,
        space: 1,
      ),

      // ── Chrome ────────────────────────────────────────────────────────────
      // Flat and canvas-coloured, so a screen's title reads as part of the page
      // rather than as a bar bolted above it. Material 3 would otherwise tint
      // the bar with the primary colour the moment content scrolled under it,
      // which on an orange-branded app looks like a rendering fault.
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface.canvas,
        foregroundColor: t.text.primary,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: t.text.primary, size: AppSizes.iconLg),
        actionsIconTheme:
            IconThemeData(color: t.text.primary, size: AppSizes.iconLg),
        systemOverlayStyle: overlay,
      ),

      // ── Containers ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: t.surface.card,
        // Real separation comes from AppCard's border; Material's elevation
        // would add a surface tint on top of it.
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: t.border.normal, width: 1.5),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: t.surface.overlay,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface.overlay,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: t.border.strong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: t.surface.overlay,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smAll,
          side: BorderSide(color: t.border.normal),
        ),
        textStyle: text.bodyMedium,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: t.text.secondary,
        textColor: t.text.primary,
        titleTextStyle: text.bodyMedium,
        subtitleTextStyle: text.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),

      // ── Feedback ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surface.inverse,
        contentTextStyle: text.bodyMedium?.copyWith(color: t.text.inverse),
        actionTextColor: t.brand.primary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        elevation: 0,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.surface.inverse,
          borderRadius: AppRadius.smAll,
        ),
        textStyle: text.bodySmall?.copyWith(color: t.text.inverse),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.brand.primary,
        linearTrackColor: t.surface.muted,
        circularTrackColor: t.surface.muted,
        linearMinHeight: 8,
        // Also drives the pull-to-refresh spinner, which reads its arc colour
        // from here and its disc from `refreshBackgroundColor`. This Flutter
        // version has no top-level `refreshIndicatorTheme`, so this is the
        // only place both can be set.
        refreshBackgroundColor: t.surface.card,
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(t.border.strong),
        radius: const Radius.circular(AppRadius.full),
        thickness: const WidgetStatePropertyAll(4),
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      // AppTextField draws its own container, so this exists for the platform
      // widgets that build an InputDecoration themselves — the date picker's
      // manual-entry field, the search field inside a picker dialog.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface.card,
        hintStyle: text.bodyMedium?.copyWith(color: t.text.secondary),
        labelStyle: text.labelSmall,
        floatingLabelStyle: text.labelSmall?.copyWith(color: t.brand.primary),
        helperStyle: text.labelSmall,
        errorStyle: text.labelSmall?.copyWith(color: t.status.danger.fg),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: t.border.normal, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: t.border.normal, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: t.border.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: t.status.danger.solid, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: t.status.danger.solid, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: t.border.subtle, width: 1.5),
        ),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.brand.primary,
        selectionColor: t.brand.subtle,
        selectionHandleColor: t.brand.primary,
      ),

      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        side: BorderSide(color: t.border.strong, width: 2),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.brand.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(t.brand.onSolid),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.brand.primary;
          return t.border.strong;
        }),
      ),

      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbColor: WidgetStatePropertyAll(t.surface.card),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.brand.primary;
          return t.border.strong;
        }),
      ),

      // The registration flow opens this for the licence and registration
      // expiry dates. Left to Material it arrived in default indigo, which was
      // the loudest theming break left in the app.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: t.surface.overlay,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        headerBackgroundColor: t.brand.primary,
        headerForegroundColor: t.brand.onSolid,
        headerHeadlineStyle: text.headlineMedium?.copyWith(
          color: t.brand.onSolid,
        ),
        headerHelpStyle: text.labelSmall?.copyWith(color: t.brand.onSolid),
        weekdayStyle: text.labelSmall,
        dayStyle: text.bodyMedium,
        yearStyle: text.bodyMedium,
        todayBorder: BorderSide(color: t.brand.primary, width: 1.5),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.brand.onSolid;
          if (states.contains(WidgetState.disabled)) return t.text.disabled;
          return t.text.primary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.brand.primary;
          return null;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.brand.onSolid;
          return t.brand.primary;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.brand.onSolid;
          return t.text.primary;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.brand.primary;
          return null;
        }),
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      // AppButton is the app's real button and does not go through these. What
      // does go through them: dialog actions, the date picker's OK/Cancel, and
      // the handful of genuinely tertiary links. Keeping them aligned means a
      // dialog never arrives in a different accent to the screen behind it.
      filledButtonTheme: FilledButtonThemeData(style: _primaryStyle(t, text)),
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: _primaryStyle(t, text)),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return t.text.disabled;
            return t.text.primary;
          }),
          backgroundColor: WidgetStatePropertyAll(t.surface.card),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: t.border.subtle, width: 1.5);
            }
            return BorderSide(color: t.border.normal, width: 1.5);
          }),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          minimumSize:
              const WidgetStatePropertyAll(Size(0, AppSizes.controlHeight)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          ),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return t.text.disabled;
            return t.brand.subtleText;
          }),
          overlayColor: WidgetStatePropertyAll(t.brand.subtle),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          minimumSize:
              const WidgetStatePropertyAll(Size(0, AppSizes.controlHeight)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return t.text.disabled;
            return t.text.primary;
          }),
          overlayColor: WidgetStatePropertyAll(t.surface.pressed),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.brand.primary,
        foregroundColor: t.brand.onSolid,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 1,
        extendedTextStyle: text.labelLarge?.copyWith(color: t.brand.onSolid),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
    );
  }

  static ButtonStyle _primaryStyle(AppTokens t, TextTheme text) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return t.text.disabled;
        return t.brand.onSolid;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return t.surface.muted;
        if (states.contains(WidgetState.pressed)) return t.brand.pressed;
        return t.brand.primary;
      }),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.controlHeight)),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}
