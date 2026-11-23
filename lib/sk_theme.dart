// shiroikuma-kakutoku fork: builds the 白い熊 獲得 UI ThemeData from the colour
// roles (lib/providers/sk_roles.dart) and the shape, font and density knobs.
//
// This is the mixed way in its Flutter form. Upstream's screens are not
// edited for colour: they keep reading Theme.of(context), and every theme
// and colour-scheme entry below is fed from a role of its own, so a colour
// set on the UI page reaches them. No colour is written in this file — a
// literal belongs in the role table and nowhere else.

import 'package:material_ui/material_ui.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';

FontWeight skFontWeight(double w) =>
    FontWeight.values[(w / 100).round().clamp(1, 9) - 1];

/// Frame width of the main action of a block.
const double skPillMainWidth = 3;

/// Frame width of every other action.
const double skPillRegularWidth = 1.25;

/// How strongly a disabled pill is dimmed.
const double skDisabledAlpha = 0.38;

/// The style of a pill button: fully round, an outline, the ground showing
/// through — never filled. A main action is told from the others by weight
/// only: a 3 dp frame and a bold label against 1.25 dp and normal. A
/// destructive action passes its red as both [frame] and [label].
ButtonStyle skPillStyle({
  required Color frame,
  required Color label,
  required Color ground,
  TextStyle? base,
  bool main = false,
}) {
  Color dimmed(Color c, Set<WidgetState> states) =>
      states.contains(WidgetState.disabled)
      ? c.withValues(alpha: c.a * skDisabledAlpha)
      : c;
  return ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(ground),
    foregroundColor: WidgetStateProperty.resolveWith((s) => dimmed(label, s)),
    iconColor: WidgetStateProperty.resolveWith((s) => dimmed(label, s)),
    overlayColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.pressed)
          ? label.withValues(alpha: 0.3)
          : (s.contains(WidgetState.focused) || s.contains(WidgetState.hovered))
          ? label.withValues(alpha: 0.15)
          : null,
    ),
    shadowColor: WidgetStatePropertyAll(ground.withValues(alpha: 0)),
    surfaceTintColor: WidgetStatePropertyAll(ground.withValues(alpha: 0)),
    elevation: const WidgetStatePropertyAll(0),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    side: WidgetStateProperty.resolveWith(
      (s) => BorderSide(
        color: dimmed(frame, s),
        width: main ? skPillMainWidth : skPillRegularWidth,
      ),
    ),
    textStyle: WidgetStatePropertyAll(
      (base ?? const TextStyle()).copyWith(
        fontWeight: main ? FontWeight.bold : base?.fontWeight,
      ),
    ),
  );
}

/// The knob-driven theme. [baseFontFamily] is used when the knobs don't
/// select a font of their own ('' = app default).
ThemeData buildSkTheme(SkUiKnobs k, String baseFontFamily) {
  final p = SkPalette(k);
  final family = k.fontFamily.isEmpty ? baseFontFamily : k.fontFamily;

  // A frame in the page's border width; none at all when the knob is at 0.
  BorderSide side(SkRole role) => k.borderWidth <= 0
      ? BorderSide.none
      : BorderSide(color: p[role], width: k.borderWidth);
  // The same, for things that must keep an outline to be seen at all.
  BorderSide outline(SkRole role) =>
      BorderSide(color: p[role], width: k.borderWidth > 0 ? k.borderWidth : 1);
  ShapeBorder panel(SkRole frame) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(k.cornerRadius),
    side: side(frame),
  );
  Color clear(SkRole role) => p[role].withValues(alpha: 0);

  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: p[SkRole.schemePrimary],
    onPrimary: p[SkRole.schemeOnPrimary],
    primaryContainer: p[SkRole.schemePrimaryContainer],
    onPrimaryContainer: p[SkRole.schemeOnPrimaryContainer],
    secondary: p[SkRole.schemeSecondary],
    onSecondary: p[SkRole.schemeOnSecondary],
    secondaryContainer: p[SkRole.schemeSecondaryContainer],
    onSecondaryContainer: p[SkRole.schemeOnSecondaryContainer],
    tertiary: p[SkRole.schemeTertiary],
    onTertiary: p[SkRole.schemeOnTertiary],
    tertiaryContainer: p[SkRole.schemeTertiaryContainer],
    onTertiaryContainer: p[SkRole.schemeOnTertiaryContainer],
    error: p[SkRole.schemeError],
    onError: p[SkRole.schemeOnError],
    errorContainer: p[SkRole.schemeErrorContainer],
    onErrorContainer: p[SkRole.schemeOnErrorContainer],
    surface: p[SkRole.schemeSurface],
    onSurface: p[SkRole.schemeOnSurface],
    onSurfaceVariant: p[SkRole.schemeOnSurfaceVariant],
    surfaceContainerLowest: p[SkRole.schemeSurfaceLowest],
    surfaceContainerLow: p[SkRole.schemeSurfaceLow],
    surfaceContainer: p[SkRole.schemeSurfaceContainer],
    surfaceContainerHigh: p[SkRole.schemeSurfaceHigh],
    surfaceContainerHighest: p[SkRole.schemeSurfaceHighest],
    outline: p[SkRole.schemeOutline],
    outlineVariant: p[SkRole.schemeOutlineVariant],
    inverseSurface: p[SkRole.schemeInverseSurface],
    onInverseSurface: p[SkRole.schemeOnInverseSurface],
    inversePrimary: p[SkRole.schemeInversePrimary],
    surfaceTint: p[SkRole.schemeSurfaceTint],
    shadow: p[SkRole.schemeShadow],
    scrim: p[SkRole.schemeScrim],
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: family,
  );

  TextStyle? ink(TextStyle? s, SkRole role) => s?.copyWith(
    color: p[role],
    fontWeight: skFontWeight(k.fontWeight),
    fontSize: s.fontSize == null ? null : s.fontSize! * k.fontSizeScale,
  );
  final t = base.textTheme;
  final textTheme = TextTheme(
    displayLarge: ink(t.displayLarge, SkRole.textDisplay),
    displayMedium: ink(t.displayMedium, SkRole.textDisplay),
    displaySmall: ink(t.displaySmall, SkRole.textDisplay),
    headlineLarge: ink(t.headlineLarge, SkRole.textDisplay),
    headlineMedium: ink(t.headlineMedium, SkRole.textDisplay),
    headlineSmall: ink(t.headlineSmall, SkRole.textDisplay),
    titleLarge: ink(t.titleLarge, SkRole.textTitle),
    titleMedium: ink(t.titleMedium, SkRole.textTitle),
    titleSmall: ink(t.titleSmall, SkRole.textTitle),
    bodyLarge: ink(t.bodyLarge, SkRole.textBody),
    bodyMedium: ink(t.bodyMedium, SkRole.textBody),
    bodySmall: ink(t.bodySmall, SkRole.textSmall),
    labelLarge: ink(t.labelLarge, SkRole.textLabel),
    labelMedium: ink(t.labelMedium, SkRole.textLabel),
    labelSmall: ink(t.labelSmall, SkRole.textSmall),
  );

  final iconSize = 24.0 * k.iconSizeScale;

  // Every button is an outlined pill. A button upstream drew filled is the
  // main action of its block; every other kind is a regular one.
  final mainPill = skPillStyle(
    frame: p[SkRole.buttonMainFrame],
    label: p[SkRole.buttonMainLabel],
    ground: p[SkRole.buttonGround],
    base: textTheme.labelLarge,
    main: true,
  );
  final regularPill = skPillStyle(
    frame: p[SkRole.buttonFrame],
    label: p[SkRole.buttonLabel],
    ground: p[SkRole.buttonGround],
    base: textTheme.labelLarge,
  );

  Color dimIfDisabled(Color c, Set<WidgetState> s) =>
      s.contains(WidgetState.disabled)
      ? c.withValues(alpha: c.a * skDisabledAlpha)
      : c;

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(k.cornerRadius),
    borderSide: outline(SkRole.fieldFrame),
  );
  final inputDecoration = InputDecorationThemeData(
    filled: true,
    fillColor: p[SkRole.fieldGround],
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: fieldBorder,
    enabledBorder: fieldBorder,
    disabledBorder: fieldBorder.copyWith(
      borderSide: fieldBorder.borderSide.copyWith(
        color: p[SkRole.fieldFrame].withValues(alpha: skDisabledAlpha),
      ),
    ),
    focusedBorder: fieldBorder.copyWith(
      borderSide: BorderSide(
        color: p[SkRole.fieldFocusFrame],
        width: k.borderWidth > 0 ? k.borderWidth + 1 : 2,
      ),
    ),
    errorBorder: fieldBorder.copyWith(
      borderSide: fieldBorder.borderSide.copyWith(color: p[SkRole.warning]),
    ),
    focusedErrorBorder: fieldBorder.copyWith(
      borderSide: BorderSide(
        color: p[SkRole.warning],
        width: k.borderWidth > 0 ? k.borderWidth + 1 : 2,
      ),
    ),
    labelStyle: textTheme.bodyMedium?.copyWith(color: p[SkRole.fieldLabel]),
    floatingLabelStyle: textTheme.bodyMedium?.copyWith(
      color: p[SkRole.fieldLabel],
    ),
    hintStyle: textTheme.bodyMedium?.copyWith(color: p[SkRole.fieldHint]),
    helperStyle: textTheme.bodySmall?.copyWith(color: p[SkRole.fieldHint]),
    errorStyle: textTheme.bodySmall?.copyWith(color: p[SkRole.warning]),
    prefixIconColor: p[SkRole.listIcon],
    suffixIconColor: p[SkRole.listIcon],
  );
  final menuStyle = MenuStyle(
    backgroundColor: WidgetStatePropertyAll(p[SkRole.menuGround]),
    surfaceTintColor: WidgetStatePropertyAll(clear(SkRole.menuGround)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius),
        side: outline(SkRole.menuFrame),
      ),
    ),
  );

  return base.copyWith(
    extensions: [p],
    scaffoldBackgroundColor: p.base(SkBase.background),
    canvasColor: p.base(SkBase.background),
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: IconThemeData(color: p.base(SkBase.icon), size: iconSize),
    primaryIconTheme: IconThemeData(color: p.base(SkBase.icon), size: iconSize),
    visualDensity: VisualDensity.compact,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p[SkRole.cursor],
      selectionColor: p[SkRole.selection],
      selectionHandleColor: p[SkRole.selectionHandle],
    ),
    dividerTheme: DividerThemeData(
      color: p[SkRole.divider],
      thickness: k.borderWidth,
      space: k.borderWidth,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p[SkRole.appBarGround],
      foregroundColor: p[SkRole.appBarTitle],
      surfaceTintColor: clear(SkRole.appBarGround),
      iconTheme: IconThemeData(color: p[SkRole.appBarIcon], size: iconSize),
      actionsIconTheme: IconThemeData(
        color: p[SkRole.appBarIcon],
        size: iconSize,
      ),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: p[SkRole.appBarTitle],
      ),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: p[SkRole.cardGround],
      surfaceTintColor: clear(SkRole.cardGround),
      shape: panel(SkRole.cardFrame),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p[SkRole.dialogGround],
      surfaceTintColor: clear(SkRole.dialogGround),
      barrierColor: p[SkRole.dialogScrim],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius),
        side: outline(SkRole.dialogFrame),
      ),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: p[SkRole.dialogTitle],
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: p[SkRole.dialogBody],
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p[SkRole.sheetGround],
      modalBackgroundColor: p[SkRole.sheetGround],
      surfaceTintColor: clear(SkRole.sheetGround),
      modalBarrierColor: p[SkRole.dialogScrim],
      dragHandleColor: p[SkRole.sheetHandle],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(k.cornerRadius),
        ),
        side: outline(SkRole.sheetFrame),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p[SkRole.snackGround],
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: p[SkRole.snackText],
      ),
      actionTextColor: p[SkRole.snackAction],
      closeIconColor: p[SkRole.snackText],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius),
        side: outline(SkRole.snackFrame),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius),
      ),
      iconColor: p[SkRole.listIcon],
      textColor: p[SkRole.listTitle],
      subtitleTextStyle: textTheme.bodySmall?.copyWith(
        color: p[SkRole.listSubtitle],
      ),
      selectedColor: p[SkRole.listTitle],
      selectedTileColor: p[SkRole.listSelected],
      dense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: k.rowSpacing / 2,
      ),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: panel(SkRole.cardFrame),
      collapsedShape: panel(SkRole.cardFrame),
      iconColor: p[SkRole.listIcon],
      collapsedIconColor: p[SkRole.listIcon],
      textColor: p[SkRole.listTitle],
      collapsedTextColor: p[SkRole.listTitle],
    ),
    // A chip that is on or off is a selection control, not an action: its
    // fill may mark the chosen state.
    chipTheme: ChipThemeData(
      backgroundColor: p[SkRole.chipGround],
      selectedColor: p[SkRole.chipSelected],
      checkmarkColor: p[SkRole.chipCheck],
      surfaceTintColor: clear(SkRole.chipGround),
      labelStyle: textTheme.labelLarge?.copyWith(color: p[SkRole.chipLabel]),
      iconTheme: IconThemeData(color: p[SkRole.chipLabel], size: 18),
      side: outline(SkRole.chipFrame),
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: inputDecoration,
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: inputDecoration,
      menuStyle: menuStyle,
      textStyle: textTheme.bodyMedium?.copyWith(color: p[SkRole.fieldText]),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p[SkRole.menuGround],
      surfaceTintColor: clear(SkRole.menuGround),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.cornerRadius),
        side: outline(SkRole.menuFrame),
      ),
      textStyle: textTheme.bodyMedium?.copyWith(color: p[SkRole.menuLabel]),
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.bodyMedium?.copyWith(color: p[SkRole.menuLabel]),
      ),
      iconColor: p[SkRole.menuCheck],
    ),
    menuTheme: MenuThemeData(style: menuStyle),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(p[SkRole.menuLabel]),
        iconColor: WidgetStatePropertyAll(p[SkRole.menuCheck]),
        overlayColor: WidgetStatePropertyAll(
          p[SkRole.menuLabel].withValues(alpha: 0.15),
        ),
        textStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: mainPill),
    elevatedButtonTheme: ElevatedButtonThemeData(style: regularPill),
    outlinedButtonTheme: OutlinedButtonThemeData(style: regularPill),
    textButtonTheme: TextButtonThemeData(style: regularPill),
    // A button that is only a glyph stays a glyph, in every variant.
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => dimIfDisabled(p[SkRole.glyphButton], s),
        ),
        backgroundColor: WidgetStatePropertyAll(clear(SkRole.glyphButton)),
        overlayColor: WidgetStatePropertyAll(
          p[SkRole.glyphButton].withValues(alpha: 0.15),
        ),
      ),
    ),
    // A segment that is chosen is a selection, so its fill may mark it.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(outline(SkRole.segFrame)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? p[SkRole.segSelectedGround]
              : p[SkRole.segGround],
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? p[SkRole.segSelectedLabel]
              : p[SkRole.segLabel],
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? p[SkRole.segSelectedLabel]
              : p[SkRole.segLabel],
        ),
      ),
    ),
    // The floating button is an outlined ring (a pill when it carries a
    // label), never a filled slab; it is the main action of its screen.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p[SkRole.fabGround],
      foregroundColor: p[SkRole.fabIcon],
      splashColor: p[SkRole.fabIcon].withValues(alpha: 0.3),
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      disabledElevation: 0,
      shape: StadiumBorder(
        side: BorderSide(color: p[SkRole.fabFrame], width: skPillMainWidth),
      ),
      extendedTextStyle: textTheme.labelLarge?.copyWith(
        color: p[SkRole.fabIcon],
        fontWeight: FontWeight.bold,
      ),
    ),
    // Stock switches that are not the fork's own drop-in (see
    // components/sk_dropins.dart) still follow the outlined look as far as
    // the theme can take it: no fill, an outline and a dot.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? p[SkRole.switchOnDot]
            : p[SkRole.switchOffDot],
      ),
      trackColor: WidgetStatePropertyAll(clear(SkRole.switchOnOutline)),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? p[SkRole.switchOnOutline]
            : p[SkRole.switchOffOutline],
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(2),
    ),
    // Check boxes and radio buttons are selection marks, in their own roles.
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? dimIfDisabled(p[SkRole.checkOn], s)
            : clear(SkRole.checkOn),
      ),
      checkColor: WidgetStatePropertyAll(p[SkRole.checkTick]),
      side: outline(SkRole.checkOff),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => dimIfDisabled(
          s.contains(WidgetState.selected)
              ? p[SkRole.radioOn]
              : p[SkRole.radioOff],
          s,
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p[SkRole.sliderActive],
      inactiveTrackColor: p[SkRole.sliderTrack],
      thumbColor: p[SkRole.sliderThumb],
      overlayColor: p[SkRole.sliderThumb].withValues(alpha: 0.12),
      valueIndicatorColor: p[SkRole.sliderValueGround],
      valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
        color: p[SkRole.sliderValueText],
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p[SkRole.progress],
      linearTrackColor: p[SkRole.progressTrack],
      circularTrackColor: p[SkRole.progressTrack],
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p[SkRole.tabSelected],
      unselectedLabelColor: p[SkRole.tabUnselected],
      indicatorColor: p[SkRole.tabSelected],
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p[SkRole.navGround],
      surfaceTintColor: clear(SkRole.navGround),
      indicatorColor: p[SkRole.navIndicator],
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? p[SkRole.navIconSelected]
              : p[SkRole.navIcon],
          size: iconSize,
        ),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(color: p[SkRole.navLabel]),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p[SkRole.navGround],
      indicatorColor: p[SkRole.navIndicator],
      selectedIconTheme: IconThemeData(
        color: p[SkRole.navIconSelected],
        size: iconSize,
      ),
      unselectedIconTheme: IconThemeData(
        color: p[SkRole.navIcon],
        size: iconSize,
      ),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: p[SkRole.navLabel],
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: p[SkRole.navLabel],
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(p[SkRole.searchGround]),
      surfaceTintColor: WidgetStatePropertyAll(clear(SkRole.searchGround)),
      textStyle: WidgetStatePropertyAll(
        textTheme.bodyLarge?.copyWith(color: p[SkRole.searchText]),
      ),
      hintStyle: WidgetStatePropertyAll(
        textTheme.bodyLarge?.copyWith(color: p[SkRole.searchHint]),
      ),
      shape: WidgetStatePropertyAll(
        StadiumBorder(side: side(SkRole.searchFrame)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p[SkRole.tooltipGround],
        borderRadius: BorderRadius.circular(k.cornerRadius / 2),
        border: k.borderWidth > 0
            ? Border.all(color: p[SkRole.tooltipFrame], width: k.borderWidth)
            : null,
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: p[SkRole.tooltipText]),
    ),
  );
}
