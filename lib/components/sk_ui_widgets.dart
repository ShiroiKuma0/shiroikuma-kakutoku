// shiroikuma-kakutoku fork: building blocks of the 白い熊 獲得 UI page,
// mirroring the sister-repo house style — two heading tiers (big bold with a
// full-width accent rule / smaller bold with a text-width underline), deep
// per-level indents, tight single-line rows, per-row previews, an
// RGBA-slider color picker with one-click recent-color boxes, and a font
// picker that renders every family in its own glyphs.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';
import 'package:provider/provider.dart';

/// Indent per hierarchy level (the sisters use 48-72dp).
const double skIndentStep = 40;

/// The live text sample used by font/text previews (same string family as
/// the sister repos: Latin + 白い熊 kanji + Czech diacritics).
const String skFontSample = 'AaIiMmOoQqWw 012 白い熊相撲道 áčďéěíňóřšťúůýž';

double skIndent(int level) => 16.0 + skIndentStep * level;

/// kxkb-style section heading: a full-width 1px hairline spacer above
/// (between sections — omitted via [first]), then a 20sp bold accent title
/// underlined only as wide as the text (2.5dp rule, 2dp gap).
class SkSectionHeading extends StatelessWidget {
  const SkSectionHeading(this.title, {super.key, this.first = false});
  final String title;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final sk = context.watch<SkUiProvider>();
    final scale = sk.knobs.enabled ? sk.knobs.fontSizeScale : 1.0;
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: EdgeInsets.only(top: first ? 12 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!first) ...[
            Container(height: hairline, color: accent),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20 * scale,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(height: 2.5, color: accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Smaller (17sp) bold subgroup heading with a 1.5dp underline exactly as
/// wide as the text, indented one level.
class SkSubgroupHeading extends StatelessWidget {
  const SkSubgroupHeading(this.title, {super.key, this.level = 1});
  final String title;
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final sk = context.watch<SkUiProvider>();
    final scale = sk.knobs.enabled ? sk.knobs.fontSizeScale : 1.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(skIndent(level), 10, 16, 2),
      child: Row(
        children: [
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 17 * scale,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Container(height: 1.5, color: accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tight, indented, whole-row-tappable line: label + trailing widget.
class SkRow extends StatelessWidget {
  const SkRow({
    super.key,
    required this.label,
    this.level = 2,
    this.trailing,
    this.below,
    this.onTap,
  });
  final String label;
  final int level;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.fromLTRB(skIndent(level), 3, 14, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          ?below,
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// A tight, indented switch row (tap anywhere on the row toggles).
class SkSwitchRow extends StatelessWidget {
  const SkSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.level = 2,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final int level;

  @override
  Widget build(BuildContext context) {
    return SkRow(
      label: label,
      level: level,
      onTap: () => onChanged(!value),
      trailing: IgnorePointer(
        child: SizedBox(
          height: 28,
          child: FittedBox(
            child: Switch(value: value, onChanged: (_) {}),
          ),
        ),
      ),
    );
  }
}

/// A tight, indented slider row with the current value and an optional
/// inline preview below. Live: [onChanged] fires while dragging,
/// [onChangeEnd] persists.
class SkSliderRow extends StatelessWidget {
  const SkSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
    this.level = 2,
    this.divisions,
    this.valueText,
    this.preview,
  });
  final String label;
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
    return Padding(
      padding: EdgeInsets.fromLTRB(skIndent(level), 2, 14, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                valueText ?? value.toStringAsFixed(0),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          SizedBox(
            height: 28,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 14,
                ),
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
            Padding(
              padding: const EdgeInsets.only(left: skIndentStep, bottom: 2),
              child: preview!,
            ),
        ],
      ),
    );
  }
}

/// The 28dp circular per-row color swatch (over a checkerboard so alpha is
/// visible), with a hairline outline.
class SkColorSwatchDot extends StatelessWidget {
  const SkColorSwatchDot(this.color, {super.key, this.size = 28});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CustomPaint(
          painter: _CheckerPainter(),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFFBBBBBB);
    final dark = Paint()..color = const Color(0xFF666666);
    const cell = 5.0;
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final even = ((x / cell).floor() + (y / cell).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cell, cell),
          even ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A color row: label + trailing swatch; tap opens the RGBA picker dialog.
/// [onChanged] fires live while the dialog is being manipulated; on cancel
/// the original color is restored (also via [onChanged]).
class SkColorRow extends StatelessWidget {
  const SkColorRow({
    super.key,
    required this.label,
    required this.color,
    required this.onChanged,
    this.level = 2,
  });
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;
  final int level;

  @override
  Widget build(BuildContext context) {
    return SkRow(
      label: label,
      level: level,
      trailing: SkColorSwatchDot(color),
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
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(name, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: SizedBox(
            height: 26,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: trackColor,
                thumbColor: trackColor,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 13,
                ),
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
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final recents = context.watch<SkUiProvider>().recentColors;
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
                      Text(
                        'old',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      _swatchBox(current),
                      const SizedBox(height: 2),
                      Text(
                        '#$hex',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _channelSlider('R', r, const Color(0xFFFF5050), (v) => r = v),
            _channelSlider('G', g, const Color(0xFF50C050), (v) => g = v),
            _channelSlider('B', b, const Color(0xFF5080FF), (v) => b = v),
            _channelSlider('A', a, Theme.of(context).colorScheme.primary,
                (v) => a = v),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(current),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }

  Widget _swatchBox(Color c) => SizedBox(
    height: 34,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CustomPaint(
        painter: _CheckerPainter(),
        child: Container(
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The font picker dialog: app default, system font, monospace, then every
/// imported font — each row RENDERED IN ITS OWN TYPEFACE — plus "Add font…".
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

  @override
  Widget build(BuildContext context) {
    final sk = context.watch<SkUiProvider>();
    final options = <(String, String)>[
      ('', 'App default (Montserrat)'),
      ('SystemFont', 'System font'),
      (skMonospaceFamily, 'Monospace'),
      for (final f in sk.externalFonts) (f, f),
    ];
    return AlertDialog(
      title: const Text('Font'),
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
                    vertical: 7,
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
                                fontFamily: family.isEmpty
                                    ? 'Montserrat'
                                    : family,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (family == widget.selected)
                        const Icon(Icons.check, size: 18),
                      if (sk.externalFonts.contains(family))
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () async {
                            await sk.deleteFont(family);
                            if (mounted) setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ),
            InkWell(
              onTap: importing
                  ? null
                  : () async {
                      setState(() => importing = true);
                      try {
                        final res = await FilePicker.pickFile(
                          type: FileType.custom,
                          allowedExtensions: ['ttf', 'otf'],
                        );
                        final path = res?.path;
                        if (path != null) {
                          final family = await sk.importFont(path);
                          if (family == null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please pick a .ttf or .otf font file',
                                ),
                              ),
                            );
                          }
                        }
                      } finally {
                        if (mounted) setState(() => importing = false);
                      }
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      importing ? 'Importing…' : 'Add font (.ttf / .otf)…',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
