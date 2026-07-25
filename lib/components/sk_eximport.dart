// shiroikuma-kakutoku fork: category Export/Import for the 白い熊 獲得 UI
// page, in the sister-fork house style (Kōjiki flow, ArcaneChat buttons):
// a settable export folder queried for the latest export, per-category
// checkboxes with the sources first, a pill button row — Cancel separated
// left, Import + Export right — and black-yellow bordered result dialogs.
// On success the whole chain closes (info dialog → panel → UI page);
// failures leave the panel open.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obtainium/providers/apps_provider.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';
import 'package:obtainium/providers/source_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_storage/shared_storage.dart' as saf;

const Color skWarnRed = Color(0xFFFF5252);

const String skExportFormat = 'kakutoku-export';
const int skExportVersion = 1;
const String skExportPrefix = 'shiroikuma-kakutoku-';

/// A selectable export/import category. `id` is the key inside the export
/// JSON's `data` map. Order = display order (sources first).
enum SkExportCat {
  sources('sources', 'Sources (tracked apps)'),
  appSettings('appSettings', 'App settings'),
  creds('creds', 'Source credentials'),
  categories('categories', 'Categories'),
  skUi('skUi', '白い熊 獲得 UI (colors · fonts · sizes)');

  const SkExportCat(this.id, this.label);
  final String id;
  final String label;
}

/// Settings keys that live in the shared prefs file but belong to another
/// category (or are device-local) and must not ride along in "App settings".
const Set<String> _appSettingsExclude = {'exportDir', 'categories'};

bool _isCredKey(String k) => k.endsWith('-creds');
bool _isSkUiKey(String k) => k == 'skUiKnobs' || k == 'skUiRecentColors';

String _pad2(int n) => n.toString().padLeft(2, '0');

String skExportFileName() {
  final now = DateTime.now();
  final ts =
      '${now.year}-${_pad2(now.month)}-${_pad2(now.day)}'
      '_${_pad2(now.hour)}-${_pad2(now.minute)}-${_pad2(now.second)}';
  return '$skExportPrefix$kPackageVersion-export_$ts.json';
}

/// The UI-page / panel status of the export folder + latest export in it.
class SkExportStatus {
  const SkExportStatus({
    required this.dirSet,
    this.dirName,
    required this.message,
  });
  final bool dirSet;
  final String? dirName;
  final String message;
}

/// Serializes folder queries: two concurrent [saf.listFiles] listeners share
/// one platform event channel, and the second listener orphans the first
/// (its stream never closes), so queries must never overlap.
Future<void> _statusChain = Future.value();

/// The timestamp our export filenames embed ("…export_2026-07-25_11-17-35.json").
final RegExp _exportTsRe = RegExp(
  r'export_(\d{4}-\d{2}-\d{2})_(\d{2})-(\d{2})-(\d{2})\.json$',
);

/// Queries the export folder (if set) for the newest 白い熊 獲得 export.
/// Never throws and never hangs: every stage has its own timeout, every
/// failure becomes a readable status, and [progress] reports the current
/// stage so a stall is visible on screen instead of an eternal "…".
Future<SkExportStatus> skLastExportStatus(
  SettingsProvider sp, {
  void Function(String stage)? progress,
}) {
  final prev = _statusChain;
  final run = () async {
    // Wait for any previous query (shared platform event channel), but
    // never inherit its hang.
    progress?.call('waiting for a previous folder check…');
    try {
      await prev.timeout(const Duration(seconds: 15));
    } catch (_) {}
    return _lastExportStatusInner(sp, progress);
  }();
  _statusChain = run.then((_) {}, onError: (_) {});
  return run;
}

/// Human-readable folder name from a SAF tree URI. `pathSegments` is
/// already percent-decoded — never decode it again (a second
/// [Uri.decodeComponent] THROWS on non-ASCII folder names, e.g. Japanese).
String _dirDisplayName(Uri? dir) {
  if (dir == null) return '(folder)';
  var name = dir.pathSegments.isNotEmpty
      ? dir.pathSegments.last
      : dir.toString();
  final colon = name.indexOf(':');
  if (colon >= 0 && colon < name.length - 1) {
    name = name.substring(colon + 1);
  }
  return name;
}

Future<SkExportStatus> _lastExportStatusInner(
  SettingsProvider sp,
  void Function(String stage)? progress,
) async {
  progress?.call('checking the export folder…');
  Uri? dir;
  var failure = '';
  try {
    dir = await sp.getExportDir().timeout(const Duration(seconds: 8));
  } on TimeoutException {
    dir = null;
    failure = 'The folder permission check timed out.';
  } catch (e) {
    dir = null;
    failure = 'The folder check failed: $e';
  }
  if (dir == null) {
    if (failure.isNotEmpty) {
      // The permission check failed, but a folder may still be stored —
      // show its name rather than claiming nothing is set.
      final raw = sp.prefs?.getString('exportDir');
      if (raw != null) {
        return SkExportStatus(
          dirSet: true,
          dirName: _dirDisplayName(Uri.tryParse(raw)),
          message: '⚠ $failure',
        );
      }
    }
    return SkExportStatus(
      dirSet: false,
      message: failure.isNotEmpty
          ? '⚠ $failure'
          : '⚠ No export folder set — your 白い熊 獲得 setup is NOT backed up',
    );
  }
  final dirName = _dirDisplayName(dir);
  progress?.call('listing “$dirName”…');
  String? newestTs;
  var listFailure = '';
  try {
    // Only the id column: OEM document providers may omit other requested
    // columns from the cursor, which crashes the plugin's reader coroutine
    // and leaves the stream open forever (the upstream export code also
    // queries id only). The timeout is the safety net for exactly that.
    final files = await saf
        .listFiles(dir, columns: [saf.DocumentFileColumn.id])
        .toList()
        .timeout(const Duration(seconds: 12));
    for (final f in files) {
      final name = (f.name ?? f.uri.pathSegments.last).split('/').last;
      if (!name.startsWith(skExportPrefix)) continue;
      final m = _exportTsRe.firstMatch(name);
      if (m == null) continue;
      final ts = '${m.group(1)} ${m.group(2)}:${m.group(3)}:${m.group(4)}';
      if (newestTs == null || ts.compareTo(newestTs) > 0) newestTs = ts;
    }
  } on TimeoutException {
    listFailure = 'Listing the folder timed out.';
  } catch (e) {
    listFailure = 'Listing the folder failed: $e';
  }
  if (listFailure.isNotEmpty) {
    return SkExportStatus(dirSet: true, dirName: dirName, message: '⚠ $listFailure');
  }
  if (newestTs == null) {
    return SkExportStatus(
      dirSet: true,
      dirName: dirName,
      message: 'No export in this folder yet.',
    );
  }
  return SkExportStatus(
    dirSet: true,
    dirName: dirName,
    message: 'Last exported: $newestTs',
  );
}

/// Builds the export JSON for the selected categories.
Future<Map<String, dynamic>> skBuildExport({
  required AppsProvider appsProvider,
  required SettingsProvider settingsProvider,
  required SkUiProvider skUiProvider,
  required Set<SkExportCat> cats,
}) async {
  final data = <String, dynamic>{};
  for (final cat in cats) {
    switch (cat) {
      case SkExportCat.sources:
        await appsProvider.waitForAppsToLoad();
        data[cat.id] = {
          'apps': appsProvider.apps.values.map((e) => e.app.toJson()).toList(),
        };
      case SkExportCat.appSettings:
        final m = <String, Object?>{};
        for (final k in settingsProvider.prefs?.getKeys() ?? <String>{}) {
          if (_appSettingsExclude.contains(k) ||
              _isCredKey(k) ||
              _isSkUiKey(k)) {
            continue;
          }
          m[k] = settingsProvider.prefs?.get(k);
        }
        data[cat.id] = m;
      case SkExportCat.creds:
        final m = <String, Object?>{};
        for (final k in settingsProvider.prefs?.getKeys() ?? <String>{}) {
          if (_isCredKey(k)) m[k] = settingsProvider.prefs?.get(k);
        }
        data[cat.id] = m;
      case SkExportCat.categories:
        data[cat.id] = settingsProvider.categories;
      case SkExportCat.skUi:
        final fonts = <String, String>{};
        for (final f in await skUiProvider.fontFiles()) {
          fonts[f.path.split('/').last] = base64Encode(await f.readAsBytes());
        }
        data[cat.id] = {
          'knobs': skUiProvider.knobs.toJson(),
          'recentColors': skUiProvider.recentColors
              .map((c) => c.toARGB32())
              .toList(),
          'fonts': fonts,
        };
    }
  }
  return {
    'format': skExportFormat,
    'version': skExportVersion,
    'app': obtainiumId,
    'appVersion': kPackageVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'categories': cats.map((c) => c.id).toList(),
    'data': data,
  };
}

void _applyPref(SettingsProvider sp, String k, dynamic v) {
  if (v is bool) {
    sp.prefs?.setBool(k, v);
  } else if (v is int) {
    sp.prefs?.setInt(k, v);
  } else if (v is double) {
    sp.prefs?.setDouble(k, v);
  } else if (v is List) {
    sp.prefs?.setStringList(k, v.whereType<String>().toList());
  } else if (v is String) {
    sp.setSettingString(k, v);
  }
}

/// Applies the selected categories from a decoded export. Absent categories
/// are silently skipped; existing data is merged, never wiped. Returns a
/// human summary (one line per applied category).
Future<String> skApplyImport({
  required Map<String, dynamic> decoded,
  required Set<SkExportCat> cats,
  required AppsProvider appsProvider,
  required SettingsProvider settingsProvider,
  required SkUiProvider skUiProvider,
}) async {
  if (decoded['format'] != skExportFormat) {
    throw 'not a 白い熊 獲得 export file';
  }
  final version = decoded['version'] is int ? decoded['version'] as int : 1;
  if (version > skExportVersion) {
    throw 'export was created by a newer 白い熊 獲得 '
        '(v$version, this app reads up to v$skExportVersion)';
  }
  final data = decoded['data'] is Map<String, dynamic>
      ? decoded['data'] as Map<String, dynamic>
      : <String, dynamic>{};
  final parts = <String>[];
  for (final cat in SkExportCat.values) {
    if (!cats.contains(cat)) continue;
    final d = data[cat.id];
    if (d == null) continue;
    switch (cat) {
      case SkExportCat.sources:
        final appsJson = d is Map && d['apps'] is List
            ? d['apps'] as List
            : const [];
        final apps = appsJson
            .map((e) => App.fromJson(e as Map<String, dynamic>))
            .toList();
        await appsProvider.waitForAppsToLoad();
        for (var i = 0; i < apps.length; i++) {
          final installedInfo = await getInstalledInfo(apps[i].id);
          apps[i] = apps[i].copyWith(
            installedVersion:
                apps[i].settings.getBool('useVersionCodeAsOSVersion')
                ? installedInfo?.versionCode.toString()
                : installedInfo?.versionName,
          );
        }
        await appsProvider.saveApps(apps, onlyIfExists: false);
        appsProvider.addMissingCategories(settingsProvider);
        parts.add('${cat.label}: ${apps.length}');
      case SkExportCat.appSettings:
      case SkExportCat.creds:
        var n = 0;
        (d as Map<String, dynamic>).forEach((k, v) {
          _applyPref(settingsProvider, k, v);
          n++;
        });
        parts.add('${cat.label}: $n');
      case SkExportCat.categories:
        final imported = (d as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        );
        settingsProvider.setCategories({
          ...settingsProvider.categories,
          ...imported,
        });
        parts.add('${cat.label}: ${imported.length}');
      case SkExportCat.skUi:
        SkUiKnobs? knobs;
        if (d is Map && d['knobs'] is Map<String, dynamic>) {
          knobs = SkUiKnobs.fromJson(d['knobs'] as Map<String, dynamic>);
        }
        List<Color>? colors;
        if (d is Map && d['recentColors'] is List) {
          colors = (d['recentColors'] as List)
              .whereType<num>()
              .map((n) => Color(n.toInt()))
              .toList();
        }
        var nFonts = 0;
        if (d is Map && d['fonts'] is Map<String, dynamic>) {
          for (final e in (d['fonts'] as Map<String, dynamic>).entries) {
            if (e.value is! String) continue;
            try {
              if (await skUiProvider.importFontBytes(
                e.key,
                base64Decode(e.value as String),
              )) {
                nFonts++;
              }
            } catch (_) {
              // Skip undecodable font entries.
            }
          }
        }
        skUiProvider.applyImported(newKnobs: knobs, colors: colors);
        parts.add('${cat.label}: knobs + $nFonts font(s)');
    }
  }
  return parts.isEmpty ? 'nothing imported' : parts.join('\n');
}

/// Relaunches the app (Kōjiki-style: restart activity task + exit).
Future<void> skRestartApp() async {
  const channel = MethodChannel('dev.imranr.obtainium/sk');
  await channel.invokeMethod('restartApp');
}

/// ArcaneChat-style round pill outline button.
class SkPillButton extends StatelessWidget {
  const SkPillButton(this.label, {super.key, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final fg = onPressed == null ? accent.withValues(alpha: 0.4) : accent;
    return Material(
      color: theme.colorScheme.surface,
      shape: StadiumBorder(side: BorderSide(color: fg, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        splashColor: accent.withValues(alpha: 0.2),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the Export/Import panel. Returns true when the whole chain should
/// close (successful export acknowledged, or import acknowledged), so the
/// caller (the UI page) can pop itself too.
Future<bool> showSkEximportPanel(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => const _SkEximportPanel(),
  );
  return result == true;
}

class _SkEximportPanel extends StatefulWidget {
  const _SkEximportPanel();

  @override
  State<_SkEximportPanel> createState() => _SkEximportPanelState();
}

class _SkEximportPanelState extends State<_SkEximportPanel> {
  final Map<SkExportCat, bool> _checked = {
    for (final c in SkExportCat.values) c: true,
  };
  bool _selectAll = true;
  bool _busy = false;
  String? _error;
  SkExportStatus? _status;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final sp = context.read<SettingsProvider>();
    SkExportStatus st;
    try {
      st = await skLastExportStatus(
        sp,
        progress: (stage) {
          if (mounted) {
            setState(
              () => _status = SkExportStatus(
                dirSet: true,
                dirName: '⋯',
                message: stage,
              ),
            );
          }
        },
      );
    } catch (e) {
      st = SkExportStatus(dirSet: false, message: '⚠ Status check failed: $e');
    }
    if (mounted) setState(() => _status = st);
  }

  Set<SkExportCat> _selected() =>
      _checked.entries.where((e) => e.value).map((e) => e.key).toSet();

  Future<void> _pickDir() async {
    final sp = context.read<SettingsProvider>();
    try {
      await sp.pickExportDir();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    await _refreshStatus();
  }

  Future<void> _export() async {
    final cats = _selected();
    if (cats.isEmpty) {
      setState(() => _error = 'No categories selected.');
      return;
    }
    final appsProvider = context.read<AppsProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final skUiProvider = context.read<SkUiProvider>();
    var dir = await settingsProvider.getExportDir();
    if (dir == null) {
      await _pickDir();
      dir = await settingsProvider.getExportDir();
      if (dir == null) {
        if (mounted) setState(() => _error = 'No export folder set.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final export = await skBuildExport(
        appsProvider: appsProvider,
        settingsProvider: settingsProvider,
        skUiProvider: skUiProvider,
        cats: cats,
      );
      final name = skExportFileName();
      final result = await saf.createFile(
        dir,
        displayName: name,
        mimeType: 'application/json',
        bytes: utf8.encode(const JsonEncoder.withIndent('  ').convert(export)),
      );
      if (result == null) throw 'could not create the file in the folder';
      if (!mounted) return;
      setState(() => _busy = false);
      await _showResultDialog(
        title: '✓ Export finished',
        body: 'Exported:\n$name',
        buttons: const [('OK', 'ok')],
      );
      // Acknowledged → close the chain (panel now, UI page by the caller).
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Export failed: $e';
        });
      }
    }
  }

  Future<void> _import() async {
    final cats = _selected();
    if (cats.isEmpty) {
      setState(() => _error = 'No categories selected.');
      return;
    }
    final appsProvider = context.read<AppsProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final skUiProvider = context.read<SkUiProvider>();
    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles();
    } catch (e) {
      if (mounted) setState(() => _error = 'No file picker available.');
      return;
    }
    final path = (picked != null && picked.files.isNotEmpty)
        ? picked.files.single.path
        : null;
    if (path == null) return; // cancelled — leave the panel open
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final decoded = jsonDecode(await File(path).readAsString());
      if (decoded is! Map<String, dynamic>) throw 'not a JSON object';
      final summary = await skApplyImport(
        decoded: decoded,
        cats: cats,
        appsProvider: appsProvider,
        settingsProvider: settingsProvider,
        skUiProvider: skUiProvider,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      final action = await _showResultDialog(
        title: '✓ Import finished',
        body: 'Restored:\n\n$summary\n\nRestart to apply everything.',
        buttons: const [('Later', 'later'), ('Restart now', 'restart')],
      );
      if (action == 'restart') {
        await skRestartApp();
        return;
      }
      // "Later" → close the chain (panel now, UI page by the caller).
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Import failed: $e';
        });
      }
    }
  }

  /// The black, yellow-bordered info dialog (Export/Import finished).
  Future<String?> _showResultDialog({
    required String title,
    required String body,
    required List<(String, String)> buttons,
  }) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(color: accent),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Spacer(),
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    SkPillButton(
                      buttons[i].$1,
                      onPressed: () => Navigator.of(ctx).pop(buttons[i].$2),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkRow(
    String label, {
    required bool value,
    required ValueChanged<bool> onChanged,
    bool bold = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _busy ? null : () => onChanged(!value),
      child: Row(
        children: [
          Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            onChanged: _busy ? null : (v) => onChanged(v == true),
          ),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final dim = accent.withValues(alpha: 0.78);
    final st = _status;
    final divider = Container(height: 1, color: accent.withValues(alpha: 0.4));
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent, width: 2),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Export / Import — 白い熊 獲得',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save or restore everything by category — the tracked apps '
              'and their sources, settings, credentials, categories, and '
              'the 白い熊 獲得 UI.',
              style: theme.textTheme.bodySmall?.copyWith(color: dim),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _busy ? null : _pickDir,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export folder (tap to choose)',
                      style: theme.textTheme.bodySmall?.copyWith(color: dim),
                    ),
                    Text(
                      st == null
                          ? '…'
                          : (st.dirName ?? 'Not set — tap to choose a folder'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: (st?.dirSet ?? true) ? accent : skWarnRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (st != null)
              Text(
                st.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: st.dirSet ? accent : skWarnRed,
                ),
              ),
            const SizedBox(height: 10),
            divider,
            _checkRow(
              'Select all',
              bold: true,
              value: _selectAll,
              onChanged: (v) => setState(() {
                _selectAll = v;
                for (final c in SkExportCat.values) {
                  _checked[c] = v;
                }
              }),
            ),
            for (final cat in SkExportCat.values)
              _checkRow(
                cat.label,
                value: _checked[cat] ?? false,
                onChanged: (v) => setState(() => _checked[cat] = v),
              ),
            divider,
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: skWarnRed),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                SkPillButton(
                  'Cancel',
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
                const Spacer(),
                SkPillButton('Import', onPressed: _busy ? null : _import),
                const SizedBox(width: 8),
                SkPillButton('Export', onPressed: _busy ? null : _export),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
