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

/// The two primaries. Written once, here.
const int _yellow = 0xFFFFFF00;
const int _black = 0xFF000000;
const Color skYellow = Color(_yellow);
const Color skBlack = Color(_black);

/// The twelve foundation colours every other role defaults to. They are the
/// knob fields the first versions of the page shipped, so stored settings
/// keep their meaning.
enum SkBase {
  background('Background', SkKind.ground, _black),
  surface('Surface (cards, sheets)', SkKind.ground, 0xFF0A0A00),
  accent('Accent', SkKind.mark, _yellow),
  onAccent('On accent (ink on an accent ground)', SkKind.ink, _black),
  text('Text', SkKind.ink, _yellow),
  dim('Secondary text', SkKind.ink, 0xFFB8B800),
  border('Border', SkKind.frame, _yellow),
  icon('Icon', SkKind.icon, _yellow),
  barGround('Top bar ground', SkKind.ground, _black),
  barInk('Top bar text and icons', SkKind.ink, _yellow),
  fabGround('Action button ground', SkKind.ground, _black),
  fabInk('Action button text and icon', SkKind.ink, _yellow);

  const SkBase(this.label, this.kind, this.defaultArgb);
  final String label;
  final SkKind kind;
  final int defaultArgb;
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

/// The top-level sections of the UI page. A role is set in the section of the
/// item it colours; a few sections hold other controls as well, or only those.
enum SkSection {
  eximport('Export / Import', SkIconRole.share),
  general('General', SkIconRole.view),
  foundation('Foundation', SkIconRole.view),
  text('Text & font', SkIconRole.message),
  buttons('Buttons', SkIconRole.call),
  dialogs('Dialogs', SkIconRole.message),
  switches('Switches', SkIconRole.call),
  marks('Check boxes & radio buttons', SkIconRole.message),
  menus('Menus', SkIconRole.view),
  lists('Lists', SkIconRole.view),
  fields('Text fields & pickers', SkIconRole.message),
  bars('Bars & tabs', SkIconRole.view),
  panels('Cards & sheets', SkIconRole.view),
  chips('Chips & selectors', SkIconRole.contact),
  progress('Progress & sliders', SkIconRole.call),
  messages('Messages & tooltips', SkIconRole.message),
  icons('Icons', SkIconRole.contact),
  shape('Shape & density', SkIconRole.view),
  page('This page', SkIconRole.view),
  picker('Colour picker', SkIconRole.contact),
  screens('Shared screen colours', SkIconRole.view),
  maintenance('Maintenance', SkIconRole.block);

  const SkSection(this.title, this.role);
  final String title;
  final SkIconRole role;

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
  textDisplay(SkSection.text, 'Large headings', _ink, _text),
  textTitle(SkSection.text, 'Titles', _ink, _text),
  textBody(SkSection.text, 'Body text', _ink, _text),
  textLabel(SkSection.text, 'Labels', _ink, _text),
  textSmall(SkSection.text, 'Small print and captions', _ink, _dim),
  textLink(SkSection.text, 'Links', _ink, _accent),
  cursor(SkSection.text, 'Text cursor', _mark, _accent),
  selection(
    SkSection.text,
    'Text selection',
    _ground,
    SkDef(SkBase.background, SkBase.accent, 0.4),
  ),
  selectionHandle(SkSection.text, 'Selection handles', _mark, _accent),

  // ---- Buttons ----
  buttonMainFrame(SkSection.buttons, 'Main button frame', _frame, _border),
  buttonMainLabel(SkSection.buttons, 'Main button label', _ink, _fabInk),
  buttonFrame(SkSection.buttons, 'Button frame', _frame, _border),
  buttonLabel(SkSection.buttons, 'Button label', _ink, _text),
  buttonGround(SkSection.buttons, 'Button ground', _ground, _fabGround),
  fabFrame(SkSection.buttons, 'Floating button frame', _frame, _border),
  fabGround(SkSection.buttons, 'Floating button ground', _ground, _fabGround),
  fabIcon(SkSection.buttons, 'Floating button icon and label', _glyph, _fabInk),
  glyphButton(SkSection.buttons, 'Glyph buttons', _glyph, _icon),
  delete(
    SkSection.buttons,
    'Delete red (frame, label and icon of what deletes)',
    _mark,
    SkDef.lit(0xFFFF0000),
  ),

  // ---- Dialogs ----
  dialogGround(SkSection.dialogs, 'Dialog ground', _ground, _bg),
  dialogFrame(SkSection.dialogs, 'Dialog frame', _frame, _border),
  dialogTitle(SkSection.dialogs, 'Dialog title', _ink, _text),
  dialogBody(SkSection.dialogs, 'Dialog text', _ink, _text),
  dialogButtonFrame(SkSection.dialogs, 'Dialog button frame', _frame, _border),
  dialogButtonLabel(SkSection.dialogs, 'Dialog button label', _ink, _text),
  dialogScrim(
    SkSection.dialogs,
    'Shade behind a dialog',
    _ground,
    SkDef.lit(0x8A000000),
  ),

  // ---- Switches ----
  switchOnOutline(SkSection.switches, 'On: outline', _frame, _accent),
  switchOnDot(SkSection.switches, 'On: dot', _mark, _accent),
  switchOffOutline(SkSection.switches, 'Off: outline', _frame, _switchOff),
  switchOffDot(SkSection.switches, 'Off: dot', _mark, _switchOff),

  // ---- Check boxes and radio buttons ----
  checkOn(SkSection.marks, 'Ticked box', _mark, _accent),
  checkTick(SkSection.marks, 'Tick', _mark, _onAccent),
  checkOff(SkSection.marks, 'Empty box frame', _frame, _border),
  radioOn(SkSection.marks, 'Chosen radio button', _mark, _accent),
  radioOff(SkSection.marks, 'Radio button not chosen', _frame, _border),

  // ---- Menus ----
  menuGround(SkSection.menus, 'Menu ground', _ground, _bg),
  menuFrame(SkSection.menus, 'Menu frame', _frame, _border),
  menuLabel(SkSection.menus, 'Menu label', _ink, _text),
  menuRowFrame(SkSection.menus, 'Menu row frame', _frame, _border),
  menuDivider(SkSection.menus, 'Menu group divider', _line, _darkAccent),
  menuCheck(SkSection.menus, 'Mark of the chosen entry', _mark, _accent),

  // ---- Lists ----
  listTitle(SkSection.lists, 'Row title', _ink, _text),
  listSubtitle(SkSection.lists, 'Row second line', _ink, _dim),
  listIcon(SkSection.lists, 'Row icon', _glyph, _icon),
  listSelected(
    SkSection.lists,
    'Selected row ground',
    _ground,
    SkDef(SkBase.background, SkBase.accent, 0.2),
  ),
  divider(SkSection.lists, 'Divider', _line, _border),

  // ---- Text fields and pickers ----
  fieldText(SkSection.fields, 'Entered text', _ink, _text),
  fieldLabel(SkSection.fields, 'Field label', _ink, _text),
  fieldHint(SkSection.fields, 'Hint', _ink, _dim),
  fieldFrame(SkSection.fields, 'Field frame', _frame, _border),
  fieldFocusFrame(SkSection.fields, 'Field frame in focus', _frame, _accent),
  fieldGround(SkSection.fields, 'Field ground', _ground, _bg),

  // ---- Bars and tabs ----
  appBarGround(SkSection.bars, 'Top bar ground', _ground, _barGround),
  appBarTitle(SkSection.bars, 'Top bar title', _ink, _barInk),
  appBarIcon(SkSection.bars, 'Top bar icons', _glyph, _barInk),
  navGround(SkSection.bars, 'Navigation bar ground', _ground, _bg),
  navIndicator(SkSection.bars, 'Mark of the current page', _mark, _accent),
  navIconSelected(SkSection.bars, 'Icon of the current page', _glyph, _onAccent),
  navIcon(SkSection.bars, 'Icons of the other pages', _glyph, _icon),
  navLabel(SkSection.bars, 'Navigation labels', _ink, _text),
  searchGround(SkSection.bars, 'Search bar ground', _ground, _surface),
  searchFrame(SkSection.bars, 'Search bar frame', _frame, _border),
  searchText(SkSection.bars, 'Search text', _ink, _text),
  searchHint(SkSection.bars, 'Search hint', _ink, _dim),
  tabSelected(SkSection.bars, 'Current tab', _ink, _accent),
  tabUnselected(SkSection.bars, 'Other tabs', _ink, _dim),

  // ---- Cards and sheets ----
  cardGround(SkSection.panels, 'Card ground', _ground, _surface),
  cardFrame(SkSection.panels, 'Card frame', _frame, _border),
  sheetGround(SkSection.panels, 'Sheet ground', _ground, _bg),
  sheetFrame(SkSection.panels, 'Sheet frame', _frame, _border),
  sheetHandle(SkSection.panels, 'Sheet handle', _mark, _dim),

  // ---- Chips and selectors ----
  chipGround(SkSection.chips, 'Chip ground', _ground, _surface),
  chipFrame(SkSection.chips, 'Chip frame', _frame, _border),
  chipLabel(SkSection.chips, 'Chip label', _ink, _text),
  chipSelected(SkSection.chips, 'Chosen chip ground', _ground, _accent),
  chipCheck(SkSection.chips, 'Chosen chip tick', _mark, _onAccent),
  segGround(SkSection.chips, 'Selector ground', _ground, _bg),
  segFrame(SkSection.chips, 'Selector frame', _frame, _border),
  segLabel(SkSection.chips, 'Selector label', _ink, _text),
  segSelectedGround(SkSection.chips, 'Chosen segment ground', _ground, _accent),
  segSelectedLabel(SkSection.chips, 'Chosen segment label', _ink, _onAccent),

  // ---- Progress and sliders ----
  progress(SkSection.progress, 'Progress', _mark, _accent),
  progressTrack(SkSection.progress, 'Progress track', _line, _surface),
  sliderActive(SkSection.progress, 'Slider, filled part', _line, _accent),
  sliderTrack(SkSection.progress, 'Slider track', _line, _surface),
  sliderThumb(SkSection.progress, 'Slider thumb', _mark, _accent),
  sliderValueGround(SkSection.progress, 'Slider value bubble', _ground, _accent),
  sliderValueText(SkSection.progress, 'Slider value text', _ink, _onAccent),

  // ---- Messages and tooltips ----
  snackGround(SkSection.messages, 'Message ground', _ground, _surface),
  snackFrame(SkSection.messages, 'Message frame', _frame, _border),
  snackText(SkSection.messages, 'Message text', _ink, _text),
  snackAction(SkSection.messages, 'Message action', _ink, _accent),
  tooltipGround(SkSection.messages, 'Tooltip ground', _ground, _surface),
  tooltipFrame(SkSection.messages, 'Tooltip frame', _frame, _border),
  tooltipText(SkSection.messages, 'Tooltip text', _ink, _text),
  warning(
    SkSection.messages,
    'Warnings and errors',
    _mark,
    SkDef.lit(0xFFFF5252),
  ),

  // ---- Icons: coloured by what the row does ----
  iconCall(
    SkSection.icons,
    'Installs, updates, connects',
    _glyph,
    SkDef.lit(0xFF00FF00),
  ),
  iconMessage(
    SkSection.icons,
    'Writes, edits, adds',
    _glyph,
    SkDef.lit(0xFF4D94FF),
  ),
  iconContact(
    SkSection.icons,
    'About an app, a person or an account',
    _glyph,
    SkDef.lit(0xFF00FFFF),
  ),
  iconShare(
    SkSection.icons,
    'Copies, shares, exports, imports',
    _glyph,
    SkDef.lit(0xFFFF8000),
  ),
  iconView(SkSection.icons, 'Views, opens, settings', _glyph, _accent),
  iconBlock(
    SkSection.icons,
    'Blocks, hides, stops, skips',
    _glyph,
    SkDef.lit(0xFFFF00FF),
  ),

  // ---- The UI page itself ----
  pageHeading(SkSection.page, 'Section heading', _ink, _accent),
  pageSubheading(SkSection.page, 'Sub-heading', _ink, _accent),
  pageLabel(SkSection.page, 'Row label', _ink, _text),
  pageValue(SkSection.page, 'Row value', _ink, _dim),
  pageNote(SkSection.page, 'Explanation (dim gold)', _ink, _gold),
  pageRule(SkSection.page, 'Left rule of an explained row', _line, _gold),
  pageDivider(SkSection.page, 'Line between sections', _line, _darkAccent),
  pageChipFrame(SkSection.page, 'Index chip frame', _frame, _border),
  pageChipLabel(SkSection.page, 'Index chip label', _ink, _text),
  pagePillFrame(SkSection.page, 'Action pill frame', _frame, _border),
  pagePillLabel(SkSection.page, 'Action pill label', _ink, _text),
  swatchRing(SkSection.page, 'Ring round a colour swatch', _frame, _border),

  // ---- The colour picker ----
  pickerRed(SkSection.picker, 'Red channel', _line, SkDef.lit(0xFFFF5050)),
  pickerGreen(SkSection.picker, 'Green channel', _line, SkDef.lit(0xFF50C050)),
  pickerBlue(SkSection.picker, 'Blue channel', _line, SkDef.lit(0xFF5080FF)),
  pickerAlpha(SkSection.picker, 'Opacity channel', _line, _accent),
  checkerLight(
    SkSection.picker,
    'See-through pattern, light square',
    _ground,
    SkDef.lit(0xFFBBBBBB),
  ),
  checkerDark(
    SkSection.picker,
    'See-through pattern, dark square',
    _ground,
    SkDef.lit(0xFF666666),
  ),

  // ---- Colour-scheme entries upstream's screens read directly ----
  schemePrimary(SkSection.screens, 'Primary', _mark, _accent),
  schemeOnPrimary(SkSection.screens, 'On primary', _ink, _onAccent),
  schemePrimaryContainer(SkSection.screens, 'Primary container', _ground, _surface),
  schemeOnPrimaryContainer(SkSection.screens, 'On primary container', _ink, _text),
  schemeSecondary(SkSection.screens, 'Secondary', _mark, _accent),
  schemeOnSecondary(SkSection.screens, 'On secondary', _ink, _onAccent),
  schemeSecondaryContainer(SkSection.screens, 'Secondary container', _ground, _surface),
  schemeOnSecondaryContainer(SkSection.screens, 'On secondary container', _ink, _text),
  schemeTertiary(SkSection.screens, 'Tertiary', _mark, _accent),
  schemeOnTertiary(SkSection.screens, 'On tertiary', _ink, _onAccent),
  schemeTertiaryContainer(SkSection.screens, 'Tertiary container', _ground, _surface),
  schemeOnTertiaryContainer(SkSection.screens, 'On tertiary container', _ink, _text),
  schemeError(SkSection.screens, 'Error', _mark, SkDef.lit(0xFFFF5252)),
  schemeOnError(SkSection.screens, 'On error', _ink, _bg),
  schemeErrorContainer(SkSection.screens, 'Error container', _ground, _surface),
  schemeOnErrorContainer(
    SkSection.screens,
    'On error container',
    _ink,
    SkDef.lit(0xFFFF5252),
  ),
  schemeSurface(SkSection.screens, 'Screen ground', _ground, _bg),
  schemeOnSurface(SkSection.screens, 'Ink on the screen ground', _ink, _text),
  schemeOnSurfaceVariant(SkSection.screens, 'Quieter ink', _ink, _dim),
  schemeSurfaceLowest(SkSection.screens, 'Lowest container', _ground, _bg),
  schemeSurfaceLow(SkSection.screens, 'Low container', _ground, _surface),
  schemeSurfaceContainer(SkSection.screens, 'Container', _ground, _surface),
  schemeSurfaceHigh(SkSection.screens, 'High container', _ground, _surface),
  schemeSurfaceHighest(SkSection.screens, 'Highest container', _ground, _surface),
  schemeOutline(SkSection.screens, 'Outline', _frame, _border),
  schemeOutlineVariant(
    SkSection.screens,
    'Quieter outline',
    _frame,
    SkDef(SkBase.background, SkBase.border, 0.5),
  ),
  schemeInverseSurface(SkSection.screens, 'Inverse ground', _ground, _text),
  schemeOnInverseSurface(SkSection.screens, 'Ink on the inverse ground', _ink, _bg),
  schemeInversePrimary(SkSection.screens, 'Inverse primary', _mark, _bg),
  schemeSurfaceTint(SkSection.screens, 'Surface tint', _ground, _bg),
  schemeShadow(SkSection.screens, 'Shadow', _ground, _bg),
  schemeScrim(SkSection.screens, 'Scrim', _ground, _bg);

  const SkRole(this.section, this.label, this.kind, this.def);
  final SkSection section;
  final String label;
  final SkKind kind;
  final SkDef def;

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
  Color icon(SkIconRole role) => this[switch (role) {
    SkIconRole.call => SkRole.iconCall,
    SkIconRole.message => SkRole.iconMessage,
    SkIconRole.contact => SkRole.iconContact,
    SkIconRole.share => SkRole.iconShare,
    SkIconRole.view => SkRole.iconView,
    SkIconRole.block => SkRole.iconBlock,
    SkIconRole.delete => SkRole.delete,
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
