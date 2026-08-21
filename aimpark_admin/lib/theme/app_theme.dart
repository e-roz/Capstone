import 'package:flutter/material.dart';

import 'app_dimensions.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// LAYER 3 — Component defaults.
///
/// This file is where tokens meet Material. Every `*ThemeData` below exists so
/// that an *unstyled* widget already looks right: a bare `ElevatedButton`, a
/// bare `DataTable`, a bare `TextField` should each come out of the box
/// matching the system, with no `style:` argument at the call site.
///
/// That is the whole trick to keeping later features consistent. Consistency
/// enforced by a code review will eventually slip; consistency that is simply
/// the default cannot.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppTokens.light, Brightness.light);
  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: t.brand.primary,
      brightness: brightness,
    ).copyWith(
      primary: t.brand.primary,
      onPrimary: t.text.onBrand,
      primaryContainer: t.brand.subtle,
      onPrimaryContainer: t.brand.subtleText,
      surface: t.surface.card,
      onSurface: t.text.primary,
      onSurfaceVariant: t.text.secondary,
      surfaceContainerLowest: t.surface.card,
      surfaceContainerLow: t.surface.canvas,
      surfaceContainer: t.surface.muted,
      surfaceContainerHigh: t.surface.muted,
      error: t.status.danger.solid,
      onError: t.text.onBrand,
      errorContainer: t.status.danger.bg,
      onErrorContainer: t.status.danger.fg,
      outline: t.border.normal,
      outlineVariant: t.border.subtle,
    );

    final text = AppTypography.textTheme(t.text.primary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.surface.canvas,
      canvasColor: t.surface.card,
      textTheme: text,
      extensions: [t],

      // Material 3 tints hovered/pressed surfaces with the primary colour by
      // default, which turns every table row faintly blue. The system uses
      // explicit hover tokens instead.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: t.surface.hover,

      iconTheme: IconThemeData(color: t.text.secondary, size: AppSizes.iconMd),
      primaryIconTheme: IconThemeData(color: t.text.onBrand),

      dividerTheme: DividerThemeData(
        color: t.border.subtle,
        thickness: 1,
        space: 1,
      ),

      // ── Containers ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: t.surface.card,
        // Real shadows come from AppCard; Material's elevation would add a
        // colour tint on top of them.
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lgAll,
          side: BorderSide(color: t.border.normal),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: t.surface.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: t.surface.overlay,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: BorderSide(color: t.border.normal),
        ),
        textStyle: text.bodyMedium,
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: t.surface.sidebar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: t.surface.card,
        foregroundColor: t.text.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
        shape: Border(bottom: BorderSide(color: t.border.normal)),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: t.text.secondary,
        textColor: t.text.primary,
        titleTextStyle: text.bodyMedium,
        subtitleTextStyle: text.bodySmall?.copyWith(color: t.text.secondary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),

      // ── Data display ──────────────────────────────────────────────────────
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(t.surface.muted),
        headingRowHeight: AppSizes.tableHeaderHeight,
        headingTextStyle: text.labelMedium?.copyWith(color: t.text.secondary),
        dataRowMinHeight: AppSizes.tableRowHeight,
        dataRowMaxHeight: AppSizes.tableRowHeight,
        dataTextStyle: text.bodyMedium,
        dividerThickness: 1,
        horizontalMargin: AppSpacing.cellPaddingX,
        columnSpacing: AppSpacing.x6,
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.surface.selected;
          if (states.contains(WidgetState.hovered)) return t.surface.hover;
          return null;
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: t.surface.muted,
        selectedColor: t.brand.subtle,
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!,
        side: BorderSide(color: t.border.normal),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
        showCheckmark: false,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.surface.inverse,
          borderRadius: AppRadii.smAll,
        ),
        textStyle: text.bodySmall?.copyWith(color: t.text.inverse),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
        waitDuration: const Duration(milliseconds: 400),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.brand.primary,
        linearTrackColor: t.surface.muted,
        circularTrackColor: t.surface.muted,
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(t.border.strong),
        radius: const Radius.circular(AppRadii.full),
        thickness: const WidgetStatePropertyAll(8),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surface.inverse,
        contentTextStyle: text.bodyMedium?.copyWith(color: t.text.inverse),
        actionTextColor: t.brand.subtle,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        insetPadding: const EdgeInsets.all(AppSpacing.x6),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: t.brand.primary,
        unselectedLabelColor: t.text.secondary,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: t.brand.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: t.border.normal,
        overlayColor: WidgetStatePropertyAll(t.surface.hover),
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface.card,
        hintStyle: text.bodyMedium?.copyWith(color: t.text.tertiary),
        labelStyle: text.bodyMedium?.copyWith(color: t.text.secondary),
        floatingLabelStyle: text.bodySmall?.copyWith(color: t.brand.primary),
        helperStyle: text.bodySmall?.copyWith(color: t.text.secondary),
        errorStyle: text.bodySmall?.copyWith(color: t.status.danger.fg),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3, vertical: AppSpacing.x3),
        border: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: t.border.normal),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: t.border.normal),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: t.border.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: t.status.danger.solid),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: t.status.danger.solid, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: t.border.subtle),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4))),
        side: BorderSide(color: t.border.strong, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.brand.primary;
          return Colors.transparent;
        }),
      ),

      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.brand.primary;
          return t.border.strong;
        }),
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      // Four roles, and the system expects them used by meaning, not by looks:
      //   FilledButton   → the one primary action on the screen
      //   ElevatedButton → same weight as filled; kept aligned for existing code
      //   OutlinedButton → secondary actions
      //   TextButton     → tertiary / cancel
      filledButtonTheme: FilledButtonThemeData(style: _primaryStyle(t, text)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryStyle(t, text)),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(t.text.primary),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return t.surface.hover;
            return t.surface.card;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: t.border.subtle);
            }
            if (states.contains(WidgetState.hovered)) {
              return BorderSide(color: t.border.strong);
            }
            return BorderSide(color: t.border.normal);
          }),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
              horizontal: AppSpacing.x4, vertical: AppSpacing.x2)),
          minimumSize:
              const WidgetStatePropertyAll(Size(0, AppSizes.controlHeight)),
          shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: AppRadii.mdAll)),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return t.text.disabled;
            return t.brand.primary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return t.brand.subtle;
            return Colors.transparent;
          }),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
              horizontal: AppSpacing.x3, vertical: AppSpacing.x2)),
          minimumSize:
              const WidgetStatePropertyAll(Size(0, AppSizes.controlHeight)),
          shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: AppRadii.mdAll)),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return t.text.disabled;
            return t.text.secondary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return t.surface.hover;
            return Colors.transparent;
          }),
          shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: AppRadii.mdAll)),
        ),
      ),
    );
  }

  static ButtonStyle _primaryStyle(AppTokens t, TextTheme text) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return t.text.disabled;
        return t.text.onBrand;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return t.surface.muted;
        if (states.contains(WidgetState.pressed)) return t.brand.pressed;
        if (states.contains(WidgetState.hovered)) return t.brand.hover;
        return t.brand.primary;
      }),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
          horizontal: AppSpacing.x4, vertical: AppSpacing.x2)),
      minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.controlHeight)),
      shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadii.mdAll)),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}
