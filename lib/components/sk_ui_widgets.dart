// shiroikuma-kakutoku fork: building blocks of the 白い熊 獲得 UI page, in the
// house style every 白い熊 app shares — folding section headings, the
// draggable chip index, action rows drawn as outlined pills that hug their
// label, plain control rows, explained rows (bold label, dim-gold note, a
// thin left rule), an icon on every row sized by its label, a swatch row for
// every colour role, the RGBA colour picker and the font picker.
//
// No colour is written here; every one is read from its role.

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:file_picker/file_picker.dart';
import 'package:obtainium/sk_strings.dart';
import 'package:obtainium/components/sk_pills.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';
import 'package:obtainium/sk_material.dart';
import 'package:obtainium/sk_theme.dart';
import 'package:provider/provider.dart';

/// The live text sample used by font/text previews (same string family as
/// the sister repos: Latin + 白い熊 kanji + Czech diacritics).
const String skFontSample = 'AaIiMmOoQqWw 012 白い熊相撲道 áčďéěíňóřšťúůýž';

/// Left edge of the page's content.
const double skPageInset = 16;

/// One further step of indent, for rows under a sub-heading.
const double skIndentStep = 16;

double skIndent(int level) => skPageInset + skIndentStep * (level - 1);

/// A row's icon is as tall as its label's text line and never under 18 dp —
/// the font size is settable, so a fixed icon would be right for one size
/// only.
double skRowIconSize(TextStyle? label) =>
    math.max(18, 1.25 * (label?.fontSize ?? 14));

/// Gap between a row's icon and its label.
const double _iconGap = 10;

/// The icon of each section, shown on its heading and its index chip.
IconData skSectionIcon(SkSection s) => switch (s) {
  SkSection.language => Icons.language,
  SkSection.eximport => Icons.import_export,
  SkSection.general => Icons.toggle_on_outlined,
  SkSection.foundation => Icons.palette_outlined,
  SkSection.text => Icons.text_fields,
  SkSection.buttons => Icons.smart_button_outlined,
  SkSection.dialogs => Icons.chat_bubble_outline,
  SkSection.switches => Icons.toggle_on_outlined,
  SkSection.marks => Icons.check_box_outlined,
  SkSection.menus => Icons.menu,
  SkSection.lists => Icons.list,
  SkSection.fields => Icons.edit_outlined,
  SkSection.bars => Icons.web_asset,
  SkSection.panels => Icons.dashboard_outlined,
  SkSection.chips => Icons.label_outline,
  SkSection.progress => Icons.linear_scale,
  SkSection.messages => Icons.notifications_outlined,
  SkSection.icons => Icons.interests_outlined,
  SkSection.shape => Icons.rounded_corner,
  SkSection.page => Icons.tune,
  SkSection.picker => Icons.colorize,
  SkSection.screens => Icons.layers_outlined,
  SkSection.maintenance => Icons.build_outlined,
};

/// The icon of a colour row, by the kind of thing the role colours.
IconData skKindIcon(SkKind k) => switch (k) {
  SkKind.ground => Icons.format_color_fill,
  SkKind.frame => Icons.crop_square,
  SkKind.ink => Icons.title,
  SkKind.icon => Icons.interests_outlined,
  SkKind.line => Icons.horizontal_rule,
  SkKind.mark => Icons.radio_button_checked,
};

TextStyle? _labelStyle(BuildContext context, {bool bold = false}) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: SkPalette.of(context)[SkRole.pageLabel],
      fontWeight: bold ? FontWeight.bold : null,
    );

TextStyle? _noteStyle(BuildContext context) {
  final body = Theme.of(context).textTheme.bodyMedium;
  return body?.copyWith(
    color: SkPalette.of(context)[SkRole.pageNote],
    // 13 sp against a 14 sp label, whatever the page's font size.
    fontSize: (body.fontSize ?? 14) * 13 / 14,
    fontWeight: FontWeight.normal,
    height: 1.2,
  );
}

/// The frame an item sits in: a thin dim-gold rule down its whole left edge
/// when it carries an explanation, the same inset without the rule when it
/// does not, so every row's icon stands in one column.
class _Item extends StatelessWidget {
  const _Item({required this.level, required this.ruled, required this.child});
  final int level;
  final bool ruled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = SkPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(skIndent(level), 2, 14, 2),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: ruled
                  ? p[SkRole.pageRule]
                  : p[SkRole.pageRule].withValues(alpha: 0),
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 10),
        child: child,
      ),
    );
  }
}

/// A section heading. A tap folds or unfolds the section's rows; the thin
/// line above it stays either way. › when folded, ⌄ when open.
class SkSectionHeader extends StatelessWidget {
  const SkSectionHeader({
    super.key,
    required this.section,
    required this.open,
    required this.onTap,
  });
  final SkSection section;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = SkPalette.of(context);
    final ink = p[SkRole.pageHeading];
    final style = theme.textTheme.titleLarge?.copyWith(
      fontSize: 20 * (theme.textTheme.bodyMedium?.fontSize ?? 14) / 14,
      fontWeight: FontWeight.bold,
      color: ink,
    );
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: p[SkRole.pageDivider]),
          Padding(
            padding: EdgeInsets.fromLTRB(skPageInset, 6, 12, open ? 2 : 6),
            child: Row(
              children: [
                Icon(
                  skSectionIcon(section),
                  size: skRowIconSize(style),
                  color: p.section(section),
                ),
                const SizedBox(width: _iconGap),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(section.title, maxLines: 1, style: style),
                          const SizedBox(height: 2),
                          Container(height: 2.5, color: ink),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  open ? Icons.expand_more : Icons.chevron_right,
                  size: skRowIconSize(style),
                  color: ink,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A bold sub-heading with an underline exactly as wide as its text; the
/// rows under it are indented one further step.
class SkSubgroupHeading extends StatelessWidget {
  const SkSubgroupHeading(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = SkPalette.of(context)[SkRole.pageSubheading];
    return Padding(
      padding: const EdgeInsets.fromLTRB(skPageInset + 12, 8, 16, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                maxLines: 1,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize:
                      17 * (theme.textTheme.bodyMedium?.fontSize ?? 14) / 14,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 2),
              Container(height: 1.5, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// A loose note that belongs to no single row: dim gold, no rule.
class SkNote extends StatelessWidget {
  const SkNote(this.text, {super.key, this.level = 1, this.color});
  final String text;
  final int level;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(skIndent(level) + 12, 2, 14, 2),
    child: Text(text, style: _noteStyle(context)?.copyWith(color: color)),
  );
}

/// A plain control row: an icon coloured by what the row does, the label,
/// and the row's own control at the right. With a [note] it is an explained
/// row — bold label, the note in dim gold beneath, a thin rule down its left
/// edge. A [tag] is a short machine identifier, shown in bold monospace; it
/// is given only where the item really has one.
class SkRow extends StatelessWidget {
  const SkRow({
    super.key,
    required this.label,
    required this.icon,
    this.role,
    this.iconColor,
    this.level = 1,
    this.trailing,
    this.note,
    this.tag,
    this.below,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final SkIconRole? role;
  final Color? iconColor;
  final int level;
  final Widget? trailing;
  final String? note;
  final String? tag;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = SkPalette.of(context);
    final explained = note != null;
    final labelStyle = _labelStyle(context, bold: explained);
    final size = skRowIconSize(labelStyle);
    final row = _Item(
      level: level,
      ruled: explained,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: size,
                color: iconColor ?? p.icon(role ?? skIconRoleFor(icon)),
              ),
              const SizedBox(width: _iconGap),
              Expanded(child: Text(label, style: labelStyle)),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          if (tag != null || note != null || below != null)
            Padding(
              padding: EdgeInsets.only(left: size + _iconGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag != null)
                    Text(
                      tag!,
                      style: labelStyle?.copyWith(
                        fontFamily: skMonospaceFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (note != null) Text(note!, style: _noteStyle(context)),
                  ?below,
                ],
              ),
            ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// A switch row: tap anywhere on it to toggle. The switch is the outlined
/// one.
class SkSwitchRow extends StatelessWidget {
  const SkSwitchRow({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.role,
    this.note,
    this.below,
    this.level = 1,
  });
  final String label;
  final IconData icon;
  final SkIconRole? role;
  final String? note;
  final Widget? below;
  final bool value;
  final ValueChanged<bool> onChanged;
  final int level;

  @override
  Widget build(BuildContext context) => SkRow(
    label: label,
    icon: icon,
    role: role,
    note: note,
    below: below,
    level: level,
    onTap: () => onChanged(!value),
    trailing: IgnorePointer(
      child: SkSwitch(value: value, onChanged: (_) {}),
    ),
  );
}

/// A row that does something when tapped — opens a screen, a picker or a
/// panel, or runs an action — drawn as an outlined pill that hugs its label,
/// so it never reads as a heading, a note or a banner. The icon sits inside
/// the pill before the label. [main], the one thing its section is for, has
/// the 3 dp frame and a bold label; [opens] adds the › of a row that leads
/// somewhere; [destructive] lends the delete red to frame and label. The
/// explanation sits beneath the pill, aligned with the label, and is not
/// part of the touch target.
class SkActionRow extends StatelessWidget {
  const SkActionRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.role,
    this.note,
    this.noteColor,
    this.below,
    this.main = false,
    this.opens = false,
    this.destructive = false,
    this.level = 1,
  });
  final String label;
  final IconData icon;
  final SkIconRole? role;
  final String? note;
  final Color? noteColor;
  final Widget? below;
  final bool main;
  final bool opens;
  final bool destructive;
  final int level;
  final VoidCallback? onTap;

  static const double _pillInset = 14;

  @override
  Widget build(BuildContext context) {
    final p = SkPalette.of(context);
    final enabled = onTap != null;
    Color dimmed(Color c) =>
        enabled ? c : c.withValues(alpha: c.a * skDisabledAlpha);
    final ink = dimmed(
      destructive ? p[SkRole.delete] : p[SkRole.pagePillLabel],
    );
    final frame = dimmed(
      destructive ? p[SkRole.delete] : p[SkRole.pagePillFrame],
    );
    final labelStyle = _labelStyle(context, bold: main)?.copyWith(color: ink);
    final size = skRowIconSize(labelStyle);
    final iconRole = destructive ? SkIconRole.delete : role;
    return _Item(
      level: level,
      ruled: note != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              type: MaterialType.transparency,
              shape: StadiumBorder(
                side: BorderSide(
                  color: frame,
                  width: main ? skPillMainWidth : skPillRegularWidth,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                customBorder: const StadiumBorder(),
                splashColor: ink.withValues(alpha: 0.3),
                highlightColor: ink.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _pillInset,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: size,
                        color: dimmed(p.icon(iconRole ?? skIconRoleFor(icon))),
                      ),
                      const SizedBox(width: _iconGap),
                      Flexible(child: Text(label, style: labelStyle)),
                      if (opens) ...[
                        const SizedBox(width: 10),
                        Text(
                          '›',
                          style: labelStyle?.copyWith(
                            fontSize: (labelStyle.fontSize ?? 14) * 1.4,
                            height: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (note != null || below != null)
              Padding(
                padding: EdgeInsets.only(
                  left: _pillInset + size + _iconGap,
                  top: 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note != null)
                      Text(
                        note!,
                        style: _noteStyle(context)?.copyWith(color: noteColor),
                      ),
                    ?below,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A slider row with the current value and an optional inline preview below.
/// Live: [onChanged] fires while dragging, [onChangeEnd] persists.
class SkSliderRow extends StatelessWidget {
  const SkSliderRow({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.role,
    this.onChangeEnd,
    this.level = 1,
    this.divisions,
    this.valueText,
    this.preview,
  });
  final String label;
  final IconData icon;
  final SkIconRole? role;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final int level;
  final String? valueText;
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    final p = SkPalette.of(context);
    return SkRow(
      label: label,
      icon: icon,
      role: role,
      level: level,
      trailing: Text(
        valueText ?? value.toStringAsFixed(0),
        style: _noteStyle(context)?.copyWith(color: p[SkRole.pageValue]),
      ),
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          if (preview != null)
            Padding(padding: const EdgeInsets.only(bottom: 2), child: preview!),
        ],
      ),
    );
  }
}

/// The round colour swatch (over a checkerboard so alpha is visible), ringed
/// in its own role.
class SkColorSwatchDot extends StatelessWidget {
  const SkColorSwatchDot(this.color, {super.key, this.size = 28});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = SkPalette.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CustomPaint(
          painter: _CheckerPainter(
            p[SkRole.checkerLight],
            p[SkRole.checkerDark],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: p[SkRole.swatchRing]),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  _CheckerPainter(this.lightColor, this.darkColor);
  final Color lightColor;
  final Color darkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = lightColor;
    final dark = Paint()..color = darkColor;
    const cell = 5.0;
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final even = ((x / cell).floor() + (y / cell).floor()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), even ? light : dark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerPainter old) =>
      old.lightColor != lightColor || old.darkColor != darkColor;
}

/// A colour row: icon, label, and the swatch at the right; a tap opens the
/// RGBA picker. [onChanged] fires live while the picker is open, and Cancel
/// puts the old colour back. When the colour is not its default, a ↺ before
/// the swatch resets it.
class SkColorRow extends StatelessWidget {
  const SkColorRow({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onChanged,
    this.iconColor,
    this.onReset,
    this.level = 1,
  });
  final String label;
  final IconData icon;
  final Color? iconColor;
  final Color color;
  final ValueChanged<Color> onChanged;

  /// Non-null while the colour differs from its default.
  final VoidCallback? onReset;
  final int level;

  @override
  Widget build(BuildContext context) {
    final p = SkPalette.of(context);
    return SkRow(
      label: label,
      icon: icon,
      iconColor: iconColor,
      level: level,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReset != null)
            InkResponse(
              onTap: onReset,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Tooltip(
                  message: SkStr.backToDefault.t,
                  child: Icon(
                    Icons.restart_alt,
                    size: 20,
                    color: p.icon(SkIconRole.delete),
                  ),
                ),
              ),
            ),
          SkColorSwatchDot(color),
        ],
      ),
      onTap: () async {
        final sk = context.read<SkUiProvider>();
        final picked = await showSkColorPicker(
          context,
          title: label,
          initial: color,
          onLive: onChanged,
        );
        if (picked != null) {
          onChanged(picked);
          sk.pushRecentColor(picked);
        } else {
          onChanged(color); // cancel → restore
        }
      },
    );
  }
}

/// The swatch rows of every colour role that belongs to [section], each with
/// its own reset.
class SkRoleRows extends StatelessWidget {
  const SkRoleRows(
    this.section, {
    super.key,
    this.level = 1,
    this.sectionIcons,
  });
  final SkSection section;
  final int level;

  /// Null: every role of the section. Otherwise only the seven section icon
  /// colours (true) or only the rest (false).
  final bool? sectionIcons;

  @override
  Widget build(BuildContext context) {
    final sk = context.watch<SkUiProvider>();
    final p = SkPalette(sk.knobs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final role in SkRole.inSection(section))
          if (sectionIcons == null || role.isSectionIcon == sectionIcons)
            _RoleRow(sk: sk, palette: p, role: role, level: level),
      ],
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.sk,
    required this.palette,
    required this.role,
    required this.level,
  });
  final SkUiProvider sk;
  final SkPalette palette;
  final SkRole role;
  final int level;

  @override
  Widget build(BuildContext context) {
    // What the role held when the picker opened, so that Cancel puts back
    // "no colour of its own" rather than pinning the default.
    final hadOwn = sk.knobs.roles.containsKey(role.name);
    final before = palette[role];
    return SkColorRow(
      label: role.label,
      icon: skKindIcon(role.kind),
      iconColor: palette.section(role.section),
      color: before,
      level: level,
      onChanged: (c) => sk.setRole(
        role,
        !hadOwn && c.toARGB32() == before.toARGB32() ? null : c,
      ),
      onReset: hadOwn ? () => sk.setRole(role, null) : null,
    );
  }
}

/// The chip index at the top of the UI page: one small outlined chip per
/// section. A tap jumps to the section; a long-press lifts the chip into a
/// drag, the chips reorder live under the finger, and the sections follow on
/// drop.
class SkSectionIndex extends StatefulWidget {
  const SkSectionIndex({
    super.key,
    required this.order,
    required this.onJump,
    required this.onReordered,
  });

  final List<SkSection> order;
  final ValueChanged<SkSection> onJump;
  final ValueChanged<List<SkSection>> onReordered;

  @override
  State<SkSectionIndex> createState() => _SkSectionIndexState();
}

class _SkSectionIndexState extends State<SkSectionIndex> {
  /// The order while a chip is in the air; null otherwise.
  List<SkSection>? _live;
  SkSection? _dragging;

  /// The chip the dragged one last changed places with. The finger is still
  /// over it right after the move, and must leave it before it can trade
  /// places with it again — otherwise the two would flap.
  SkSection? _lastTarget;

  List<SkSection> get _order => _live ?? widget.order;

  void _moveTo(SkSection target) {
    final dragged = _dragging;
    final live = _live;
    if (dragged == null || live == null) return;
    if (dragged == target) {
      _lastTarget = null;
      return;
    }
    if (target == _lastTarget) return;
    _lastTarget = target;
    final to = live.indexOf(target);
    setState(() {
      live
        ..remove(dragged)
        ..insert(to, dragged);
    });
  }

  void _drop() {
    final live = _live;
    setState(() {
      _live = null;
      _dragging = null;
      _lastTarget = null;
    });
    if (live != null && !_same(live, widget.order)) widget.onReordered(live);
  }

  static bool _same(List<SkSection> a, List<SkSection> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _chip(SkSection s, {bool lifted = false, bool ghost = false}) {
    final theme = Theme.of(context);
    final p = SkPalette.of(context);
    final alpha = ghost ? skDisabledAlpha : 1.0;
    final ink = p[SkRole.pageChipLabel].withValues(alpha: alpha);
    final label = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 12,
      height: 1.1,
      color: ink,
      fontWeight: FontWeight.normal,
      decoration: TextDecoration.none,
    );
    return Material(
      type: lifted ? MaterialType.canvas : MaterialType.transparency,
      color: lifted ? theme.scaffoldBackgroundColor : null,
      elevation: lifted ? 6 : 0,
      shape: StadiumBorder(
        side: BorderSide(
          color: p[SkRole.pageChipFrame].withValues(alpha: alpha),
          width: lifted ? skPillMainWidth : skPillRegularWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: lifted || ghost ? null : () => widget.onJump(s),
        customBorder: const StadiumBorder(),
        splashColor: ink.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The section's icon in the section's colour — the same
              // drawable and colour as on its heading — sized by the label.
              Icon(
                skSectionIcon(s),
                size: 1.25 * (label?.fontSize ?? 12),
                color: p.section(s).withValues(alpha: alpha),
              ),
              const SizedBox(width: 5),
              Text(s.title, style: label),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(skPageInset, 6, skPageInset, 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in _order)
            DragTarget<SkSection>(
              key: ValueKey<SkSection>(s),
              onWillAcceptWithDetails: (details) {
                _moveTo(s);
                return true;
              },
              onMove: (details) => _moveTo(s),
              onLeave: (data) {
                if (_lastTarget == s) _lastTarget = null;
              },
              builder: (context, candidates, rejected) =>
                  LongPressDraggable<SkSection>(
                    data: s,
                    delay: const Duration(milliseconds: 350),
                    feedback: _chip(s, lifted: true),
                    childWhenDragging: _chip(s, ghost: true),
                    onDragStarted: () => setState(() {
                      _live = [...widget.order];
                      _dragging = s;
                    }),
                    onDragEnd: (details) => _drop(),
                    child: _chip(s),
                  ),
            ),
        ],
      ),
    );
  }
}

/// The RGBA picker dialog: one-click recent-color boxes on top, then the
/// old→new preview, then the four R/G/B/A sliders (0-255 each).
Future<Color?> showSkColorPicker(
  BuildContext context, {
  required String title,
  required Color initial,
  ValueChanged<Color>? onLive,
}) {
  return showDialog<Color>(
    context: context,
    builder: (ctx) =>
        _SkColorPickerDialog(title: title, initial: initial, onLive: onLive),
  );
}

class _SkColorPickerDialog extends StatefulWidget {
  const _SkColorPickerDialog({
    required this.title,
    required this.initial,
    this.onLive,
  });
  final String title;
  final Color initial;
  final ValueChanged<Color>? onLive;

  @override
  State<_SkColorPickerDialog> createState() => _SkColorPickerDialogState();
}

class _SkColorPickerDialogState extends State<_SkColorPickerDialog> {
  late int r, g, b, a;

  Color get current => Color.fromARGB(a, r, g, b);

  @override
  void initState() {
    super.initState();
    _setFrom(widget.initial);
  }

  void _setFrom(Color c) {
    final v = c.toARGB32();
    a = (v >> 24) & 0xFF;
    r = (v >> 16) & 0xFF;
    g = (v >> 8) & 0xFF;
    b = v & 0xFF;
  }

  void _update(void Function() change) {
    setState(change);
    widget.onLive?.call(current);
  }

  Widget _channelSlider(
    String name,
    int value,
    Color trackColor,
    void Function(int) set,
  ) {
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: SkPalette.of(context)[SkRole.dialogBody],
    );
    return Row(
      children: [
        SizedBox(width: 16, child: Text(name, style: small)),
        Expanded(
          child: SizedBox(
            height: 26,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: trackColor,
                thumbColor: trackColor,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 255,
                onChanged: (v) => _update(() => set(v.round())),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text('$value', textAlign: TextAlign.right, style: small),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final recents = context.watch<SkUiProvider>().recentColors;
    final p = SkPalette.of(context);
    final small = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: p[SkRole.dialogBody]);
    final hex = current
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (recents.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in recents)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _update(() => _setFrom(c)),
                      child: SkColorSwatchDot(c, size: 30),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _swatchBox(widget.initial),
                      const SizedBox(height: 2),
                      Text(SkStr.oldColour.t, style: small),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: p[SkRole.dialogBody],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      _swatchBox(current),
                      const SizedBox(height: 2),
                      Text('#$hex', style: small),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _channelSlider('R', r, p[SkRole.pickerRed], (v) => r = v),
            _channelSlider('G', g, p[SkRole.pickerGreen], (v) => g = v),
            _channelSlider('B', b, p[SkRole.pickerBlue], (v) => b = v),
            _channelSlider('A', a, p[SkRole.pickerAlpha], (v) => a = v),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(current),
          child: Text(SkStr.useThisColour.t),
        ),
      ],
    );
  }

  Widget _swatchBox(Color c) {
    final p = SkPalette.of(context);
    return SizedBox(
      height: 34,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _CheckerPainter(
            p[SkRole.checkerLight],
            p[SkRole.checkerDark],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: p[SkRole.swatchRing]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The font picker dialog: app default, system font, monospace, then every
/// imported font — each row RENDERED IN ITS OWN TYPEFACE — plus the action
/// that imports a font file. The fonts are a list of pure choices, so its
/// rows carry no icon column; the chosen one has a ✓.
Future<void> showSkFontPicker(
  BuildContext context, {
  required String selected,
  required ValueChanged<String> onPick,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _SkFontPickerDialog(selected: selected, onPick: onPick),
  );
}

class _SkFontPickerDialog extends StatefulWidget {
  const _SkFontPickerDialog({required this.selected, required this.onPick});
  final String selected;
  final ValueChanged<String> onPick;

  @override
  State<_SkFontPickerDialog> createState() => _SkFontPickerDialogState();
}

class _SkFontPickerDialogState extends State<_SkFontPickerDialog> {
  bool importing = false;

  Future<void> _import(SkUiProvider sk) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => importing = true);
    try {
      final res = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );
      final path = res?.path;
      if (path != null) {
        final family = await sk.importFont(path);
        if (family == null) {
          messenger.showSnackBar(SnackBar(content: Text(SkStr.pickFontFile.t)));
        }
      }
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sk = context.watch<SkUiProvider>();
    final p = SkPalette.of(context);
    final options = <(String, String)>[
      ('', SkStr.fontDefault.t),
      ('SystemFont', SkStr.fontSystem.t),
      (skMonospaceFamily, SkStr.fontMono.t),
      for (final f in sk.externalFonts) (f, f),
    ];
    return AlertDialog(
      title: Text(SkStr.font.t),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 340,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (family, label) in options)
              InkWell(
                onTap: () {
                  widget.onPick(family);
                  Navigator.of(context).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 16,
                                color: p[SkRole.dialogBody],
                                fontFamily: family.isEmpty
                                    ? 'Montserrat'
                                    : family,
                              ),
                            ),
                            Text(
                              skFontSample,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: p[SkRole.pageNote],
                                fontFamily: family.isEmpty
                                    ? 'Montserrat'
                                    : family,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (family == widget.selected)
                        Icon(Icons.check, size: 18, color: p[SkRole.menuCheck]),
                      if (sk.externalFonts.contains(family))
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: SkStr.deleteFont.t,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: p.icon(SkIconRole.delete),
                          ),
                          onPressed: () async {
                            await sk.deleteFont(family);
                            if (mounted) setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ),
            Container(
              height: 1,
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              color: p[SkRole.menuDivider],
            ),
            SkActionRow(
              label: importing ? SkStr.importing.t : SkStr.addFont.t,
              icon: Icons.add,
              opens: true,
              level: 0,
              onTap: importing ? null : () => _import(sk),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel')),
        ),
      ],
    );
  }
}
