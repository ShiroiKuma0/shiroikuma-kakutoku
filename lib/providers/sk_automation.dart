// shiroikuma-kakutoku fork: the 保存復元 state-export automation contract.
//
// 白い熊's automation app 自由作業盤 backs up every sister app in one run: it
// fires a token-gated broadcast at each app, the app exports itself headlessly,
// reports progress with real counts, and replies with the written path and
// size. This file is this app's end of that wire:
//
//   * [SkAutomation] — the device-local switch (default OFF) and token.
//   * [skAutomationMain] — the headless Dart entrypoint the native
//     StateExportReceiver boots into a plain FlutterEngine (no Activity).
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
const String skAutomationTokenKey = 'skAutomationToken';

/// The method channel shared with `StateExportReceiver.kt`.
const String skAutomationChannel = 'dev.imranr.obtainium/sk_automation';

/// This app's display label, sent with every progress broadcast so 自由作業盤
/// can name the app it is currently waiting on.
const String skAppLabel = '白い熊 獲得';

/// The automation gate: a switch 白い熊 turns on by hand, plus a token that
/// must match on every single request.
class SkAutomation {
  static bool isEnabled(SharedPreferences prefs) =>
      prefs.getBool(skAutomationEnabledKey) ?? false;

  static Future<void> setEnabled(SharedPreferences prefs, bool value) =>
      prefs.setBool(skAutomationEnabledKey, value);

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

  /// null when the request may proceed, otherwise the short reason for the
  /// `ERROR:` reply. "automation disabled" and "bad token" stay distinct —
  /// they debug differently.
  static String? verify(SharedPreferences prefs, String? candidate) {
    if (!isEnabled(prefs)) return 'automation disabled';
    final stored = prefs.getString(skAutomationTokenKey);
    if (stored == null || stored.isEmpty) return 'bad token';
    if (candidate == null || candidate.isEmpty) return 'bad token';
    return _constantTimeEquals(candidate, stored) ? null : 'bad token';
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

/// The `LIST_CATEGORIES` reply: `OK:` followed by one `id<TAB>label` line per
/// exportable category. The ids are exactly the ones accepted in `items`, and
/// they are the ZIP's entry-name stems. The list is flat — no category of this
/// app has separately selectable parts — so no line carries a third field.
String skCategoriesReply() =>
    'OK:${SkExportCat.values.map((c) => '${c.id}\t${c.label}').join('\n')}';

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
    final denied = SkAutomation.verify(prefs, request['token'] as String?);
    if (denied != null) return 'ERROR:$denied';
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
Future<String> _export(
  Map<String, Object?> request,
  void Function(Map<String, Object?>) sendProgress,
) async {
  // ---- items: which categories (absent/empty = everything) ----
  final itemsRaw = (request['items'] as String?)?.trim() ?? '';
  final Set<SkExportCat> cats;
  if (itemsRaw.isEmpty) {
    cats = SkExportCat.values.toSet();
  } else {
    final byId = {for (final c in SkExportCat.values) c.id: c};
    final picked = <SkExportCat>{};
    for (final raw in itemsRaw.split(',')) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      final cat = byId[id];
      if (cat == null) return 'ERROR:unknown category in items: $itemsRaw';
      picked.add(cat);
    }
    if (picked.isEmpty) return 'ERROR:unknown category in items: $itemsRaw';
    cats = picked;
  }

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
  );

  // ---- write it, once ----
  final name = skExportFileName();
  final String writtenPath;
  if (directDir != null) {
    final file = File('$directDir/$name');
    await file.writeAsBytes(bytes, flush: true);
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
