// shiroikuma-kakutoku fork: the 白い熊 獲得 UI page — granular black-yellow
// theming in the sister-repo house style. Big bold underlined section
// headings, deeply indented rows (one more step per sublevel), tight
// spacing, and a live preview on everything: the page itself is themed by
// the knobs, so every change restyles it (and the whole app) instantly.
// Every change persists immediately; Cancel in a color dialog restores.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obtainium/components/sk_ui_widgets.dart';
import 'package:obtainium/providers/apps_provider.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';
import 'package:provider/provider.dart';

class SkUiPage extends StatelessWidget {
  const SkUiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sk = context.watch<SkUiProvider>();
    final k = sk.knobs;
    final theme = Theme.of(context);

    // Live for sliders (no persist per tick), persist on release / OK.
    void live(void Function() change) {
      change();
      sk.refresh();
    }

    void commit([void Function()? change]) {
      change?.call();
      sk.save();
    }

    Widget borderPreview() => Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(k.cornerRadius),
        border: k.borderWidth > 0
            ? Border.all(color: k.border, width: k.borderWidth)
            : null,
      ),
      child: Text('白い熊 獲得', style: theme.textTheme.bodySmall),
    );

    Widget iconPreview() => Row(
      children: [
        Icon(Icons.settings_outlined, size: 24 * k.iconSizeScale),
        const SizedBox(width: 10),
        Icon(Icons.download_outlined, size: 24 * k.iconSizeScale),
        const SizedBox(width: 10),
        Icon(Icons.add, size: 24 * k.iconSizeScale),
      ],
    );

    Widget fontPreview() => Text(
      skFontSample,
      maxLines: 2,
      style: theme.textTheme.bodyMedium,
    );

    final fontLabel = switch (k.fontFamily) {
      '' => 'App default (Montserrat)',
      'SystemFont' => 'System font',
      skMonospaceFamily => 'Monospace',
      _ => k.fontFamily,
    };

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('白い熊 獲得 UI'),
        actions: [
          IconButton(
            tooltip: 'Reset to 白い熊 defaults',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset to defaults?'),
                  content: const Text(
                    'All 白い熊 獲得 UI settings return to the black-yellow '
                    'defaults. Imported fonts stay available.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        MaterialLocalizations.of(ctx).cancelButtonLabel,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                    ),
                  ],
                ),
              );
              if (confirmed == true) sk.resetToDefaults();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ---- General ----
          const SkSectionHeading('General'),
          SkSwitchRow(
            label: 'Use 白い熊 獲得 UI (black-yellow theming)',
            level: 1,
            value: k.enabled,
            onChanged: (v) => commit(() => k.enabled = v),
          ),
          if (k.enabled) ...[
            // ---- Colors ----
            const SkSectionHeading('Colors'),
            const SkSubgroupHeading('Foundation'),
            SkColorRow(
              label: 'Background',
              color: k.background,
              onChanged: (c) => commit(() => k.background = c),
            ),
            SkColorRow(
              label: 'Surface (cards, sheets)',
              color: k.surface,
              onChanged: (c) => commit(() => k.surface = c),
            ),
            SkColorRow(
              label: 'Accent (primary)',
              color: k.accent,
              onChanged: (c) => commit(() => k.accent = c),
            ),
            SkColorRow(
              label: 'On accent (text on accent)',
              color: k.onAccent,
              onChanged: (c) => commit(() => k.onAccent = c),
            ),
            const SkSubgroupHeading('Text'),
            SkColorRow(
              label: 'Text',
              color: k.textPrimary,
              onChanged: (c) => commit(() => k.textPrimary = c),
            ),
            SkColorRow(
              label: 'Secondary text',
              color: k.textSecondary,
              onChanged: (c) => commit(() => k.textSecondary = c),
            ),
            const SkSubgroupHeading('Borders & icons'),
            SkColorRow(
              label: 'Border',
              color: k.border,
              onChanged: (c) => commit(() => k.border = c),
            ),
            SkColorRow(
              label: 'Icon',
              color: k.icon,
              onChanged: (c) => commit(() => k.icon = c),
            ),
            const SkSubgroupHeading('Top bar'),
            SkColorRow(
              label: 'Top bar background',
              color: k.appBarBackground,
              onChanged: (c) => commit(() => k.appBarBackground = c),
            ),
            SkColorRow(
              label: 'Top bar text & icons',
              color: k.appBarForeground,
              onChanged: (c) => commit(() => k.appBarForeground = c),
            ),
            const SkSubgroupHeading('Action button'),
            SkColorRow(
              label: 'Button background',
              color: k.fabBackground,
              onChanged: (c) => commit(() => k.fabBackground = c),
            ),
            SkColorRow(
              label: 'Button text & icon',
              color: k.fabForeground,
              onChanged: (c) => commit(() => k.fabForeground = c),
            ),

            // ---- Text & font ----
            const SkSectionHeading('Text & font'),
            SkRow(
              label: 'Font',
              level: 1,
              trailing: Text(
                fontLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: k.fontFamily.isEmpty
                      ? 'Montserrat'
                      : k.fontFamily,
                ),
              ),
              onTap: () => showSkFontPicker(
                context,
                selected: k.fontFamily,
                onPick: (family) {
                  if (family == 'SystemFont') {
                    // Make sure the dynamically loaded system family exists.
                    unawaited(NativeFeatures.loadSystemFont());
                  }
                  commit(() => k.fontFamily = family);
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(skIndent(2), 0, 14, 2),
              child: fontPreview(),
            ),
            SkSliderRow(
              label: 'Font size',
              level: 1,
              value: k.fontSizeScale,
              min: 0.5,
              max: 2.0,
              divisions: 30,
              valueText: '${(k.fontSizeScale * 100).round()}%',
              onChanged: (v) => live(() => k.fontSizeScale = v),
              onChangeEnd: (v) => commit(() => k.fontSizeScale = v),
            ),
            SkSliderRow(
              label: 'Font weight',
              level: 1,
              value: k.fontWeight,
              min: 100,
              max: 900,
              divisions: 8,
              valueText: '${k.fontWeight.round()}',
              onChanged: (v) => live(() => k.fontWeight = v),
              onChangeEnd: (v) => commit(() => k.fontWeight = v),
            ),

            // ---- Shape & borders ----
            const SkSectionHeading('Shape & borders'),
            SkSliderRow(
              label: 'Corner roundness',
              level: 1,
              value: k.cornerRadius,
              min: 0,
              max: 32,
              divisions: 32,
              valueText: '${k.cornerRadius.round()} dp',
              onChanged: (v) => live(() => k.cornerRadius = v),
              onChangeEnd: (v) => commit(() => k.cornerRadius = v),
              preview: borderPreview(),
            ),
            SkSliderRow(
              label: 'Border thickness (0 = none)',
              level: 1,
              value: k.borderWidth,
              min: 0,
              max: 6,
              divisions: 12,
              valueText: k.borderWidth <= 0
                  ? 'none'
                  : '${k.borderWidth.toStringAsFixed(1)} dp',
              onChanged: (v) => live(() => k.borderWidth = v),
              onChangeEnd: (v) => commit(() => k.borderWidth = v),
              preview: borderPreview(),
            ),

            // ---- Icons ----
            const SkSectionHeading('Icons'),
            SkSliderRow(
              label: 'Icon size',
              level: 1,
              value: k.iconSizeScale,
              min: 0.5,
              max: 2.0,
              divisions: 30,
              valueText: '${(k.iconSizeScale * 100).round()}%',
              onChanged: (v) => live(() => k.iconSizeScale = v),
              onChangeEnd: (v) => commit(() => k.iconSizeScale = v),
              preview: iconPreview(),
            ),

            // ---- Density ----
            const SkSectionHeading('Density'),
            SkSliderRow(
              label: 'Row spacing (0 = tightest)',
              level: 1,
              value: k.rowSpacing,
              min: 0,
              max: 16,
              divisions: 16,
              valueText: '${k.rowSpacing.round()} dp',
              onChanged: (v) => live(() => k.rowSpacing = v),
              onChangeEnd: (v) => commit(() => k.rowSpacing = v),
            ),
          ],
        ],
      ),
    );
  }
}
