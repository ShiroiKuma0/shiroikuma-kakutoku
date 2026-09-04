// shiroikuma-kakutoku fork: the 保存復元 state-export automation contract.
//
// 白い熊's automation app 自由作業盤 backs up every sister app in one run: it
// fires a token-gated broadcast at each app, the app exports itself headlessly,
// reports progress with real counts, and replies with the written path and
// size. This file is this app's end of that wire:
//
//   * [SkAutomation] — the device-local switches: automation ON by default,
//     an OPT-IN token that is only consulted when 白い熊 asks for one.
//   * [skAutomationMain] — the headless Dart entrypoint the native
//     StateExportReceiver boots into a plain FlutterEngine (no Activity).
//   * [skAutomationDataMain] — the same trick for the v2 data door: the
//     entrypoint AutomationDataService boots to export this app's backup into
//     a descriptor 応用管理 opened, and to put one back on a wiped phone.
//
// The export itself is NOT reimplemented here: `sk_eximport.dart` holds the one
// export core, and the Export/Import panel and this receiver are its two thin
// callers, so a headless export is a normal, restorable backup.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:obtainium/components/sk_eximport.dart';
import 'package:obtainium/providers/apps_provider.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_storage/shared_storage.dart' as saf;

/// Device-local prefs keys. Everything under the `skAutomation` prefix is kept
/// out of the export (see `_isAutomationKey` in `sk_eximport.dart`) — the token
/// must never travel in a backup ZIP.
const String skAutomationEnabledKey = 'skAutomationEnabled';
const String skAutomationRequireTokenKey = 'skAutomationRequireToken';
const String skAutomationTokenKey = 'skAutomationToken';

/// The method channel shared with `StateExportReceiver.kt`.
const String skAutomationChannel = 'dev.imranr.obtainium/sk_automation';

/// The method channel shared with `AutomationDataService.kt` — the v2 data
/// door. Its own channel and entrypoint, deliberately: the §1 broadcast path
/// above is EMUI-proven and is not disturbed to make room for this one.
const String skAutomationDataChannel = 'dev.imranr.obtainium/sk_automation_data';

/// This app's display label, sent with every progress broadcast so 自由作業盤
/// can name the app it is currently waiting on.
const String skAppLabel = '白い熊 獲得';

/// The automation gate: a switch that ships ON, and a token that is OFF until
/// 白い熊 asks for one.
///
/// **v2 (2026-09-04) inverted both defaults, and the reason is the whole point
/// of the change.** v1 shipped every app closed: the switch was off and a
/// caller also had to present a 48-character secret pasted from this app's
/// settings into the caller's. A pasted secret cannot survive a wipe — and the
/// case this family exists to serve is 応用管理 restoring apps *and their data*
/// onto a clean phone, where nothing has been configured and nobody has pasted
/// anything. A gate that only works once the phone is already set up is no gate
/// for setting the phone up.
///
/// This class is the AUTHORITATIVE gate: it owns the keys, and the Export /
/// Import rows on the 白い熊 獲得 UI page write them. `SkAutomationGate.kt`
/// mirrors it natively for the data door, which must answer inside a binder
/// call and cannot boot an engine to ask. **Change a key or a default here and
/// change it there** — that file says the same thing back.
class SkAutomation {
  /// v2 default **ON**: every app answers automation out of the box, so a
  /// freshly restored phone is already on the 保存復元 batch. It stays a switch
  /// because it is the only way to close this one app off.
  static bool isEnabled(SharedPreferences prefs) =>
      prefs.getBool(skAutomationEnabledKey) ?? true;

  static Future<void> setEnabled(SharedPreferences prefs, bool value) =>
      prefs.setBool(skAutomationEnabledKey, value);

  /// v2 default **OFF**: the token is an extra a caller may be asked for, not
  /// the gate. Off means any sister app may drive the automation; the data door
  /// checks the caller's package, uid and signing certificate either way.
  static bool requiresToken(SharedPreferences prefs) =>
      prefs.getBool(skAutomationRequireTokenKey) ?? false;

  static Future<void> setRequireToken(SharedPreferences prefs, bool value) =>
      prefs.setBool(skAutomationRequireTokenKey, value);

  /// The stored token, generated on first read so the settings row always
  /// shows a value.
  static String token(SharedPreferences prefs) {
    final existing = prefs.getString(skAutomationTokenKey);
    if (existing != null && existing.isNotEmpty) return existing;
    return regenerate(prefs);
  }

  /// A fresh token: 24 bytes from the platform's cryptographic RNG, hex-encoded.
  static String regenerate(SharedPreferences prefs) {
    final rnd = Random.secure();
    final token = List<int>.generate(
      24,
      (_) => rnd.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    unawaited(prefs.setString(skAutomationTokenKey, token));
    return token;
  }

  /// `80922d8c…4c49a87c` — what the settings row shows. The full value only
  /// ever leaves the app through the clipboard.
  static String abbreviate(String token) => token.length <= 20
      ? token
      : '${token.substring(0, 8)}…${token.substring(token.length - 8)}';

  /// null when the request may proceed, otherwise the exact `ERROR:` line to
  /// answer with. Both checks live in this ONE function: two of them written
  /// out at each entry point is how "disabled" and "bad token" drift apart
  /// across forty-two apps. The two stay distinct as answers because they
  /// debug differently.
  ///
  /// **A token handed to an app that does not require one is IGNORED. It is
  /// never an error.** Tokens live in task arguments and workspace variables
  /// that outlive the setting they were pasted for, and a caller still sending
  /// one — because it was configured last year, or because another app on the
  /// batch does want one — must be served. Refusing it would turn "白い熊
  /// turned a switch off" into "half the batch mysteriously fails", which is
  /// precisely the friction the switch exists to remove.
  static String? refuse(SharedPreferences prefs, String? candidate) {
    if (!isEnabled(prefs)) return 'ERROR:automation disabled';
    if (!requiresToken(prefs)) return null;
    final stored = prefs.getString(skAutomationTokenKey);
    if (stored == null || stored.isEmpty) return 'ERROR:bad token';
    if (candidate == null || candidate.isEmpty) return 'ERROR:bad token';
    // Constant-time compare stays for the case where the token IS required.
    return _constantTimeEquals(candidate, stored) ? null : 'ERROR:bad token';
  }

  /// Compares in constant time — no early exit on the first differing byte.
  static bool _constantTimeEquals(String a, String b) {
    final x = utf8.encode(a);
    final y = utf8.encode(b);
    var diff = x.length ^ y.length;
    final n = x.length < y.length ? x.length : y.length;
    for (var i = 0; i < n; i++) {
      diff |= x[i] ^ y[i];
    }
    return diff == 0;
  }
}

/// The `LIST_CATEGORIES` reply: `OK:` followed by one
/// `id<TAB>label<TAB>parent<TAB>on|off` line per exportable category. The ids
/// are exactly the ones accepted in `items`, and they are the ZIP's entry-name
/// stems.
///
/// The list is flat — no category of this app has separately selectable parts
/// — so the third (parent) field is always EMPTY, which the positional format
/// still requires so that the fourth field lands where it belongs. That fourth
/// field is this app stating whether the item starts ticked in 保存復元's
/// picker instead of the picker assuming it; see [SkExportCat.defaultSelected].
String skCategoriesReply() => 'OK:${SkExportCat.values.map((c) {
  final on = c.defaultSelected ? 'on' : 'off';
  return '${c.id}\t${c.label}\t\t$on';
}).join('\n')}';

/// Resolves an `items` list into categories.
///
/// Absent or empty means this app's **default set** — the ones it reports as
/// `on` from `LIST_CATEGORIES`, which is not the same as everything. null means
/// the list named something this app does not export, which is an error the
/// caller must see rather than a backup quietly missing a category.
///
/// Both doors resolve `items` through here: the §1 broadcast export and the
/// §2a data door must agree on what a caller asked for.
Set<SkExportCat>? skResolveCats(String? raw) {
  final itemsRaw = raw?.trim() ?? '';
  if (itemsRaw.isEmpty) return skDefaultCats();
  final byId = {for (final c in SkExportCat.values) c.id: c};
  final picked = <SkExportCat>{};
  for (final entry in itemsRaw.split(',')) {
    final id = entry.trim();
    if (id.isEmpty) continue;
    final cat = byId[id];
    if (cat == null) return null;
    picked.add(cat);
  }
  return picked.isEmpty ? null : picked;
}

/// The `reply_id` of the export running right now, or null when none is. Two
/// exports at once are forbidden by the contract, so one slot is enough — the
/// id only narrows WHICH run a `CANCEL_EXPORT` may target.
String? _runningExportReplyId;

/// Set by [skHandleCancel]; the export reads it at every entry boundary and on
/// both sides of the write. Reset when an export starts, so a stale cancel can
/// never kill the next run.
bool _exportCancelled = false;

/// Handles a `CANCEL_EXPORT`. Token-gated exactly like every other request,
/// and otherwise a **silent no-op**: nothing running, an id for a different
/// run, or an export that already finished all return without a reply, without
/// an error and without a crash. The cancel action answers nothing — the
/// terminal `ERROR:cancelled` belongs to the ORIGINAL request and is sent by
/// [_export] through the normal reply channel.
Future<bool> skHandleCancel(Map<String, Object?> request) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (SkAutomation.refuse(prefs, request['token'] as String?) != null) {
      return false;
    }
    final running = _runningExportReplyId;
    if (running == null) return false;
    final target = (request['reply_id'] as String?)?.trim() ?? '';
    if (target.isNotEmpty && target != running) return false;
    _exportCancelled = true;
    return true;
  } catch (_) {
    return false;
  }
}

/// Throttles progress broadcasts to at most one every 500 ms, with a forced
/// final one at completion.
class _ProgressSink {
  _ProgressSink(this._send);

  final void Function(Map<String, Object?>) _send;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void report(
    int current,
    int total,
    String unit,
    String text, {
    bool force = false,
  }) {
    final now = DateTime.now();
    if (!force && now.difference(_last).inMilliseconds < 500) return;
    _last = now;
    _send({
      'app': skAppLabel,
      'text': text,
      'current': current,
      'total': total,
      'unit': unit,
    });
  }
}

/// The headless entrypoint. `StateExportReceiver.kt` runs this in its own
/// FlutterEngine, then dispatches each request over [skAutomationChannel] and
/// waits for the returned one-line result.
@pragma('vm:entry-point')
void skAutomationMain() {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(skAutomationChannel);
  channel.setMethodCallHandler((call) async {
    // `cancel` deliberately BYPASSES the one-at-a-time `handle` queue: a
    // cancel that waited its turn behind the export it is meant to stop would
    // never arrive.
    if (call.method == 'cancel') {
      return skHandleCancel(Map<String, Object?>.from(call.arguments as Map));
    }
    if (call.method != 'handle') return null;
    final request = Map<String, Object?>.from(call.arguments as Map);
    final replyId = request['reply_id'] as String? ?? '';
    return skHandleAutomationRequest(request, (progress) {
      unawaited(
        channel.invokeMethod('progress', {'reply_id': replyId, ...progress}),
      );
    });
  });
  unawaited(channel.invokeMethod('ready'));
}

/// Handles one request and returns its `result` line. Never throws: every
/// failure comes back as a one-line `ERROR:…` so the caller always gets an
/// answer.
Future<String> skHandleAutomationRequest(
  Map<String, Object?> request,
  void Function(Map<String, Object?>) sendProgress,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    // The engine outlives a single request and the UI runs in its own engine,
    // so re-read the switch and token from disk on every request.
    await prefs.reload();
    final denied = SkAutomation.refuse(prefs, request['token'] as String?);
    if (denied != null) return denied;
    switch (request['action']) {
      case 'categories':
        return skCategoriesReply();
      case 'export':
        return await _export(request, sendProgress);
      default:
        return 'ERROR:unknown action';
    }
  } catch (e) {
    return 'ERROR:${_oneLine(e.toString())}';
  }
}

/// Runs the app's own export headlessly and writes exactly ONE ZIP.
///
/// Owns the cancel bookkeeping: the running `reply_id` is published for
/// `CANCEL_EXPORT` for exactly as long as this run lasts, and a cancel landing
/// anywhere inside it unwinds to the one terminal `ERROR:cancelled` — sent
/// through the normal reply channel, under the receiver's existing
/// one-reply-per-request guard, so it can never double-fire with a success.
Future<String> _export(
  Map<String, Object?> request,
  void Function(Map<String, Object?>) sendProgress,
) async {
  _runningExportReplyId = (request['reply_id'] as String?) ?? '';
  _exportCancelled = false;
  try {
    return await _exportInner(request, sendProgress);
  } on SkExportCancelled {
    return 'ERROR:cancelled';
  } finally {
    _runningExportReplyId = null;
    _exportCancelled = false;
  }
}

Future<String> _exportInner(
  Map<String, Object?> request,
  void Function(Map<String, Object?>) sendProgress,
) async {
  // ---- items: which categories (absent/empty = this app's default set) ----
  final itemsRaw = (request['items'] as String?)?.trim() ?? '';
  final cats = skResolveCats(itemsRaw);
  if (cats == null) return 'ERROR:unknown category in items: $itemsRaw';

  // ---- destination: `path` extra → the configured export folder → error ----
  final settingsProvider = SettingsProvider();
  await settingsProvider.initializeSettings();
  Uri? safDir;
  try {
    safDir = await settingsProvider.getExportDir();
  } catch (_) {
    safDir = null;
  }
  var pathExtra = (request['path'] as String?)?.trim() ?? '';
  while (pathExtra.length > 1 && pathExtra.endsWith('/')) {
    pathExtra = pathExtra.substring(0, pathExtra.length - 1);
  }
  String? directDir;
  if (pathExtra.isNotEmpty) {
    if (await _canWriteDirectly(pathExtra)) {
      directDir = pathExtra;
    } else if (safDir == null) {
      // No All-files access and nowhere else to put it.
      return 'ERROR:no-storage-access';
    }
    // Otherwise: fall back to the configured folder, ignoring `path`.
  } else if (safDir == null) {
    return 'ERROR:no-directory';
  }

  // ---- build the ZIP ----
  if (_exportCancelled) throw const SkExportCancelled();
  final appsProvider = AppsProvider(
    isBg: true,
    settingsProvider: settingsProvider,
  );
  await appsProvider.loadApps();
  final skUiProvider = SkUiProvider();
  await skUiProvider.initializeWithoutFonts();
  final progress = _ProgressSink(sendProgress);
  final bytes = await skBuildExportZip(
    appsProvider: appsProvider,
    settingsProvider: settingsProvider,
    skUiProvider: skUiProvider,
    cats: cats,
    onProgress: progress.report,
    isCancelled: () => _exportCancelled,
  );

  // ---- write it, once ----
  //
  // This app has no `.part` file to sweep up: the ZIP is built whole in memory
  // and handed to the filesystem in a single call. The equivalent promise —
  // that a cancelled export leaves the backup folder EXACTLY as it found it —
  // is kept by not writing at all once cancelled, and by removing the file
  // again if the cancel landed while those bytes were going out.
  final name = skExportFileName();
  if (_exportCancelled) throw const SkExportCancelled();
  final String writtenPath;
  if (directDir != null) {
    final file = File('$directDir/$name');
    await file.writeAsBytes(bytes, flush: true);
    if (_exportCancelled) {
      try {
        await file.delete();
      } catch (_) {
        // Nothing better to do — the cancel reply still stands.
      }
      throw const SkExportCancelled();
    }
    writtenPath = file.path;
  } else {
    final created = await saf.createFile(
      safDir!,
      displayName: name,
      mimeType: 'application/zip',
      bytes: bytes,
    );
    if (created == null) {
      return 'ERROR:could not write to the configured export folder';
    }
    if (_exportCancelled) {
      try {
        await saf.delete(created.uri);
      } catch (_) {
        // Nothing better to do — the cancel reply still stands.
      }
      throw const SkExportCancelled();
    }
    final dirPath = _absolutePathForTreeUri(safDir);
    writtenPath = dirPath == null
        ? created.uri.toString()
        : '$dirPath/${created.name ?? name}';
  }
  final size = skHumanSize(bytes.length);
  progress.report(
    cats.length,
    cats.length,
    '区分',
    '区分 ${cats.length}/${cats.length} — 書き込み完了 ($size)',
    force: true,
  );
  return 'OK:$writtenPath|${bytes.length}|$size|${cats.length} categories';
}

/// True when this app may write [dir] with plain `java.io.File` — i.e. it holds
/// All-files access. Probes for real rather than trusting a permission flag.
Future<bool> _canWriteDirectly(String dir) async {
  try {
    final directory = Directory(dir);
    if (!await directory.exists()) await directory.create(recursive: true);
    final probe = File('${directory.path}/.kakutoku-write-probe');
    await probe.writeAsBytes(const [0], flush: true);
    await probe.delete();
    return true;
  } catch (_) {
    return false;
  }
}

/// Best-effort filesystem path behind a SAF tree URI, so the reply can name an
/// absolute path instead of a `content://` URI. Returns null for providers
/// whose document ids do not map to storage volumes.
String? _absolutePathForTreeUri(Uri treeUri) {
  final segments = treeUri.pathSegments;
  final i = segments.indexOf('tree');
  if (i < 0 || i + 1 >= segments.length) return null;
  final documentId = segments[i + 1];
  final colon = documentId.indexOf(':');
  if (colon < 0) return null;
  final volume = documentId.substring(0, colon);
  final relative = documentId.substring(colon + 1);
  final root = volume == 'primary' ? '/storage/emulated/0' : '/storage/$volume';
  return relative.isEmpty ? root : '$root/$relative';
}

/// `result` is one line — collapse anything multi-line an error carried.
String _oneLine(String s) {
  final flat = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= 300 ? flat : '${flat.substring(0, 297)}…';
}

// ---------------------------------------------------------------------------
// §2a — the data door: this app's backup through a descriptor 応用管理 opened
// ---------------------------------------------------------------------------
//
// The native half is `android/app/src/main/kotlin/dev/imranr/obtainium/
// automation/` — a ContentProvider that identifies its caller by exact package
// name, uid and pinned signing certificate, and a foreground service that moves
// the bytes. This is the Dart half: the same export core as everything else,
// and the import the broadcast contract deliberately does NOT expose.
//
// **The gate is not re-checked here.** `AutomationProvider.call()` has already
// run it — natively, through `SkAutomationGate`, because it must answer inside
// a binder call — and nothing reaches this entrypoint without passing it.

/// The data-door job running right now, or null when none is.
String? _dataJobId;

/// Set when the service relays a `cancel`. The export reads it at every entry
/// boundary, so it unwinds between files rather than mid-write.
bool _dataCancelled = false;

/// The headless entrypoint `AutomationDataService.kt` boots.
///
/// Its own entrypoint and channel rather than [skAutomationMain]'s: the §1
/// broadcast path is EMUI-proven and is not disturbed to make room for this.
@pragma('vm:entry-point')
void skAutomationDataMain() {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(skAutomationDataChannel);
  channel.setMethodCallHandler((call) async {
    final args = call.arguments is Map
        ? Map<String, Object?>.from(call.arguments as Map)
        : <String, Object?>{};
    switch (call.method) {
      case 'cancel':
        return _dataCancel(args);
      case 'export':
        return skAutomationDataExport(args, (progress) {
          unawaited(
            channel.invokeMethod('progress', {
              'job_id': args['job_id'],
              ...progress,
            }),
          );
        });
      case 'import':
        return skAutomationDataImport(args);
      default:
        return null;
    }
  });
  unawaited(channel.invokeMethod('ready'));
}

/// A cancel for the data door. Silent no-op when nothing is running or the id
/// belongs to another job — a cancel arriving after the work finished is the
/// normal race, not an error.
bool _dataCancel(Map<String, Object?> request) {
  final running = _dataJobId;
  if (running == null) return false;
  final target = (request['job_id'] as String?)?.trim() ?? '';
  if (target.isNotEmpty && target != running) return false;
  _dataCancelled = true;
  return true;
}

/// Builds this app's backup and hands the bytes back for the service to write
/// into the caller's descriptor.
///
/// Answers a map rather than a result line because the payload travels with it:
/// `{bytes, categories}` on success, `{error}` on anything else. Never throws —
/// the service must always have something to reply.
Future<Map<String, Object?>> skAutomationDataExport(
  Map<String, Object?> request,
  void Function(Map<String, Object?>) sendProgress,
) async {
  _dataJobId = (request['job_id'] as String?) ?? '';
  _dataCancelled = false;
  try {
    final itemsRaw = (request['items'] as String?)?.trim() ?? '';
    final cats = skResolveCats(itemsRaw);
    if (cats == null) return {'error': 'unknown category in items: $itemsRaw'};
    final settingsProvider = SettingsProvider();
    await settingsProvider.initializeSettings();
    final appsProvider = AppsProvider(
      isBg: true,
      settingsProvider: settingsProvider,
    );
    await appsProvider.loadApps();
    final skUiProvider = SkUiProvider();
    await skUiProvider.initializeWithoutFonts();
    final progress = _ProgressSink(sendProgress);
    final bytes = await skBuildExportZip(
      appsProvider: appsProvider,
      settingsProvider: settingsProvider,
      skUiProvider: skUiProvider,
      cats: cats,
      onProgress: progress.report,
      isCancelled: () => _dataCancelled,
    );
    // Nothing has been written into the caller's file yet, so a cancel landing
    // here costs the caller nothing to clean up — the descriptor is closed and
    // the archive it was opened for never arrives.
    if (_dataCancelled) return {'error': 'cancelled'};
    progress.report(
      cats.length,
      cats.length,
      '区分',
      '区分 ${cats.length}/${cats.length} — ${skHumanSize(bytes.length)}',
      force: true,
    );
    return {'bytes': bytes, 'categories': cats.length};
  } on SkExportCancelled {
    return {'error': 'cancelled'};
  } catch (e) {
    return {'error': _oneLine(e.toString())};
  } finally {
    _dataJobId = null;
    _dataCancelled = false;
  }
}

/// Puts a backup back — the half that exists ONLY behind the provider.
///
/// An import overwrites this app's data, and the §1 receiver is exported with
/// no permission: an import action there would let any app on the phone wipe
/// any sister app. Here the caller has been identified by package, uid and
/// signing certificate before a byte was read.
///
/// The whole archive is in hand before anything is touched — a partial read
/// that failed halfway would import half a backup, and a half-restored app is
/// worse than one that refused. Categories absent from the archive are skipped
/// and existing data is merged, never wiped, exactly as the Export/Import panel
/// does it.
Future<Map<String, Object?>> skAutomationDataImport(
  Map<String, Object?> request,
) async {
  _dataJobId = (request['job_id'] as String?) ?? '';
  _dataCancelled = false;
  try {
    final raw = request['bytes'];
    if (raw is! Uint8List || raw.isEmpty) return {'error': 'empty archive'};
    final decoded = skDecodeExportBytes(raw);
    // Every category the archive actually carries, not every category we know
    // about: asking for one the archive lacks is how a restore ends up
    // reporting success over nothing.
    final data = decoded['data'];
    final present = <SkExportCat>{};
    if (data is Map) {
      for (final cat in SkExportCat.values) {
        if (data[cat.id] != null) present.add(cat);
      }
    }
    if (present.isEmpty) return {'error': 'archive carries no categories'};
    if (_dataCancelled) return {'error': 'cancelled'};
    final settingsProvider = SettingsProvider();
    await settingsProvider.initializeSettings();
    final appsProvider = AppsProvider(
      isBg: true,
      settingsProvider: settingsProvider,
    );
    await appsProvider.loadApps();
    final skUiProvider = SkUiProvider();
    await skUiProvider.initializeWithoutFonts();
    final summary = await skApplyImport(
      decoded: decoded,
      cats: present,
      appsProvider: appsProvider,
      settingsProvider: settingsProvider,
      skUiProvider: skUiProvider,
    );
    // 応用管理 force-stops this app the instant it hears success, and that is
    // deliberate: a running process writes its cached SharedPreferences back
    // out at orderly shutdown and would silently undo what was just imported.
    return {'restored': present.length, 'summary': _oneLine(summary)};
  } catch (e) {
    return {'error': _oneLine(e.toString())};
  } finally {
    _dataJobId = null;
    _dataCancelled = false;
  }
}
