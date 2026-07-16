// shiroikuma-kakutoku fork: the 白い熊 獲得 UI theming layer (granular
// black-yellow theming in the style of the sister shiroikuma forks).
//
// All knobs persist as a single JSON blob in SharedPreferences; recently
// picked colors persist as a shared list so every color picker offers them
// as one-click presets. External fonts are copied into
// <app documents>/sk_fonts/ and loaded as font families named after the file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The house palette (same yellow as the launcher icon trace — NOT material
/// yellow #FFEB3B).
const Color skYellow = Color(0xFFFFFF00);
const Color skBlack = Color(0xFF000000);
const Color skDimYellow = Color(0xFFB8B800);
const Color skDarkSurface = Color(0xFF0A0A00);

/// Current defaults revision. Bump when a shipped default changes and old
/// saved states should be migrated (see [SkUiProvider.initialize]).
const int skCurrentBtnRev = 1;

/// One themable knob set. Every field has a black-yellow default.
class SkUiKnobs {
  // Master switch.
  bool enabled;

  // Colors — background.
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

  SkUiKnobs({
    this.enabled = true,
    this.background = skBlack,
    this.surface = skDarkSurface,
    this.textPrimary = skYellow,
    this.textSecondary = skDimYellow,
    this.accent = skYellow,
    this.onAccent = skBlack,
    this.border = skYellow,
    this.icon = skYellow,
    this.appBarBackground = skBlack,
    this.appBarForeground = skYellow,
    // Action buttons: black fill, yellow text/icon, yellow border (the
    // border comes from `border` + `borderWidth`).
    this.fabBackground = skBlack,
    this.fabForeground = skYellow,
    this.btnRev = skCurrentBtnRev,
    this.fontFamily = '',
    this.fontSizeScale = 1.0,
    this.fontWeight = 400,
    this.cornerRadius = 8,
    this.borderWidth = 1,
    this.iconSizeScale = 1.0,
    this.rowSpacing = 4,
  });

  factory SkUiKnobs.fromJson(Map<String, dynamic> m) {
    final d = SkUiKnobs();
    Color c(String k, Color def) =>
        m[k] is int ? Color(m[k] as int) : def;
    double n(String k, double def) =>
        m[k] is num ? (m[k] as num).toDouble() : def;
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
      // Prefill the one-click boxes with the house palette.
      recentColors = const [
        skYellow,
        skBlack,
        skDimYellow,
        Color(0xFFFFFFFF),
        Color(0xFF808080),
        Color(0xFFFF4040),
        Color(0xFF40C040),
        Color(0xFF4080FF),
      ];
    }
    await loadExternalFonts();
    notifyListeners();
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
