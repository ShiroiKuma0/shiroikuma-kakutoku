// shiroikuma-kakutoku fork: builds the 白い熊 獲得 UI ThemeData from the
// SkUiKnobs — black-yellow by default, every attribute driven by the knobs
// so edits on the UI page restyle the whole app instantly.

import 'package:flutter/material.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';

FontWeight skFontWeight(double w) =>
    FontWeight.values[(w / 100).round().clamp(1, 9) - 1];

TextTheme _applyKnobs(TextTheme t, SkUiKnobs k, Color color, Color dim) {
  TextStyle? f(TextStyle? s, {bool secondary = false}) => s?.copyWith(
    color: secondary ? dim : color,
    fontWeight: skFontWeight(k.fontWeight),
    fontSize: s.fontSize == null ? null : s.fontSize! * k.fontSizeScale,
  );
  return TextTheme(
    displayLarge: f(t.displayLarge),
    displayMedium: f(t.displayMedium),
    displaySmall: f(t.displaySmall),
    headlineLarge: f(t.headlineLarge),
    headlineMedium: f(t.headlineMedium),
    headlineSmall: f(t.headlineSmall),
    titleLarge: f(t.titleLarge),
    titleMedium: f(t.titleMedium),
    titleSmall: f(t.titleSmall),
    bodyLarge: f(t.bodyLarge),
    bodyMedium: f(t.bodyMedium),
    bodySmall: f(t.bodySmall, secondary: true),
    labelLarge: f(t.labelLarge),
    labelMedium: f(t.labelMedium),
    labelSmall: f(t.labelSmall, secondary: true),
  );
}

/// The knob-driven theme. [baseFontFamily] is used when the knobs don't
/// select a font of their own ('' = app default).
ThemeData buildSkTheme(SkUiKnobs k, String baseFontFamily) {
  final family = k.fontFamily.isEmpty ? baseFontFamily : k.fontFamily;
  final side = k.borderWidth <= 0
      ? BorderSide.none
      : BorderSide(color: k.border, width: k.borderWidth);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(k.cornerRadius),
    side: side,
  );
  final dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(k.cornerRadius),
    side: side,
  );

  final scheme =
      ColorScheme.dark(
        surface: k.background,
        onSurface: k.textPrimary,
        onSurfaceVariant: k.textSecondary,
        surfaceContainerLowest: k.background,
        surfaceContainerLow: k.surface,
        surfaceContainer: k.surface,
        surfaceContainerHigh: k.surface,
        surfaceContainerHighest: k.surface,
        inverseSurface: k.textPrimary,
        onInverseSurface: k.background,
        primary: k.accent,
        onPrimary: k.onAccent,
        primaryContainer: k.surface,
        onPrimaryContainer: k.textPrimary,
        secondary: k.accent,
        onSecondary: k.onAccent,
        secondaryContainer: k.surface,
        onSecondaryContainer: k.textPrimary,
        tertiary: k.accent,
        onTertiary: k.onAccent,
        tertiaryContainer: k.surface,
        onTertiaryContainer: k.textPrimary,
        outline: k.border,
        outlineVariant: k.border.withValues(alpha: 0.5),
        shadow: Colors.black,
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: family,
  );

  final textTheme = _applyKnobs(
    base.textTheme,
    k,
    k.textPrimary,
    k.textSecondary,
  );

  final iconSize = 24.0 * k.iconSizeScale;

  final pillButtonStyle = ButtonStyle(
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius * 2),
      ),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
  );

  return base.copyWith(
    scaffoldBackgroundColor: k.background,
    canvasColor: k.background,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: IconThemeData(color: k.icon, size: iconSize),
    primaryIconTheme: IconThemeData(color: k.icon, size: iconSize),
    visualDensity: VisualDensity.compact,
    dividerTheme: DividerThemeData(
      color: k.border,
      thickness: k.borderWidth,
      space: k.borderWidth,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: k.appBarBackground,
      foregroundColor: k.appBarForeground,
      iconTheme: IconThemeData(color: k.appBarForeground, size: iconSize),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: k.appBarForeground,
      ),
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: k.surface,
      shape: shape,
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: k.background,
      shape: dialogShape,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: k.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(k.cornerRadius),
        ),
        side: side,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: k.surface,
      contentTextStyle: textTheme.bodyMedium,
      shape: shape,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius),
      ),
      iconColor: k.icon,
      textColor: k.textPrimary,
      dense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: k.rowSpacing / 2,
      ),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: shape,
      collapsedShape: shape,
      iconColor: k.icon,
      collapsedIconColor: k.icon,
      textColor: k.textPrimary,
      collapsedTextColor: k.textPrimary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: k.surface,
      selectedColor: k.accent,
      labelStyle: textTheme.labelLarge,
      side: side,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius),
        borderSide: k.borderWidth <= 0
            ? BorderSide(color: k.border, width: 1)
            : side,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius),
        borderSide: k.borderWidth <= 0
            ? BorderSide(color: k.border.withValues(alpha: 0.6), width: 1)
            : side,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius),
        borderSide: BorderSide(
          color: k.accent,
          width: k.borderWidth > 0 ? k.borderWidth + 1 : 2,
        ),
      ),
      labelStyle: textTheme.bodyMedium,
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: k.textSecondary.withValues(alpha: 0.7),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(k.cornerRadius),
          borderSide: side == BorderSide.none
              ? BorderSide(color: k.border, width: 1)
              : side,
        ),
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(k.background),
        shape: WidgetStatePropertyAll(shape),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: k.background,
      shape: shape,
      textStyle: textTheme.bodyMedium,
      iconColor: k.icon,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(k.background),
        shape: WidgetStatePropertyAll(shape),
      ),
    ),
    // Filled buttons (e.g. the "Update" banner button, dialog actions):
    // black fill, accent text, accent border — the house action-button look.
    filledButtonTheme: FilledButtonThemeData(
      style: pillButtonStyle.copyWith(
        backgroundColor: WidgetStatePropertyAll(k.fabBackground),
        foregroundColor: WidgetStatePropertyAll(k.fabForeground),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: k.border,
            width: k.borderWidth > 0 ? k.borderWidth : 1.5,
          ),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: pillButtonStyle.copyWith(
        backgroundColor: WidgetStatePropertyAll(k.surface),
        foregroundColor: WidgetStatePropertyAll(k.textPrimary),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: pillButtonStyle.copyWith(
        foregroundColor: WidgetStatePropertyAll(k.textPrimary),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: k.border,
            width: k.borderWidth > 0 ? k.borderWidth : 1,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(k.accent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(k.cornerRadius * 2),
          ),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(
          BorderSide(
            color: k.border,
            width: k.borderWidth > 0 ? k.borderWidth : 1,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? k.accent
              : k.background,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? k.onAccent
              : k.textPrimary,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: k.fabBackground,
      foregroundColor: k.fabForeground,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius * 1.5),
        side: side,
      ),
      extendedTextStyle: textTheme.labelLarge?.copyWith(
        color: k.fabForeground,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? k.onAccent : k.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? k.accent : k.surface,
      ),
      trackOutlineColor: WidgetStatePropertyAll(k.border),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? k.accent
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(k.onAccent),
      side: BorderSide(
        color: k.border,
        width: k.borderWidth > 0 ? k.borderWidth : 1,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStatePropertyAll(k.accent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: k.accent,
      inactiveTrackColor: k.surface,
      thumbColor: k.accent,
      overlayColor: k.accent.withValues(alpha: 0.12),
      valueIndicatorColor: k.accent,
      valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
        color: k.onAccent,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: k.accent,
      linearTrackColor: k.surface,
      circularTrackColor: k.surface,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: k.accent,
      unselectedLabelColor: k.textSecondary,
      indicatorColor: k.accent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: k.background,
      indicatorColor: k.accent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? k.onAccent : k.icon,
          size: iconSize,
        ),
      ),
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(k.surface),
      textStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
      hintStyle: WidgetStatePropertyAll(
        textTheme.bodyLarge?.copyWith(
          color: k.textSecondary.withValues(alpha: 0.7),
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(k.cornerRadius * 2),
          side: side,
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(k.cornerRadius / 2),
        border: k.borderWidth > 0
            ? Border.all(color: k.border, width: k.borderWidth)
            : null,
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: k.textPrimary),
    ),
  );
}
