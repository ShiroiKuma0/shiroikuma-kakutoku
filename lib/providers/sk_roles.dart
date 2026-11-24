// shiroikuma-kakutoku fork: the colour role table of the 白い熊 獲得 UI.
//
// Every colour the themed app draws with is a role in this file, and this is
// the only place a default is written. The two primaries are the defaults a
// fresh install shows; a handful of colours that carry meaning (the icon
// roles, the delete red, the warning) keep their settled values. Everything
// else derives from the twelve foundation colours, so changing one of those
// moves every role that was not given a colour of its own.
//
// The mixed way, in its Flutter form: upstream's screens keep reading
// Theme.of(context), and every theme and colour-scheme entry is fed from a
// role here (lib/sk_theme.dart); the fork's own screens read their roles
// directly through SkPalette.

import 'package:material_ui/material_ui.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';
import 'package:obtainium/sk_strings.dart';

/// The two primaries. Written once, here.
const int _yellow = 0xFFFFFF00;
const int _black = 0xFF000000;
const Color skYellow = Color(_yellow);
const Color skBlack = Color(_black);

/// The twelve foundation colours every other role defaults to. They are the
/// knob fields the first versions of the page shipped, so stored settings
/// keep their meaning.
enum SkBase {
  background(SkKind.ground, _black),
  surface(SkKind.ground, 0xFF0A0A00),
  accent(SkKind.mark, _yellow),
  onAccent(SkKind.ink, _black),
  text(SkKind.ink, _yellow),
  dim(SkKind.ink, 0xFFB8B800),
  border(SkKind.frame, _yellow),
  icon(SkKind.icon, _yellow),
  barGround(SkKind.ground, _black),
  barInk(SkKind.ink, _yellow),
  fabGround(SkKind.ground, _black),
  fabInk(SkKind.ink, _yellow);

  const SkBase(this.kind, this.defaultArgb);
  final SkKind kind;
  final int defaultArgb;

  /// The name shown on the UI page (tool/sk_strings).
  String get label => skTr('skBase_$name');
}

/// What kind of thing a role colours; picks the row's icon on the UI page.
enum SkKind { ground, frame, ink, icon, line, mark }

/// What a row does; its icon takes the colour of the role.
enum SkIconRole {
  /// Starts or connects something: install, update, download, refresh.
  call,

  /// Writes or marks: edit, add, rename.
  message,

  /// About a person, an account or an app identity.
  contact,

  /// Copies, shares, exports, imports.
  share,

  /// Views, opens a page or settings. The accent.
  view,

  /// Blocks, hides, stops, skips.
  block,

  /// Deletes or removes. Lends its colour to frame and label too.
  delete,
}

/// What kind of thing a section is; its icon — on the heading and on the
/// index chip alike — takes the colour of the kind. Seven colours, each with
/// one meaning; they are roles of their own, not the row icon roles.
enum SkSectionKind {
  /// What the app is, and its settings. The accent.
  base,

  /// What you operate.
  controls,

  /// Words, written and read.
  words,

  /// The frame and its boxes.
  frame,

  /// The app reaches out: asks, offers, hands over.
  reach,

  /// Resets and wipes.
  warning,

  /// A brief flash. One section at most.
  flash,
}

/// The top-level sections of the UI page, in their default order — arranged
/// so that no two neighbours share a colour. A role is set in the section of
/// the item it colours; a few sections hold other controls as well, or only
/// those. The titles are in tool/sk_strings.
enum SkSection {
  // Always first: every 白い熊 app opens its UI page with the app's language.
  language(SkSectionKind.words),
  eximport(SkSectionKind.reach),
  general(SkSectionKind.base),
  text(SkSectionKind.words),
  foundation(SkSectionKind.base),
  buttons(SkSectionKind.controls),
  dialogs(SkSectionKind.reach),
  switches(SkSectionKind.controls),
  menus(SkSectionKind.reach),
  marks(SkSectionKind.controls),
  lists(SkSectionKind.frame),
  fields(SkSectionKind.words),
  bars(SkSectionKind.frame),
  icons(SkSectionKind.base),
  chips(SkSectionKind.controls),
  shape(SkSectionKind.base),
  panels(SkSectionKind.frame),
  page(SkSectionKind.base),
  progress(SkSectionKind.controls),
  screens(SkSectionKind.base),
  messages(SkSectionKind.flash),
  picker(SkSectionKind.reach),
  maintenance(SkSectionKind.warning);

  const SkSection(this.kind);
  final SkSectionKind kind;

  String get title => skTr('skSection_$name');

  static SkSection? byName(String name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// A role's default: a foundation colour, a mix of two, or — only for colours
/// that carry meaning or are not yellow or black at all — a literal.
class SkDef {
  const SkDef(this.a, [this.b, this.t = 0]) : argb = null;
  const SkDef.lit(int this.argb) : a = SkBase.background, b = null, t = 0;

  final SkBase a;
  final SkBase? b;
  final double t;
  final int? argb;

  Color resolve(Color Function(SkBase) base) {
    if (argb != null) return Color(argb!);
    if (b == null) return base(a);
    return Color.lerp(base(a), base(b!), t)!;
  }
}

const _bg = SkDef(SkBase.background);
const _surface = SkDef(SkBase.surface);
const _accent = SkDef(SkBase.accent);
const _onAccent = SkDef(SkBase.onAccent);
const _text = SkDef(SkBase.text);
const _dim = SkDef(SkBase.dim);
const _border = SkDef(SkBase.border);
const _icon = SkDef(SkBase.icon);
const _barGround = SkDef(SkBase.barGround);
const _barInk = SkDef(SkBase.barInk);
const _fabGround = SkDef(SkBase.fabGround);
const _fabInk = SkDef(SkBase.fabInk);

/// The darker accent of dividers: 70 % of the way from the background to the
/// accent, opaque.
const _darkAccent = SkDef(SkBase.background, SkBase.accent, 0.7);

/// A switch that is off: 55 % of the way from the background to the text —
/// a darker yellow, never a faded one.
const _switchOff = SkDef(SkBase.background, SkBase.text, 0.55);

/// The dim gold of explanations and their left rule.
const _gold = SkDef.lit(0xFFC8C800);

const _ground = SkKind.ground;
const _frame = SkKind.frame;
const _ink = SkKind.ink;
const _glyph = SkKind.icon;
const _line = SkKind.line;
const _mark = SkKind.mark;

/// Every item's own colour role.
enum SkRole {
  // ---- Text ----
  textDisplay(SkSection.text, _ink, _text),
  textTitle(SkSection.text, _ink, _text),
  textBody(SkSection.text, _ink, _text),
  textLabel(SkSection.text, _ink, _text),
  textSmall(SkSection.text, _ink, _dim),
  textLink(SkSection.text, _ink, _accent),
  cursor(SkSection.text, _mark, _accent),
  selection(
    SkSection.text,
    _ground,
    SkDef(SkBase.background, SkBase.accent, 0.4),
  ),
  selectionHandle(SkSection.text, _mark, _accent),

  // ---- Buttons ----
  buttonMainFrame(SkSection.buttons, _frame, _border),
  buttonMainLabel(SkSection.buttons, _ink, _fabInk),
  buttonFrame(SkSection.buttons, _frame, _border),
  buttonLabel(SkSection.buttons, _ink, _text),
  buttonGround(SkSection.buttons, _ground, _fabGround),
  fabFrame(SkSection.buttons, _frame, _border),
  fabGround(SkSection.buttons, _ground, _fabGround),
  fabIcon(SkSection.buttons, _glyph, _fabInk),
  glyphButton(SkSection.buttons, _glyph, _icon),
  delete(SkSection.buttons, _mark, SkDef.lit(0xFFFF0000)),

  // ---- Dialogs ----
  dialogGround(SkSection.dialogs, _ground, _bg),
  dialogFrame(SkSection.dialogs, _frame, _border),
  dialogTitle(SkSection.dialogs, _ink, _text),
  dialogBody(SkSection.dialogs, _ink, _text),
  dialogButtonFrame(SkSection.dialogs, _frame, _border),
  dialogButtonLabel(SkSection.dialogs, _ink, _text),
  dialogScrim(SkSection.dialogs, _ground, SkDef.lit(0x8A000000)),

  // ---- Switches ----
  switchOnOutline(SkSection.switches, _frame, _accent),
  switchOnDot(SkSection.switches, _mark, _accent),
  switchOffOutline(SkSection.switches, _frame, _switchOff),
  switchOffDot(SkSection.switches, _mark, _switchOff),

  // ---- Check boxes and radio buttons ----
  checkOn(SkSection.marks, _mark, _accent),
  checkTick(SkSection.marks, _mark, _onAccent),
  checkOff(SkSection.marks, _frame, _border),
  radioOn(SkSection.marks, _mark, _accent),
  radioOff(SkSection.marks, _frame, _border),

  // ---- Menus ----
  menuGround(SkSection.menus, _ground, _bg),
  menuFrame(SkSection.menus, _frame, _border),
  menuLabel(SkSection.menus, _ink, _text),
  menuRowFrame(SkSection.menus, _frame, _border),
  menuDivider(SkSection.menus, _line, _darkAccent),
  menuCheck(SkSection.menus, _mark, _accent),

  // ---- Lists ----
  listTitle(SkSection.lists, _ink, _text),
  listSubtitle(SkSection.lists, _ink, _dim),
  listIcon(SkSection.lists, _glyph, _icon),
  listSelected(
    SkSection.lists,
    _ground,
    SkDef(SkBase.background, SkBase.accent, 0.2),
  ),
  divider(SkSection.lists, _line, _border),

  // ---- Text fields and pickers ----
  fieldText(SkSection.fields, _ink, _text),
  fieldLabel(SkSection.fields, _ink, _text),
  fieldHint(SkSection.fields, _ink, _dim),
  fieldFrame(SkSection.fields, _frame, _border),
  fieldFocusFrame(SkSection.fields, _frame, _accent),
  fieldGround(SkSection.fields, _ground, _bg),

  // ---- Bars and tabs ----
  appBarGround(SkSection.bars, _ground, _barGround),
  appBarTitle(SkSection.bars, _ink, _barInk),
  appBarIcon(SkSection.bars, _glyph, _barInk),
  navGround(SkSection.bars, _ground, _bg),
  navIndicator(SkSection.bars, _mark, _accent),
  navIconSelected(SkSection.bars, _glyph, _onAccent),
  navIcon(SkSection.bars, _glyph, _icon),
  navLabel(SkSection.bars, _ink, _text),
  searchGround(SkSection.bars, _ground, _surface),
  searchFrame(SkSection.bars, _frame, _border),
  searchText(SkSection.bars, _ink, _text),
  searchHint(SkSection.bars, _ink, _dim),
  tabSelected(SkSection.bars, _ink, _accent),
  tabUnselected(SkSection.bars, _ink, _dim),

  // ---- Cards and sheets ----
  cardGround(SkSection.panels, _ground, _surface),
  cardFrame(SkSection.panels, _frame, _border),
  sheetGround(SkSection.panels, _ground, _bg),
  sheetFrame(SkSection.panels, _frame, _border),
  sheetHandle(SkSection.panels, _mark, _dim),

  // ---- Chips and selectors ----
  chipGround(SkSection.chips, _ground, _surface),
  chipFrame(SkSection.chips, _frame, _border),
  chipLabel(SkSection.chips, _ink, _text),
  chipSelected(SkSection.chips, _ground, _accent),
  chipCheck(SkSection.chips, _mark, _onAccent),
  segGround(SkSection.chips, _ground, _bg),
  segFrame(SkSection.chips, _frame, _border),
  segLabel(SkSection.chips, _ink, _text),
  segSelectedGround(SkSection.chips, _ground, _accent),
  segSelectedLabel(SkSection.chips, _ink, _onAccent),

  // ---- Progress and sliders ----
  progress(SkSection.progress, _mark, _accent),
  progressTrack(SkSection.progress, _line, _surface),
  sliderActive(SkSection.progress, _line, _accent),
  sliderTrack(SkSection.progress, _line, _surface),
  sliderThumb(SkSection.progress, _mark, _accent),
  sliderValueGround(SkSection.progress, _ground, _accent),
  sliderValueText(SkSection.progress, _ink, _onAccent),

  // ---- Messages and tooltips ----
  snackGround(SkSection.messages, _ground, _surface),
  snackFrame(SkSection.messages, _frame, _border),
  snackText(SkSection.messages, _ink, _text),
  snackAction(SkSection.messages, _ink, _accent),
  tooltipGround(SkSection.messages, _ground, _surface),
  tooltipFrame(SkSection.messages, _frame, _border),
  tooltipText(SkSection.messages, _ink, _text),
  warning(SkSection.messages, _mark, SkDef.lit(0xFFFF5252)),

  // ---- Icons: coloured by what the row does ----
  iconCall(SkSection.icons, _glyph, SkDef.lit(0xFF00A550)),
  iconMessage(SkSection.icons, _glyph, SkDef.lit(0xFF0066FF)),
  iconContact(SkSection.icons, _glyph, SkDef.lit(0xFF00B0FF)),
  iconShare(SkSection.icons, _glyph, SkDef.lit(0xFFFF8000)),
  iconView(SkSection.icons, _glyph, _accent),
  iconBlock(SkSection.icons, _glyph, SkDef.lit(0xFFFF3D7F)),

  // ---- The UI page itself ----
  pageHeading(SkSection.page, _ink, _accent),
  pageSubheading(SkSection.page, _ink, _accent),
  pageLabel(SkSection.page, _ink, _text),
  pageValue(SkSection.page, _ink, _dim),
  pageNote(SkSection.page, _ink, _gold),
  pageRule(SkSection.page, _line, _gold),
  pageDivider(SkSection.page, _line, _darkAccent),
  pageChipFrame(SkSection.page, _frame, _border),
  pageChipLabel(SkSection.page, _ink, _text),
  pagePillFrame(SkSection.page, _frame, _border),
  pagePillLabel(SkSection.page, _ink, _text),
  swatchRing(SkSection.page, _frame, _border),

  // ---- Section icons: one colour per kind of section ----
  sectionBase(SkSection.page, _glyph, _accent),
  sectionControls(SkSection.page, _glyph, SkDef.lit(0xFF00A550)),
  sectionWords(SkSection.page, _glyph, SkDef.lit(0xFF00B0FF)),
  sectionFrame(SkSection.page, _glyph, SkDef.lit(0xFF0066FF)),
  sectionReach(SkSection.page, _glyph, SkDef.lit(0xFFFF8000)),
  sectionWarning(SkSection.page, _glyph, SkDef.lit(0xFFFF0000)),
  sectionFlash(SkSection.page, _glyph, SkDef.lit(0xFFFF3D7F)),

  // ---- The colour picker ----
  pickerRed(SkSection.picker, _line, SkDef.lit(0xFFFF5050)),
  pickerGreen(SkSection.picker, _line, SkDef.lit(0xFF50C050)),
  pickerBlue(SkSection.picker, _line, SkDef.lit(0xFF5080FF)),
  pickerAlpha(SkSection.picker, _line, _accent),
  checkerLight(SkSection.picker, _ground, SkDef.lit(0xFFBBBBBB)),
  checkerDark(SkSection.picker, _ground, SkDef.lit(0xFF666666)),

  // ---- Colour-scheme entries upstream's screens read directly ----
  schemePrimary(SkSection.screens, _mark, _accent),
  schemeOnPrimary(SkSection.screens, _ink, _onAccent),
  schemePrimaryContainer(SkSection.screens, _ground, _surface),
  schemeOnPrimaryContainer(SkSection.screens, _ink, _text),
  schemeSecondary(SkSection.screens, _mark, _accent),
  schemeOnSecondary(SkSection.screens, _ink, _onAccent),
  schemeSecondaryContainer(SkSection.screens, _ground, _surface),
  schemeOnSecondaryContainer(SkSection.screens, _ink, _text),
  schemeTertiary(SkSection.screens, _mark, _accent),
  schemeOnTertiary(SkSection.screens, _ink, _onAccent),
  schemeTertiaryContainer(SkSection.screens, _ground, _surface),
  schemeOnTertiaryContainer(SkSection.screens, _ink, _text),
  schemeError(SkSection.screens, _mark, SkDef.lit(0xFFFF5252)),
  schemeOnError(SkSection.screens, _ink, _bg),
  schemeErrorContainer(SkSection.screens, _ground, _surface),
  schemeOnErrorContainer(SkSection.screens, _ink, SkDef.lit(0xFFFF5252)),
  schemeSurface(SkSection.screens, _ground, _bg),
  schemeOnSurface(SkSection.screens, _ink, _text),
  schemeOnSurfaceVariant(SkSection.screens, _ink, _dim),
  schemeSurfaceLowest(SkSection.screens, _ground, _bg),
  schemeSurfaceLow(SkSection.screens, _ground, _surface),
  schemeSurfaceContainer(SkSection.screens, _ground, _surface),
  schemeSurfaceHigh(SkSection.screens, _ground, _surface),
  schemeSurfaceHighest(SkSection.screens, _ground, _surface),
  schemeOutline(SkSection.screens, _frame, _border),
  schemeOutlineVariant(
    SkSection.screens,
    _frame,
    SkDef(SkBase.background, SkBase.border, 0.5),
  ),
  schemeInverseSurface(SkSection.screens, _ground, _text),
  schemeOnInverseSurface(SkSection.screens, _ink, _bg),
  schemeInversePrimary(SkSection.screens, _mark, _bg),
  schemeSurfaceTint(SkSection.screens, _ground, _bg),
  schemeShadow(SkSection.screens, _ground, _bg),
  schemeScrim(SkSection.screens, _ground, _bg);

  const SkRole(this.section, this.kind, this.def);
  final SkSection section;
  final SkKind kind;
  final SkDef def;

  /// The name shown on the UI page (tool/sk_strings).
  String get label => skTr('skRole_$name');

  /// Whether this is one of the seven section icon colours, which have a
  /// group of their own on the UI page.
  bool get isSectionIcon => name.startsWith('section');

  static Iterable<SkRole> inSection(SkSection s) =>
      values.where((r) => r.section == s);
}

/// The resolved colours: a role's stored colour, or its default worked out
/// from the foundation colours. Carried by the theme, so every screen follows
/// the UI page without asking for it.
class SkPalette extends ThemeExtension<SkPalette> {
  SkPalette(this.knobs);

  /// Stands in while the 白い熊 獲得 UI is switched off: the fork's own
  /// screens then draw with the surrounding Material scheme.
  factory SkPalette.fromScheme(ColorScheme cs) => SkPalette(
    SkUiKnobs(
      background: cs.surface,
      surface: cs.surfaceContainerLow,
      textPrimary: cs.onSurface,
      textSecondary: cs.onSurfaceVariant,
      accent: cs.primary,
      onAccent: cs.onPrimary,
      border: cs.outline,
      icon: cs.onSurfaceVariant,
      appBarBackground: cs.surface,
      appBarForeground: cs.onSurface,
      fabBackground: cs.surface,
      fabForeground: cs.primary,
    ),
  );

  final SkUiKnobs knobs;

  Color base(SkBase b) => knobs.base(b);

  Color defaultOf(SkRole r) => r.def.resolve(base);

  Color operator [](SkRole r) {
    final stored = knobs.roles[r.name];
    return stored != null ? Color(stored) : defaultOf(r);
  }

  /// The colour of an icon that does [role].
  Color icon(SkIconRole role) =>
      this[switch (role) {
        SkIconRole.call => SkRole.iconCall,
        SkIconRole.message => SkRole.iconMessage,
        SkIconRole.contact => SkRole.iconContact,
        SkIconRole.share => SkRole.iconShare,
        SkIconRole.view => SkRole.iconView,
        SkIconRole.block => SkRole.iconBlock,
        SkIconRole.delete => SkRole.delete,
      }];

  /// The colour of the icon of [s], on its heading and its index chip.
  Color section(SkSection s) =>
      this[switch (s.kind) {
        SkSectionKind.base => SkRole.sectionBase,
        SkSectionKind.controls => SkRole.sectionControls,
        SkSectionKind.words => SkRole.sectionWords,
        SkSectionKind.frame => SkRole.sectionFrame,
        SkSectionKind.reach => SkRole.sectionReach,
        SkSectionKind.warning => SkRole.sectionWarning,
        SkSectionKind.flash => SkRole.sectionFlash,
      }];

  /// The palette of the 白い熊 獲得 UI, or null while it is switched off.
  static SkPalette? maybeOf(BuildContext context) =>
      Theme.of(context).extension<SkPalette>();

  static SkPalette of(BuildContext context) =>
      maybeOf(context) ?? SkPalette.fromScheme(Theme.of(context).colorScheme);

  @override
  SkPalette copyWith() => this;

  @override
  SkPalette lerp(ThemeExtension<SkPalette>? other, double t) =>
      other is SkPalette && t >= 0.5 ? other : this;
}
