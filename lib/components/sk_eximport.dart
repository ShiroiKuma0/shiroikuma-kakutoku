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

import 'package:archive/archive.dart';
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

/// v1 = single JSON file (pre-2026-07-25). v2 = the family ZIP: `manifest.json`
/// plus one `<category id>.json` per exported category.
const int skExportVersion = 2;

/// The mandatory family file-name stem (白い熊, 2026-07-25): every backup this
/// app writes — from the Export/Import panel and from the 保存復元 automation
/// path alike — is `shiroikuma-kakutoku_<yyyy-MM-dd_HH-mm-ss>.zip`. No version,
/// no infix, no suffix: all sister apps' backups share one directory and must
/// sort and read uniformly.
const String skExportPrefix = 'shiroikuma-kakutoku_';

/// The v1 file-name stem, still recognised when looking for the latest export
/// so backups written before the rename stay visible.
const String skLegacyExportPrefix = 'shiroikuma-kakutoku-';

/// The archive entry carrying the export's metadata.
const String skManifestEntry = 'manifest.json';

/// A selectable export/import category. `id` is the key inside the export
/// JSON's `data` map. Order = display order (sources first).
///
/// [defaultSelected] is this app STATING whether an item starts ticked rather
/// than letting a picker guess: it seeds the Export/Import panel's checkboxes
/// and rides out as the fourth `on|off` field of the `LIST_CATEGORIES` reply,
/// so 保存復元's item editor opens on the same answer. Everything this app
/// exports is small and not re-creatable, so every category is `on`; the flag
/// exists so a future large-derived-regenerable category can say otherwise
/// without the contract having to change again.
enum SkExportCat {
  sources('sources', 'Sources (tracked apps)'),
  appSettings('appSettings', 'App settings'),
  creds('creds', 'Source credentials'),
  categories('categories', 'Categories'),
  skUi('skUi', '白い熊 獲得 UI (colors · fonts · sizes)');

  // No category passes `off` today — that is the point of the audit above,
  // not an oversight — so the analyzer sees an optional parameter nobody
  // supplies. It stays because the alternative is changing this contract
  // again the first time a category should start unticked.
  // ignore: unused_element_parameter
  const SkExportCat(this.id, this.label, {this.defaultSelected = true});
  final String id;
  final String label;
  final bool defaultSelected;
}

/// The categories that start ticked — what an automation request with no
/// `items` extra means, and what the Export/Import panel opens on.
Set<SkExportCat> skDefaultCats() =>
    SkExportCat.values.where((c) => c.defaultSelected).toSet();

/// Settings keys that live in the shared prefs file but belong to another
/// category (or are device-local) and must not ride along in "App settings".
const Set<String> _appSettingsExclude = {'exportDir', 'categories'};

bool _isCredKey(String k) => k.endsWith('-creds');
bool _isSkUiKey(String k) => k == 'skUiKnobs' || k == 'skUiRecentColors';

/// The 保存復元 automation switch and token (`skAutomationEnabled`,
/// `skAutomationToken`) are device-local secrets: the token must never travel
/// in a backup ZIP, so the whole `skAutomation*` namespace stays out of the
/// "App settings" prefs dump.
bool _isAutomationKey(String k) => k.startsWith('skAutomation');

String _pad2(int n) => n.toString().padLeft(2, '0');

String skTimestamp([DateTime? at]) {
  final now = at ?? DateTime.now();
  return '${now.year}-${_pad2(now.month)}-${_pad2(now.day)}'
      '_${_pad2(now.hour)}-${_pad2(now.minute)}-${_pad2(now.second)}';
}

String skExportFileName([DateTime? at]) => '$skExportPrefix${skTimestamp(at)}.zip';

/// Byte count for display (`4.6 MB`, `1.20 GB`) — the automation caller cannot
/// stat the file, so this app computes it.
String skHumanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

/// Progress while exporting: real counts, never a percentage.
typedef SkExportProgress =
    void Function(int current, int total, String unit, String text);

/// Asked between entries: true = unwind at this boundary.
typedef SkCancelProbe = bool Function();

/// Thrown out of [skBuildExportZip] when a [SkCancelProbe] goes true. The
/// export unwinds at an entry boundary — never mid-`write()`, never by
/// interrupting a thread or killing the process.
class SkExportCancelled implements Exception {
  const SkExportCancelled();
  @override
  String toString() => 'cancelled';
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

/// The timestamp our export filenames embed — both the current family name
/// ("shiroikuma-kakutoku_2026-07-25_18-58-23.zip") and the v1 one it replaced
/// ("shiroikuma-kakutoku-1.6.10+7-export_2026-07-25_11-17-35.json").
final RegExp _exportTsRe = RegExp(
  r'_(\d{4}-\d{2}-\d{2})_(\d{2})-(\d{2})-(\d{2})\.(?:zip|json)$',
);

/// The `yyyy-MM-dd HH:mm:ss` stamp of one of our exports, or null if [name] is
/// not one of them.
String? skExportStamp(String name) {
  if (!name.startsWith(skExportPrefix) &&
      !name.startsWith(skLegacyExportPrefix)) {
    return null;
  }
  final m = _exportTsRe.firstMatch(name);
  if (m == null) return null;
  return '${m.group(1)} ${m.group(2)}:${m.group(3)}:${m.group(4)}';
}

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
      final ts = skExportStamp(name);
      if (ts == null) continue;
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

/// Builds one category's payload — the object stored as `<id>.json` inside the
/// export ZIP (and as `data[<id>]` in a v1 export). [onProgress] reports the
/// countable work inside the category (apps, fonts).
Future<Object?> skBuildCategory(
  SkExportCat cat, {
  required AppsProvider appsProvider,
  required SettingsProvider settingsProvider,
  required SkUiProvider skUiProvider,
  SkExportProgress? onProgress,
}) async {
  switch (cat) {
    case SkExportCat.sources:
      await appsProvider.waitForAppsToLoad();
      final tracked = appsProvider.apps.values.toList();
      final apps = <Map<String, dynamic>>[];
      for (var i = 0; i < tracked.length; i++) {
        apps.add(tracked[i].app.toJson());
        onProgress?.call(
          i + 1,
          tracked.length,
          'アプリ',
          'アプリ ${i + 1}/${tracked.length}',
        );
      }
      return {'apps': apps};
    case SkExportCat.appSettings:
      final m = <String, Object?>{};
      for (final k in settingsProvider.prefs?.getKeys() ?? <String>{}) {
        if (_appSettingsExclude.contains(k) ||
            _isCredKey(k) ||
            _isSkUiKey(k) ||
            _isAutomationKey(k)) {
          continue;
        }
        m[k] = settingsProvider.prefs?.get(k);
      }
      return m;
    case SkExportCat.creds:
      final m = <String, Object?>{};
      for (final k in settingsProvider.prefs?.getKeys() ?? <String>{}) {
        if (_isCredKey(k)) m[k] = settingsProvider.prefs?.get(k);
      }
      return m;
    case SkExportCat.categories:
      return settingsProvider.categories;
    case SkExportCat.skUi:
      final files = await skUiProvider.fontFiles();
      final fonts = <String, String>{};
      for (var i = 0; i < files.length; i++) {
        fonts[files[i].path.split('/').last] = base64Encode(
          await files[i].readAsBytes(),
        );
        onProgress?.call(
          i + 1,
          files.length,
          'フォント',
          'フォント ${i + 1}/${files.length}',
        );
      }
      return {
        'knobs': skUiProvider.knobs.toJson(),
        'recentColors': skUiProvider.recentColors
            .map((c) => c.toARGB32())
            .toList(),
        'fonts': fonts,
      };
  }
}

/// Builds the whole backup for [cats] as ONE ZIP — `manifest.json` plus one
/// `<category id>.json` per category. This is the single export core: the
/// Export/Import panel and the 保存復元 automation receiver are both thin
/// callers, so a headless export is a normal, restorable backup.
Future<Uint8List> skBuildExportZip({
  required AppsProvider appsProvider,
  required SettingsProvider settingsProvider,
  required SkUiProvider skUiProvider,
  required Set<SkExportCat> cats,
  SkExportProgress? onProgress,
  SkCancelProbe? isCancelled,
}) async {
  // Declaration order, so the ZIP's entries and the manifest always agree
  // regardless of how the caller built the set.
  final ordered = SkExportCat.values.where(cats.contains).toList();
  final entries = <ArchiveFile>[];
  for (var i = 0; i < ordered.length; i++) {
    if (isCancelled?.call() ?? false) throw const SkExportCancelled();
    final cat = ordered[i];
    onProgress?.call(
      i + 1,
      ordered.length,
      '区分',
      '区分 ${i + 1}/${ordered.length} — ${cat.label}',
    );
    final payload = await skBuildCategory(
      cat,
      appsProvider: appsProvider,
      settingsProvider: settingsProvider,
      skUiProvider: skUiProvider,
      onProgress: onProgress,
    );
    entries.add(ArchiveFile.string('${cat.id}.json', jsonEncode(payload)));
  }
  // The last boundary before the one long synchronous stretch (encodeBytes)
  // and the write that follows it.
  if (isCancelled?.call() ?? false) throw const SkExportCancelled();
  final manifest = {
    'format': skExportFormat,
    'version': skExportVersion,
    'app': obtainiumId,
    'appVersion': kPackageVersion,
    'createdTs': DateTime.now().toIso8601String(),
    'categories': ordered.map((c) => c.id).toList(),
  };
  final archive = Archive()
    ..add(
      ArchiveFile.string(
        skManifestEntry,
        const JsonEncoder.withIndent('  ').convert(manifest),
      ),
    );
  for (final e in entries) {
    archive.add(e);
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Reads one of our export files — the family ZIP, or a v1 single JSON — into
/// the `{format, version, data}` shape [skApplyImport] consumes.
Future<Map<String, dynamic>> skReadExportFile(String path) async =>
    skDecodeExportBytes(await File(path).readAsBytes());

/// The same decode, from bytes that never touched the filesystem.
///
/// The 応用管理 data door hands this app an archive through a
/// `ParcelFileDescriptor` the CALLER opened — never a path, because a backup is
/// not a stable directory while it is being assembled, and a file this app
/// dropped in itself would be neither encrypted nor checksummed by the caller
/// that owns the archive. So the restore path has bytes and no file, and this
/// is where they enter.
Map<String, dynamic> skDecodeExportBytes(Uint8List bytes) {
  final isZip = bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  if (!isZip) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) throw 'not a JSON object';
    return decoded;
  }
  final archive = ZipDecoder().decodeBytes(bytes);
  final manifestEntry = archive.findFile(skManifestEntry);
  if (manifestEntry == null) {
    throw 'not a 白い熊 獲得 export (no $skManifestEntry in the ZIP)';
  }
  final manifest = jsonDecode(
    utf8.decode(manifestEntry.readBytes() ?? const []),
  );
  if (manifest is! Map<String, dynamic>) throw 'corrupt $skManifestEntry';
  final data = <String, dynamic>{};
  for (final cat in SkExportCat.values) {
    final entry = archive.findFile('${cat.id}.json');
    if (entry == null) continue;
    data[cat.id] = jsonDecode(utf8.decode(entry.readBytes() ?? const []));
  }
  return {...manifest, 'data': data};
}

/// Applies one imported preference, AWAITING the write.
///
/// The await matters because of what follows an import: the panel restarts the
/// app and the automation data door is force-stopped the moment it reports
/// success, so a write still in flight is a write that never happened. The
/// String branch stays fire-and-forget because `setSettingString` is upstream's
/// and also notifies listeners; [skFlushSettingsWrites] is what covers it, and
/// everything else on this path that drops its Future.
Future<void> _applyPref(SettingsProvider sp, String k, dynamic v) async {
  if (v is bool) {
    await sp.prefs?.setBool(k, v);
  } else if (v is int) {
    await sp.prefs?.setInt(k, v);
  } else if (v is double) {
    await sp.prefs?.setDouble(k, v);
  } else if (v is List) {
    await sp.prefs?.setStringList(k, v.whereType<String>().toList());
  } else if (v is String) {
    sp.setSettingString(k, v);
  }
}

/// Waits for every preference write an import issued to actually land.
///
/// **Both callers of [skApplyImport] are followed immediately by the process
/// ending**: the Export/Import panel restarts the app, and 白い熊 応用管理
/// force-stops it the instant the data door replies `OK` — a SIGKILL, not an
/// orderly shutdown. Anything still in flight is simply lost, and a restore
/// then reports success over data that never arrived, which is the one failure
/// worse than a restore that refused.
///
/// Several writes on this path are fire-and-forget by construction and not ours
/// to change: `SettingsProvider.setSettingString`, `SettingsProvider.setCategories`
/// and `SkUiProvider.save()` all drop the Future `shared_preferences` hands
/// them. So the flush is a final awaited round trip on the SAME channel — the
/// platform handles one channel's messages in order and the Android side
/// commits each write synchronously (`SharedPreferences.Editor.commit()`), so
/// when this answers, everything sent before it is on disk. `reload()` rather
/// than a dummy write because it also reads back what actually landed, leaving
/// the in-memory cache agreeing with the file instead of with our intent.
///
/// The file writes on this path — the app JSONs and imported fonts — are
/// already awaited, and their bytes survive a SIGKILL in the page cache; it is
/// only the preference channel that needs draining.
///
/// Audited 2026-09-04: neither `SettingsProvider` nor `SkUiProvider` debounces
/// its writes, so there is no timer to wait out first. **If one is ever added,
/// it has to be awaited here** — a debounce means the store has not even been
/// asked to write at the moment this returns.
Future<void> skFlushSettingsWrites(SettingsProvider sp) async {
  await sp.prefs?.reload();
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
        // A `for` rather than `forEach`: the writes are awaited now, and
        // `forEach` cannot await its callback — it would return with every
        // write still outstanding, which is the bug this is here to prevent.
        for (final e in (d as Map<String, dynamic>).entries) {
          await _applyPref(settingsProvider, e.key, e.value);
          n++;
        }
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
  // Written is not landed. Nobody is told this succeeded until it has.
  await skFlushSettingsWrites(settingsProvider);
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
  // Seeded from the categories' own default, so this sheet and the 保存復元
  // item editor (which reads the same flag off `LIST_CATEGORIES`) open on the
  // same answer.
  final Map<SkExportCat, bool> _checked = {
    for (final c in SkExportCat.values) c: c.defaultSelected,
  };
  bool _selectAll = SkExportCat.values.every((c) => c.defaultSelected);
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
      final bytes = await skBuildExportZip(
        appsProvider: appsProvider,
        settingsProvider: settingsProvider,
        skUiProvider: skUiProvider,
        cats: cats,
      );
      final name = skExportFileName();
      final result = await saf.createFile(
        dir,
        displayName: name,
        mimeType: 'application/zip',
        bytes: bytes,
      );
      if (result == null) throw 'could not create the file in the folder';
      if (!mounted) return;
      setState(() => _busy = false);
      await _showResultDialog(
        title: '✓ Export finished',
        body:
            'Exported:\n$name\n'
            '${cats.length} categories · ${skHumanSize(bytes.length)}',
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
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile();
    } catch (e) {
      if (mounted) setState(() => _error = 'No file picker available.');
      return;
    }
    final path = picked?.path;
    if (path == null) return; // cancelled — leave the panel open
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final decoded = await skReadExportFile(path);
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
