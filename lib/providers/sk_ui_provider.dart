// shiroikuma-kakutoku fork: the 白い熊 獲得 UI theming layer (granular
// black-yellow theming in the style of the sister shiroikuma forks).
//
// All knobs persist as a single JSON blob in SharedPreferences; recently
// picked colors persist as a shared list so every color picker offers them
// as one-click presets. External fonts are copied into
// <app documents>/sk_fonts/ and loaded as font families named after the file.

export 'package:obtainium/providers/sk_roles.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:obtainium/providers/sk_roles.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// Current defaults revision. Bump when a shipped default changes and old
/// saved states should be migrated (see [SkUiProvider.initialize]).
const int skCurrentBtnRev = 1;

/// One themable knob set. Every field has a black-yellow default.
class SkUiKnobs {
  // Master switch.
  bool enabled;

  // Colors — the twelve foundation colours (SkBase); every role defaults
  // to one of them or to a mix of two.
  Color background;
  Color surface;
  // Colors — text.
  Color textPrimary;
  Color textSecondary;
  // Colors — accent.
  Color accent;
  Color onAccent;
  // Colors — borders & icons.
  Color border;
  Color icon;
  // Colors — app bar.
  Color appBarBackground;
  Color appBarForeground;
  // Colors — action buttons (Add FAB, Update, per-app download).
  Color fabBackground;
  Color fabForeground;

  // Bookkeeping: bumped when a new defaults revision must migrate old saves.
  int btnRev;

  // Text.
  String fontFamily; // '' = app default (Montserrat), 'SystemFont', or an
  // imported family name (sk_fonts file basename).
  double fontSizeScale; // 0.5 .. 2.0
  double fontWeight; // 100 .. 900 (FontWeight.w100..w900)

  // Shape & borders.
  double cornerRadius; // 0 .. 32
  double borderWidth; // 0 .. 6 (0 = no borders)

  // Icons.
  double iconSizeScale; // 0.5 .. 2.0

  // Density.
  double rowSpacing; // vertical list-row padding, 0 .. 16

  // Colours of single items: a role's name → ARGB. A role that is not in
  // here shows its default (see sk_roles.dart).
  Map<String, int> roles;

  // The UI page's arrangement: section order (names of SkSection) and the
  // sections that are unfolded. Stored with the knobs so they travel in the
  // export with the colours and fonts.
  List<String> sectionOrder;
  List<String> sectionsOpen;

  SkUiKnobs({
    this.enabled = true,
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? border,
    Color? icon,
    Color? appBarBackground,
    Color? appBarForeground,
    Color? fabBackground,
    Color? fabForeground,
    this.btnRev = skCurrentBtnRev,
    this.fontFamily = '',
    this.fontSizeScale = 1.0,
    this.fontWeight = 400,
    this.cornerRadius = 8,
    this.borderWidth = 1,
    this.iconSizeScale = 1.0,
    this.rowSpacing = 4,
    Map<String, int>? roles,
    List<String>? sectionOrder,
    List<String>? sectionsOpen,
  }) : background = background ?? Color(SkBase.background.defaultArgb),
       surface = surface ?? Color(SkBase.surface.defaultArgb),
       textPrimary = textPrimary ?? Color(SkBase.text.defaultArgb),
       textSecondary = textSecondary ?? Color(SkBase.dim.defaultArgb),
       accent = accent ?? Color(SkBase.accent.defaultArgb),
       onAccent = onAccent ?? Color(SkBase.onAccent.defaultArgb),
       border = border ?? Color(SkBase.border.defaultArgb),
       icon = icon ?? Color(SkBase.icon.defaultArgb),
       appBarBackground =
           appBarBackground ?? Color(SkBase.barGround.defaultArgb),
       appBarForeground = appBarForeground ?? Color(SkBase.barInk.defaultArgb),
       fabBackground = fabBackground ?? Color(SkBase.fabGround.defaultArgb),
       fabForeground = fabForeground ?? Color(SkBase.fabInk.defaultArgb),
       roles = roles ?? {},
       sectionOrder = sectionOrder ?? [],
       sectionsOpen = sectionsOpen ?? [];

  /// A foundation colour by name.
  Color base(SkBase b) => switch (b) {
    SkBase.background => background,
    SkBase.surface => surface,
    SkBase.accent => accent,
    SkBase.onAccent => onAccent,
    SkBase.text => textPrimary,
    SkBase.dim => textSecondary,
    SkBase.border => border,
    SkBase.icon => icon,
    SkBase.barGround => appBarBackground,
    SkBase.barInk => appBarForeground,
    SkBase.fabGround => fabBackground,
    SkBase.fabInk => fabForeground,
  };

  void setBase(SkBase b, Color c) {
    switch (b) {
      case SkBase.background:
        background = c;
      case SkBase.surface:
        surface = c;
      case SkBase.accent:
        accent = c;
      case SkBase.onAccent:
        onAccent = c;
      case SkBase.text:
        textPrimary = c;
      case SkBase.dim:
        textSecondary = c;
      case SkBase.border:
        border = c;
      case SkBase.icon:
        icon = c;
      case SkBase.barGround:
        appBarBackground = c;
      case SkBase.barInk:
        appBarForeground = c;
      case SkBase.fabGround:
        fabBackground = c;
      case SkBase.fabInk:
        fabForeground = c;
    }
  }

  factory SkUiKnobs.fromJson(Map<String, dynamic> m) {
    final d = SkUiKnobs();
    Color c(String k, Color def) =>
        m[k] is int ? Color(m[k] as int) : def;
    double n(String k, double def) =>
        m[k] is num ? (m[k] as num).toDouble() : def;
    List<String>? strings(String k) =>
        m[k] is List ? (m[k] as List).whereType<String>().toList() : null;
    return SkUiKnobs(
      enabled: m['enabled'] is bool ? m['enabled'] as bool : d.enabled,
      background: c('background', d.background),
      surface: c('surface', d.surface),
      textPrimary: c('textPrimary', d.textPrimary),
      textSecondary: c('textSecondary', d.textSecondary),
      accent: c('accent', d.accent),
      onAccent: c('onAccent', d.onAccent),
      border: c('border', d.border),
      icon: c('icon', d.icon),
      appBarBackground: c('appBarBackground', d.appBarBackground),
      appBarForeground: c('appBarForeground', d.appBarForeground),
      fabBackground: c('fabBackground', d.fabBackground),
      fabForeground: c('fabForeground', d.fabForeground),
      btnRev: m['btnRev'] is int ? m['btnRev'] as int : 0,
      fontFamily: m['fontFamily'] is String ? m['fontFamily'] as String : '',
      fontSizeScale: n('fontSizeScale', d.fontSizeScale),
      fontWeight: n('fontWeight', d.fontWeight),
      cornerRadius: n('cornerRadius', d.cornerRadius),
      borderWidth: n('borderWidth', d.borderWidth),
      iconSizeScale: n('iconSizeScale', d.iconSizeScale),
      rowSpacing: n('rowSpacing', d.rowSpacing),
      roles: m['roles'] is Map
          ? {
              for (final e in (m['roles'] as Map).entries)
                if (e.key is String && e.value is int)
                  e.key as String: e.value as int,
            }
          : null,
      sectionOrder: strings('sectionOrder'),
      sectionsOpen: strings('sectionsOpen'),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'background': background.toARGB32(),
    'surface': surface.toARGB32(),
    'textPrimary': textPrimary.toARGB32(),
    'textSecondary': textSecondary.toARGB32(),
    'accent': accent.toARGB32(),
    'onAccent': onAccent.toARGB32(),
    'border': border.toARGB32(),
    'icon': icon.toARGB32(),
    'appBarBackground': appBarBackground.toARGB32(),
    'appBarForeground': appBarForeground.toARGB32(),
    'fabBackground': fabBackground.toARGB32(),
    'fabForeground': fabForeground.toARGB32(),
    'btnRev': btnRev,
    'fontFamily': fontFamily,
    'fontSizeScale': fontSizeScale,
    'fontWeight': fontWeight,
    'cornerRadius': cornerRadius,
    'borderWidth': borderWidth,
    'iconSizeScale': iconSizeScale,
    'rowSpacing': rowSpacing,
    'roles': roles,
    'sectionOrder': sectionOrder,
    'sectionsOpen': sectionsOpen,
  };
}

/// Sentinel family name for the monospace option (same idea as the sister
/// repos' "@monospace").
const String skMonospaceFamily = 'monospace';

class SkUiProvider extends ChangeNotifier {
  static const _prefsKey = 'skUiKnobs';
  static const _recentColorsKey = 'skUiRecentColors';
  static const maxRecentColors = 10;

  SharedPreferences? _prefs;
  SkUiKnobs knobs = SkUiKnobs();
  List<Color> recentColors = [];
  List<String> externalFonts = []; // loaded family names (file basenames)

  Future<void> initialize() async {
    await _loadPersistedState();
    await loadExternalFonts();
    notifyListeners();
  }

  /// Loads the persisted state without registering any font with the engine.
  /// The headless 保存復元 export needs the knobs, the recent colors and the
  /// font *files* — never the rendered glyphs — so it skips [loadExternalFonts].
  Future<void> initializeWithoutFonts() => _loadPersistedState();

  Future<void> _loadPersistedState() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_prefsKey);
    if (raw != null) {
      try {
        knobs = SkUiKnobs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        knobs = SkUiKnobs();
      }
      // Migrate a pre-rev-1 save that still carries the old yellow-fill
      // action-button defaults to the new black-fill / yellow-text style.
      if (knobs.btnRev < 1) {
        if (knobs.fabBackground.toARGB32() == skYellow.toARGB32() &&
            knobs.fabForeground.toARGB32() == skBlack.toARGB32()) {
          knobs.fabBackground = skBlack;
          knobs.fabForeground = skYellow;
        }
        knobs.btnRev = skCurrentBtnRev;
        unawaited(_prefs!.setString(_prefsKey, jsonEncode(knobs.toJson())));
      }
    }
    recentColors = (_prefs!.getStringList(_recentColorsKey) ?? [])
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .map(Color.new)
        .toList();
    if (recentColors.isEmpty) {
      // Prefill the one-click boxes with the house palette. These are the
      // picker's presets — data, not the colour of anything.
      recentColors = [
        skYellow,
        skBlack,
        Color(SkBase.dim.defaultArgb),
        const Color(0xFFFFFFFF),
        const Color(0xFF808080),
        const Color(0xFFFF4040),
        const Color(0xFF40C040),
        const Color(0xFF4080FF),
      ];
    }
  }

  void save() {
    _prefs?.setString(_prefsKey, jsonEncode(knobs.toJson()));
    notifyListeners();
  }

  /// Live-update without persisting (used while a slider/dialog is open).
  void refresh() => notifyListeners();

  /// Back to the black-yellow defaults. Imported fonts stay available.
  void resetToDefaults() {
    knobs = SkUiKnobs();
    save();
  }

  /// Gives one item a colour of its own; null puts it back to its default.
  void setRole(SkRole role, Color? color, {bool persist = true}) {
    if (color == null) {
      knobs.roles.remove(role.name);
    } else {
      knobs.roles[role.name] = color.toARGB32();
    }
    persist ? save() : refresh();
  }

  void resetBase(SkBase b) {
    knobs.setBase(b, Color(b.defaultArgb));
    save();
  }

  /// Every colour back to its default: the foundation colours and every
  /// item's own. Fonts, shapes and the page's arrangement are left alone.
  void resetAllColours() {
    for (final b in SkBase.values) {
      knobs.setBase(b, Color(b.defaultArgb));
    }
    knobs.roles.clear();
    save();
  }

  void setSectionOpen(SkSection s, bool open) {
    knobs.sectionsOpen.remove(s.name);
    if (open) knobs.sectionsOpen.add(s.name);
    save();
  }

  void setSectionOrder(List<String> order) {
    knobs.sectionOrder = [...order];
    save();
  }

  void resetSectionOrder() {
    knobs.sectionOrder = [];
    save();
  }

  void pushRecentColor(Color c) {
    recentColors.removeWhere((e) => e.toARGB32() == c.toARGB32());
    recentColors.insert(0, c);
    if (recentColors.length > maxRecentColors) {
      recentColors = recentColors.sublist(0, maxRecentColors);
    }
    _prefs?.setStringList(
      _recentColorsKey,
      recentColors.map((e) => e.toARGB32().toString()).toList(),
    );
    notifyListeners();
  }

  // ---- External fonts ----

  Future<Directory> _fontsDir() async {
    // filesDir/fonts, mirroring the sister repos' FontHelper.getFontsDir().
    final files = await getApplicationSupportDirectory();
    final dir = Directory('${files.path}/fonts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String familyNameForFile(String path) {
    final base = path.split('/').last;
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }

  /// Loads every font file in sk_fonts/ as a family named after the file.
  Future<void> loadExternalFonts() async {
    final dir = await _fontsDir();
    final names = <String>[];
    await for (final f in dir.list()) {
      if (f is! File) continue;
      final lower = f.path.toLowerCase();
      if (!lower.endsWith('.ttf') && !lower.endsWith('.otf')) continue;
      final family = familyNameForFile(f.path);
      try {
        final loader = FontLoader(family)
          ..addFont(
            f
                .readAsBytes()
                .then((b) => ByteData.sublistView(Uint8List.fromList(b))),
          );
        await loader.load();
        names.add(family);
      } catch (_) {
        // Skip unparseable font files.
      }
    }
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    externalFonts = names;
  }

  /// Copies a picked font file into sk_fonts/ and loads it. Returns the
  /// family name, or null if the file was not a loadable font.
  Future<String?> importFont(String sourcePath) async {
    final dir = await _fontsDir();
    final base = sourcePath.split('/').last;
    final dest = File('${dir.path}/$base');
    await File(sourcePath).copy(dest.path);
    final family = familyNameForFile(dest.path);
    try {
      final loader = FontLoader(family)
        ..addFont(
          dest
              .readAsBytes()
              .then((b) => ByteData.sublistView(Uint8List.fromList(b))),
        );
      await loader.load();
    } catch (_) {
      await dest.delete();
      return null;
    }
    if (!externalFonts.contains(family)) {
      externalFonts.add(family);
      externalFonts.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    notifyListeners();
    return family;
  }

  /// Font files currently in the fonts dir (for the category export).
  Future<List<File>> fontFiles() async {
    final dir = await _fontsDir();
    final out = <File>[];
    await for (final f in dir.list()) {
      if (f is! File) continue;
      final lower = f.path.toLowerCase();
      if (lower.endsWith('.ttf') || lower.endsWith('.otf')) out.add(f);
    }
    return out;
  }

  /// Writes a font from an import (bytes + basename) and loads it. Returns
  /// false (and removes the file) if it is not a loadable font.
  Future<bool> importFontBytes(String name, List<int> bytes) async {
    final safe = name.split('/').last; // basename only — no path traversal
    final dir = await _fontsDir();
    final dest = File('${dir.path}/$safe');
    await dest.writeAsBytes(bytes);
    final family = familyNameForFile(dest.path);
    try {
      final loader = FontLoader(family)
        ..addFont(
          dest
              .readAsBytes()
              .then((b) => ByteData.sublistView(Uint8List.fromList(b))),
        );
      await loader.load();
    } catch (_) {
      await dest.delete();
      return false;
    }
    if (!externalFonts.contains(family)) {
      externalFonts.add(family);
      externalFonts.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    notifyListeners();
    return true;
  }

  /// Replaces knobs and/or recent colors from a category import and
  /// persists the result.
  void applyImported({SkUiKnobs? newKnobs, List<Color>? colors}) {
    if (newKnobs != null) knobs = newKnobs;
    if (colors != null && colors.isNotEmpty) {
      recentColors = colors.take(maxRecentColors).toList();
      _prefs?.setStringList(
        _recentColorsKey,
        recentColors.map((e) => e.toARGB32().toString()).toList(),
      );
    }
    save();
  }

  Future<void> deleteFont(String family) async {
    final dir = await _fontsDir();
    await for (final f in dir.list()) {
      if (f is File && familyNameForFile(f.path) == family) {
        await f.delete();
      }
    }
    externalFonts.remove(family);
    if (knobs.fontFamily == family) {
      knobs.fontFamily = '';
      save();
    } else {
      notifyListeners();
    }
  }
}
