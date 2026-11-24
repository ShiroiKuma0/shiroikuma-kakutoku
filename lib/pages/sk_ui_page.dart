// shiroikuma-kakutoku fork: the 白い熊 獲得 UI page, in the house style every
// 白い熊 app shares. Under the title: the pill that opens the app's own
// settings, then the chip index (one chip per section — a tap jumps, a
// long-press drags and reorders), then the sections as a folding accordion,
// every one folded on a fresh install. A row that does something is an
// outlined pill; a row with a control stays plain; every row has an icon.
//
// Every colour of the app is a role with a swatch row in the section of the
// item it colours. Every change restyles the whole app at once and persists
// immediately; Cancel in a colour dialog puts the old colour back.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:obtainium/sk_strings.dart';
import 'package:obtainium/components/sk_eximport.dart';
import 'package:obtainium/components/sk_language.dart';
import 'package:obtainium/components/sk_ui_widgets.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/providers/sk_automation.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';
import 'package:obtainium/sk_material.dart';
import 'package:obtainium/utils/native_features.dart';
import 'package:obtainium/utils/nav_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class SkUiPage extends StatefulWidget {
  const SkUiPage({super.key});

  @override
  State<SkUiPage> createState() => _SkUiPageState();
}

class _SkUiPageState extends State<SkUiPage> {
  // Export/Import status: the export directory + latest export in it,
  // queried when the page opens (and re-queried after directory changes).
  SkExportStatus? _exStatus;

  // 保存復元 automation (contract v2): the switch ships ON, and the token is an
  // extra a caller may be asked for rather than the gate. A pasted secret
  // cannot survive a wipe, and the case this serves is 応用管理 restoring apps
  // and their data onto a clean phone where nothing has been configured.
  bool _automationOn = true;
  bool _automationRequireToken = false;
  String _automationToken = '';
  bool _allFilesAccess = false;

  // What a chip scrolls to.
  final Map<SkSection, GlobalKey> _sectionKeys = {
    for (final s in SkSection.values) s: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _refreshExportStatus();
    final prefs = context.read<SettingsProvider>().prefs;
    if (prefs != null) {
      _automationOn = SkAutomation.isEnabled(prefs);
      _automationRequireToken = SkAutomation.requiresToken(prefs);
      // Read (and so generate) the token only when it is actually being asked
      // for: a 48-character secret written into prefs to sit under an off
      // switch is a secret nobody needs.
      if (_automationRequireToken) _automationToken = SkAutomation.token(prefs);
    }
    _refreshAllFilesAccess();
  }

  Future<void> _refreshAllFilesAccess() async {
    var granted = false;
    try {
      granted = await Permission.manageExternalStorage.isGranted;
    } catch (_) {
      // Platform without the permission concept — the SAF directory still
      // works.
    }
    if (mounted) setState(() => _allFilesAccess = granted);
  }

  Future<void> _setAutomation(bool value) async {
    final prefs = context.read<SettingsProvider>().prefs;
    if (prefs == null) return;
    await SkAutomation.setEnabled(prefs, value);
    if (!mounted) return;
    setState(() => _automationOn = value);
    if (!value || _allFilesAccess) return;
    // A sister-app task may hand us an absolute directory to write into, which
    // needs All-files access; without it the export falls back to the
    // directory configured above.
    try {
      await Permission.manageExternalStorage.request();
    } catch (_) {
      // Denied or unavailable — the fallback still produces a backup.
    }
    await _refreshAllFilesAccess();
  }

  Future<void> _setRequireToken(bool value) async {
    final prefs = context.read<SettingsProvider>().prefs;
    if (prefs == null) return;
    await SkAutomation.setRequireToken(prefs, value);
    if (!mounted) return;
    setState(() {
      _automationRequireToken = value;
      // Generated on first read, which is now — the row below is about to be
      // shown and must have something to abbreviate.
      if (value && _automationToken.isEmpty) {
        _automationToken = SkAutomation.token(prefs);
      }
    });
  }

  Future<void> _copyToken() async {
    await Clipboard.setData(ClipboardData(text: _automationToken));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(SkStr.tokenCopied.t)));
  }

  /// A yes / no question; [destructive] makes the confirming pill red.
  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        destructive: destructive,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _regenerateToken() async {
    final prefs = context.read<SettingsProvider>().prefs;
    if (prefs == null) return;
    final confirmed = await _confirm(
      title: SkStr.regenTitle.t,
      body: SkStr.regenBody.t,
      action: SkStr.regenerate.t,
    );
    if (!confirmed) return;
    final token = SkAutomation.regenerate(prefs);
    if (!mounted) return;
    setState(() => _automationToken = token);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(SkStr.tokenGenerated.t)));
  }

  Future<void> _refreshExportStatus() async {
    final sp = context.read<SettingsProvider>();
    SkExportStatus st;
    try {
      st = await skLastExportStatus(
        sp,
        progress: (stage) {
          if (mounted) {
            setState(
              () => _exStatus = SkExportStatus(
                dirSet: true,
                dirName: '⋯',
                message: stage,
              ),
            );
          }
        },
      );
    } catch (e) {
      st = SkExportStatus(
        dirSet: false,
        message: SkStr.statusCheckFailed.f(['$e']),
      );
    }
    if (mounted) setState(() => _exStatus = st);
  }

  Future<void> _pickExportDir() async {
    try {
      await context.read<SettingsProvider>().pickExportDir();
    } catch (_) {
      // Picker unavailable — the status line keeps showing the warning.
    }
    await _refreshExportStatus();
  }

  Future<void> _openEximportPanel() async {
    final closePage = await showSkEximportPanel(context);
    if (!mounted) return;
    if (closePage) {
      Navigator.of(context).pop();
      return;
    }
    await _refreshExportStatus();
  }

  // ---- The page's arrangement ----

  /// The sections the page shows now. While the 白い熊 獲得 UI is switched
  /// off its roles colour nothing, so only what still works is offered.
  List<SkSection> _visible(SkUiKnobs k) => k.enabled
      ? SkSection.values
      : const [
          SkSection.language,
          SkSection.eximport,
          SkSection.general,
          SkSection.maintenance,
        ];

  /// The stored order, limited to the sections shown, with any section it
  /// does not name yet appended in its default place. “App language” is the
  /// exception: an order stored before the section existed gets it first —
  /// nothing dragged it anywhere yet. Once the order names it, it stays where
  /// it was dragged.
  List<SkSection> _order(SkUiKnobs k) {
    final visible = _visible(k);
    final order = <SkSection>[
      if (!k.sectionOrder.contains(SkSection.language.name)) SkSection.language,
      for (final name in k.sectionOrder)
        if (SkSection.byName(name) case final s?)
          if (visible.contains(s)) s,
    ];
    for (final s in visible) {
      if (!order.contains(s)) order.add(s);
    }
    return order;
  }

  /// A drop in the chip index: the sections shown take their new order, and
  /// the ones hidden right now keep their places after them.
  void _reorder(SkUiProvider sk, List<SkSection> shown) {
    sk.setSectionOrder([
      for (final s in shown) s.name,
      for (final name in sk.knobs.sectionOrder)
        if (!shown.any((s) => s.name == name)) name,
    ]);
  }

  /// A tap on an index chip: unfold the section and scroll to it.
  void _jump(SkUiProvider sk, SkSection s) {
    sk.setSectionOpen(s, true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _sectionKeys[s]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sk = context.watch<SkUiProvider>();
    final k = sk.knobs;
    final theme = Theme.of(context);
    final p = SkPalette.of(context);
    final order = _order(k);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('白い熊 獲得 UI')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            // The link to the app's own settings: the first, thick pill. It
            // opens over this page, so Back returns here.
            SkActionRow(
              label: SkStr.appSettings.t,
              icon: Icons.settings_outlined,
              main: true,
              opens: true,
              onTap: () => NavHelper.pushSettingsPage(context),
            ),
            SkSectionIndex(
              order: order,
              onJump: (s) => _jump(sk, s),
              onReordered: (shown) => _reorder(sk, shown),
            ),
            for (final s in order) ...[
              SkSectionHeader(
                key: _sectionKeys[s],
                section: s,
                open: k.sectionsOpen.contains(s.name),
                onTap: () =>
                    sk.setSectionOpen(s, !k.sectionsOpen.contains(s.name)),
              ),
              // A folded section's rows are not built at all.
              if (k.sectionsOpen.contains(s.name)) ..._rows(s, sk, p),
            ],
            Container(height: 1, color: p[SkRole.pageDivider]),
          ],
        ),
      ),
    );
  }

  List<Widget> _rows(SkSection s, SkUiProvider sk, SkPalette p) {
    final k = sk.knobs;
    final theme = Theme.of(context);

    // Live for sliders (no persist per tick), persist on release.
    void live(void Function() change) {
      change();
      sk.refresh();
    }

    void commit([void Function()? change]) {
      change?.call();
      sk.save();
    }

    final rows = switch (s) {
      SkSection.language => <Widget>[
        SkActionRow(
          label: SkStr.languageRow.f([
            skLanguageName(context.watch<SettingsProvider>().forcedLocale),
          ]),
          icon: Icons.language,
          main: true,
          opens: true,
          onTap: () => showSkLanguagePicker(context),
        ),
      ],
      SkSection.eximport => _eximportRows(p),
      SkSection.general => <Widget>[
        SkSwitchRow(
          label: SkStr.useUi.t,
          icon: Icons.toggle_on_outlined,
          note: SkStr.useUiNote.t,
          value: k.enabled,
          onChanged: (v) => commit(() => k.enabled = v),
        ),
      ],
      SkSection.foundation => <Widget>[
        SkNote(SkStr.foundationNote.t),
        for (final b in SkBase.values)
          SkColorRow(
            label: b.label,
            icon: skKindIcon(b.kind),
            iconColor: p.section(s),
            color: k.base(b),
            onChanged: (c) => commit(() => k.setBase(b, c)),
            onReset: k.base(b).toARGB32() == b.defaultArgb
                ? null
                : () => sk.resetBase(b),
          ),
      ],
      SkSection.text => <Widget>[
        SkActionRow(
          label: SkStr.font.t,
          icon: Icons.font_download_outlined,
          opens: true,
          note: switch (k.fontFamily) {
            '' => SkStr.fontDefault.t,
            'SystemFont' => SkStr.fontSystem.t,
            skMonospaceFamily => SkStr.fontMono.t,
            _ => k.fontFamily,
          },
          below: Text(
            skFontSample,
            maxLines: 2,
            style: theme.textTheme.bodyMedium,
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
        SkSliderRow(
          label: SkStr.fontSize.t,
          icon: Icons.format_size,
          value: k.fontSizeScale,
          min: 0.5,
          max: 2.0,
          divisions: 30,
          valueText: '${(k.fontSizeScale * 100).round()}%',
          onChanged: (v) => live(() => k.fontSizeScale = v),
          onChangeEnd: (v) => commit(() => k.fontSizeScale = v),
        ),
        SkSliderRow(
          label: SkStr.fontWeight.t,
          icon: Icons.format_bold,
          value: k.fontWeight,
          min: 100,
          max: 900,
          divisions: 8,
          valueText: '${k.fontWeight.round()}',
          onChanged: (v) => live(() => k.fontWeight = v),
          onChangeEnd: (v) => commit(() => k.fontWeight = v),
        ),
        SkSubgroupHeading(SkStr.colours.t),
        SkRoleRows(s, level: 2),
      ],
      SkSection.icons => <Widget>[
        SkSliderRow(
          label: SkStr.iconSize.t,
          icon: Icons.interests_outlined,
          role: SkIconRole.contact,
          value: k.iconSizeScale,
          min: 0.5,
          max: 2.0,
          divisions: 30,
          valueText: '${(k.iconSizeScale * 100).round()}%',
          onChanged: (v) => live(() => k.iconSizeScale = v),
          onChangeEnd: (v) => commit(() => k.iconSizeScale = v),
          preview: Row(
            children: [
              for (final i in const [
                Icons.settings_outlined,
                Icons.download_outlined,
                Icons.add,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    i,
                    size: 24 * k.iconSizeScale,
                    color: p.base(SkBase.icon),
                  ),
                ),
            ],
          ),
        ),
        SkSubgroupHeading(SkStr.iconsByRole.t),
        SkRoleRows(s, level: 2),
      ],
      SkSection.shape => <Widget>[
        SkNote(SkStr.shapeNote.t),
        SkSliderRow(
          label: SkStr.cornerRoundness.t,
          icon: Icons.rounded_corner,
          value: k.cornerRadius,
          min: 0,
          max: 32,
          divisions: 32,
          valueText: '${k.cornerRadius.round()} dp',
          onChanged: (v) => live(() => k.cornerRadius = v),
          onChangeEnd: (v) => commit(() => k.cornerRadius = v),
          preview: _borderPreview(k, p),
        ),
        SkSliderRow(
          label: SkStr.borderThickness.t,
          icon: Icons.line_weight,
          value: k.borderWidth,
          min: 0,
          max: 6,
          divisions: 12,
          valueText: k.borderWidth <= 0
              ? SkStr.none.t
              : '${k.borderWidth.toStringAsFixed(1)} dp',
          onChanged: (v) => live(() => k.borderWidth = v),
          onChangeEnd: (v) => commit(() => k.borderWidth = v),
          preview: _borderPreview(k, p),
        ),
        SkSliderRow(
          label: SkStr.rowSpacing.t,
          icon: Icons.format_line_spacing,
          value: k.rowSpacing,
          min: 0,
          max: 16,
          divisions: 16,
          valueText: '${k.rowSpacing.round()} dp',
          onChanged: (v) => live(() => k.rowSpacing = v),
          onChangeEnd: (v) => commit(() => k.rowSpacing = v),
        ),
      ],
      SkSection.maintenance => <Widget>[
        SkActionRow(
          label: SkStr.resetOrder.t,
          icon: Icons.reorder,
          note: SkStr.resetOrderNote.t,
          onTap: sk.resetSectionOrder,
        ),
        if (k.enabled)
          SkActionRow(
            label: SkStr.resetColours.t,
            icon: Icons.restart_alt,
            destructive: true,
            note: SkStr.resetColoursNote.t,
            onTap: () async {
              if (await _confirm(
                title: SkStr.resetColoursTitle.t,
                body: SkStr.resetColoursBody.t,
                action: SkStr.reset.t,
                destructive: true,
              )) {
                sk.resetAllColours();
              }
            },
          ),
        SkActionRow(
          label: SkStr.resetAll.t,
          icon: Icons.restart_alt,
          destructive: true,
          note: SkStr.resetAllNote.t,
          onTap: () async {
            if (await _confirm(
              title: SkStr.resetAllTitle.t,
              body: SkStr.resetAllBody.t,
              action: SkStr.reset.t,
              destructive: true,
            )) {
              sk.resetToDefaults();
            }
          },
        ),
      ],
      SkSection.page => <Widget>[
        SkRoleRows(s, sectionIcons: false),
        SkSubgroupHeading(SkStr.sectionIcons.t),
        SkNote(SkStr.sectionIconsNote.t, level: 2),
        SkRoleRows(s, level: 2, sectionIcons: true),
      ],
      // Every other section holds the colour roles of its items.
      _ => <Widget>[SkRoleRows(s)],
    };
    return [...rows, const SizedBox(height: 6)];
  }

  Widget _borderPreview(SkUiKnobs k, SkPalette p) => Container(
    height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: p[SkRole.cardGround],
      borderRadius: BorderRadius.circular(k.cornerRadius),
      border: k.borderWidth > 0
          ? Border.all(color: p[SkRole.cardFrame], width: k.borderWidth)
          : null,
    ),
    child: Text('白い熊 獲得', style: Theme.of(context).textTheme.bodySmall),
  );

  List<Widget> _eximportRows(SkPalette p) {
    final st = _exStatus;
    final warn = p[SkRole.warning];
    return [
      SkActionRow(
        label: SkStr.eximportOpen.t,
        icon: Icons.import_export,
        main: true,
        opens: true,
        note: SkStr.eximportNote.t,
        onTap: _openEximportPanel,
      ),
      SkActionRow(
        label: SkStr.exportDir.t,
        icon: Icons.folder_open,
        opens: true,
        note: st == null
            ? '…'
            : [st.dirName ?? SkStr.notSetTap.t, st.message].join('\n'),
        noteColor: (st?.dirSet ?? true) ? null : warn,
        onTap: _pickExportDir,
      ),
      SkSwitchRow(
        label: SkStr.automationExport.t,
        icon: Icons.sync,
        value: _automationOn,
        onChanged: _setAutomation,
        note: SkStr.automationNote.t,
        below: _automationOn && !_allFilesAccess
            ? Text(
                SkStr.noAllFiles.t,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: warn),
              )
            : null,
      ),
      SkSwitchRow(
        label: SkStr.useToken.t,
        icon: Icons.key,
        value: _automationRequireToken,
        onChanged: _setRequireToken,
        note: SkStr.useTokenNote.t,
      ),
      // Shown only when the token is being asked for: a 48-character secret
      // sitting under an off switch invites pasting it somewhere it will do
      // nothing.
      if (_automationRequireToken) ...[
        SkActionRow(
          label: SkStr.copyToken.t,
          icon: Icons.content_copy,
          note: _automationToken.isEmpty
              ? '…'
              : SkAutomation.abbreviate(_automationToken),
          onTap: _copyToken,
        ),
        SkActionRow(
          label: SkStr.regenToken.t,
          icon: Icons.refresh,
          note: SkStr.regenTokenNote.t,
          onTap: _regenerateToken,
        ),
      ],
    ];
  }
}
