// shiroikuma-kakutoku fork: "compare against an installed app".
//
// Many entries here only MONITOR an upstream project whose fork we patch and
// build ourselves (this very app included). Such an entry can be linked to a
// locally installed package: its reported installed version is then read from
// that package's version name with our fork's build counter stripped
// ("1.6.10+9" -> "1.6.10"), and — with `updateOnlyIfNewer` on — it reports an
// update only when the source's version is genuinely HIGHER than that base,
// not merely different from it.
//
// Everything downstream (update badge, Updates filter, list tile, App page,
// background notifications) keeps reading `App.installedVersion`, so the whole
// feature hangs off two hooks: the correction pass in AppsProviderLifecycle
// fills that field from the linked package, and [skIsOutdated] replaces the
// bare `installedVersion != latestVersion` test at the decision sites.

import 'package:android_package_manager/android_package_manager.dart';
import 'package:obtainium/providers/source_provider.dart';

/// Arrow shown between the local build an entry is about and the upstream it
/// is measured against: "白い熊 獲得 ⇒ Obtainium".
const String skLinkArrow = '⇒';

/// The prefix every one of our own builds carries in its label. An entry whose
/// displayed name starts with it is ours — whether the name comes from the
/// linked local build ("白い熊 自由動画 ⇒ FreeTube") or from the installed app
/// itself ("白い熊 獲得").
const String skOurNamePrefix = '白い熊';

/// Additional-setting keys (declared in `AppSource._commonAppSettingFormItems`).
const String skLinkedPackageKey = 'linkedInstalledPackage';
const String skLinkedStripKey = 'linkedVersionStripRegEx';
const String skUpdateOnlyIfNewerKey = 'updateOnlyIfNewer';

/// Strips our fork's build counter, padded or not: "1.6.10+9" -> "1.6.10",
/// "6.3.0-alpha.2026-07-30.g5c0ed6a3+002" -> "6.3.0-alpha.2026-07-30.g5c0ed6a3".
const String skDefaultVersionStripRegEx = r'\+\d+$';

/// The package an app is linked to, or null when it is a normal entry.
String? skLinkedPackage(App app) {
  final pkg = app.settings.getStringOrNull(skLinkedPackageKey)?.trim();
  return (pkg == null || pkg.isEmpty) ? null : pkg;
}

/// Applies the app's strip pattern to a raw OS version name. An invalid or
/// fully-consuming pattern falls back to the raw string rather than to null,
/// so a typo in the RegEx can never silently blank out the comparison.
String? skStripVersion(String? versionName, App app) {
  final raw = versionName?.trim();
  if (raw == null || raw.isEmpty) return null;
  var pattern = app.settings.getStringOrNull(skLinkedStripKey)?.trim();
  if (pattern == null || pattern.isEmpty) pattern = skDefaultVersionStripRegEx;
  try {
    final stripped = raw.replaceAll(RegExp(pattern), '').trim();
    return stripped.isEmpty ? raw : stripped;
  } catch (_) {
    return raw;
  }
}

/// The installed package an entry takes its icon and label from: the linked
/// local build whenever one is set and present, even if the tracked package
/// itself is installed here too. Linking declares that the entry is really
/// about that build — the version comparison already follows it, so the face
/// the entry shows must follow it as well, or a tracked upstream that happens
/// to be installed alongside our fork keeps lending the entry its icon.
PackageInfo? skIconSource(
  App? app,
  PackageInfo? installedInfo,
  PackageInfo? linkedInfo,
) => (app != null && skLinkedPackage(app) != null && linkedInfo != null)
    ? linkedInfo
    : installedInfo;

/// The version a linked app should report as installed. Null when no link is
/// set, or when the linked package is not installed on this device (in which
/// case the app just keeps behaving like a plain track-only entry).
String? skLinkedInstalledVersion(App app, PackageInfo? linkedInfo) {
  if (skLinkedPackage(app) == null) return null;
  return skStripVersion(linkedInfo?.versionName, app);
}

/// Pre-release ranks: anything unrecognized is treated as a final release.
const Map<String, int> _preReleaseRanks = {
  'dev': 0,
  'snapshot': 0,
  'nightly': 0,
  'alpha': 1,
  'beta': 2,
  'pre': 3,
  'preview': 3,
  'rc': 3,
};
const int _finalReleaseRank = 100;

final RegExp _numericCore = RegExp(r'^(\d+(?:[._-]\d+)*)(.*)$');
final RegExp _preRelease = RegExp(
  r'^(dev|snapshot|nightly|alpha|beta|preview|pre|rc)[._\- ]?(\d*)(.*)$',
);

class _SkVersion {
  final List<int> parts;
  final int preRank;
  final int preNum;

  /// False when part of the string was not understood — the caller then
  /// refuses to order two versions that differ only in that tail.
  final bool exact;

  const _SkVersion(this.parts, this.preRank, this.preNum, this.exact);
}

_SkVersion? _skParse(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.startsWith('v') && s.length > 1 && _isDigit(s[1])) {
    s = s.substring(1);
  }
  final coreMatch = _numericCore.firstMatch(s);
  if (coreMatch == null) return null;
  final parts = coreMatch
      .group(1)!
      .split(RegExp(r'[._-]'))
      .map((e) => int.tryParse(e) ?? 0)
      .toList();
  final rest = coreMatch.group(2)!.replaceFirst(RegExp(r'^[._\-+ ]+'), '');
  if (rest.isEmpty) {
    return _SkVersion(parts, _finalReleaseRank, 0, true);
  }
  final preMatch = _preRelease.firstMatch(rest);
  if (preMatch != null) {
    return _SkVersion(
      parts,
      _preReleaseRanks[preMatch.group(1)!]!,
      int.tryParse(preMatch.group(2) ?? '') ?? 0,
      preMatch.group(3)!.isEmpty,
    );
  }
  return _SkVersion(parts, _finalReleaseRank, 0, false);
}

bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

/// Orders two version strings: negative, zero or positive like [Comparable].
/// Returns null when the two cannot be confidently ordered — callers then fall
/// back to Obtainium's plain "they differ, so it is an update" rule, so an
/// unparseable version can never silently swallow a real update.
int? skCompareVersions(String a, String b) {
  final va = _skParse(a);
  final vb = _skParse(b);
  if (va == null || vb == null) return null;
  final len = va.parts.length > vb.parts.length
      ? va.parts.length
      : vb.parts.length;
  for (var i = 0; i < len; i++) {
    final pa = i < va.parts.length ? va.parts[i] : 0;
    final pb = i < vb.parts.length ? vb.parts[i] : 0;
    // A numeric difference is decisive even if the tails were not understood.
    if (pa != pb) return pa.compareTo(pb);
  }
  if (!va.exact || !vb.exact) {
    return a.trim().toLowerCase() == b.trim().toLowerCase() ? 0 : null;
  }
  if (va.preRank != vb.preRank) return va.preRank.compareTo(vb.preRank);
  return va.preNum.compareTo(vb.preNum);
}

/// Display form of a version string: drops the leading "v" that release tags
/// so often carry ("v1.6.10" -> "1.6.10"). Used for every version shown in the
/// UI; stored versions keep their source spelling, so nothing about fetching,
/// reconciliation or export changes.
String skDisplayVersion(String version) {
  final v = version.trim();
  if (v.length > 1 && (v[0] == 'v' || v[0] == 'V') && _isDigit(v[1])) {
    return v.substring(1);
  }
  return v;
}

/// Version strings contain no spaces, so a long one ("6.3.0-alpha.2026-07-30
/// .g5c0ed6a3") has nowhere to break and gets ellipsized in a narrow column
/// instead of wrapping. This inserts a zero-width space after each separator,
/// giving the layout somewhere to fold without changing what is read.
String skWrappableVersion(String version) =>
    version.replaceAllMapped(RegExp(r'[.\-_+]'), (m) => '${m[0]}\u200B');

/// [skDisplayVersion] passing null through.
String? skDisplayVersionOrNull(String? version) =>
    version == null ? null : skDisplayVersion(version);

/// The upstream commits embedded in a version string, in `git describe`'s
/// `g<sha>` form — the shape the git-versioning skill pins our forks to, and
/// the shape GitHub's commit-tracking mode reports upstream's head as.
///
/// All forms of the skill are accepted, since forks migrate one at a time:
///   sortable  "6.3.0-alpha.2026-07-30.g5c0ed6a3+002" -> "5c0ed6a3"
///   original  "6.3.0-alpha.g6441c21e+24"             -> "6441c21e"
///   upstream  "2026-07-30.g5c0ed6a3"                 -> "5c0ed6a3"
///
/// A fork that rebases onto more than one upstream pins one sha per upstream
/// ("0.25.1.2026-07-30.gfea7a050.gab12cd34+039"), and each is tracked by its
/// own entry here, so every sha in the string is returned. Adjacent tails
/// share the `.` between them, which is why the separators are matched as
/// lookarounds rather than consumed — consuming one would hide the next.
///
/// Requiring the `g` marker keeps an all-digit version component (a date-based
/// version like "20260801", which is valid hex) from being read as a commit —
/// and with the sortable form putting a date directly before the sha, that
/// marker is what separates the two numbers.
final RegExp _commitInVersion = RegExp(
  r'(?:^|(?<=[.\-_+]))g([0-9a-f]{7,40})(?=$|[.\-_+])',
);

List<String> skExtractCommits(String version) => _commitInVersion
    .allMatches(version.trim().toLowerCase())
    .map((m) => m.group(1)!)
    .toList();

/// The first commit named by a version string, or null when it names none.
String? skExtractCommit(String version) {
  final commits = skExtractCommits(version);
  return commits.isEmpty ? null : commits.first;
}

/// Whether two commit hashes denote the same commit. Lengths can differ (8
/// characters here, more elsewhere), so the shorter is matched as a prefix.
bool skCommitsMatch(String a, String b) => a.startsWith(b) || b.startsWith(a);

/// Whether any commit named by [a] is one named by [b]. A build rebased onto
/// several upstreams is current with respect to a given upstream as soon as
/// one of its shas is that upstream's head — the other shas belong to the
/// other upstreams and say nothing about this one.
bool skAnyCommitMatches(List<String> a, List<String> b) =>
    a.any((x) => b.any((y) => skCommitsMatch(x, y)));

/// Drop-in replacement for `app.installedVersion != app.latestVersion`, adding
/// the per-app "only if newer" rule for linked apps. Keeps the original null
/// semantics: a never-installed app counts as outdated.
bool skIsOutdated(App app) {
  final installed = app.installedVersion;
  if (installed == null) return true;
  // A bare "v" prefix is spelling, not a version difference: "1.6.10" and
  // "v1.6.10" are the same release, so they must never read as an update.
  if (skDisplayVersion(installed) == skDisplayVersion(app.latestVersion)) {
    return false;
  }
  // Commits have no ordering, only identity: when both sides name one, being
  // rebased onto upstream's head IS being up to date, whatever the version
  // literals around it say. A build pinned to several upstreams carries one
  // sha each, and this entry follows one of them, so any match is current.
  final installedCommits = skExtractCommits(installed);
  final latestCommits = skExtractCommits(app.latestVersion);
  if (installedCommits.isNotEmpty && latestCommits.isNotEmpty) {
    return !skAnyCommitMatches(installedCommits, latestCommits);
  }
  if (skLinkedPackage(app) == null ||
      !app.settings.getBool(skUpdateOnlyIfNewerKey, defaultValue: true)) {
    return true;
  }
  final cmp = skCompareVersions(app.latestVersion, installed);
  return cmp == null || cmp > 0;
}

/// Snapshot of every installed package, refreshed by `loadApps` (which already
/// enumerates them for install-status detection, so the picker costs nothing
/// extra) and read by the installed-app picker.
List<PackageInfo> skInstalledPackages = const [];

void skSetInstalledPackages(List<PackageInfo> packages) {
  skInstalledPackages = packages;
}

/// ApplicationInfo.FLAG_SYSTEM / FLAG_UPDATED_SYSTEM_APP.
const int _flagSystem = 1 << 0;
const int _flagUpdatedSystemApp = 1 << 7;

/// True for user-installed apps (including updated system apps) — the default
/// contents of the picker, which keeps a ~400-package list down to a few dozen.
bool skIsUserApp(PackageInfo info) {
  final flags = info.applicationInfo?.flags ?? 0;
  return (flags & _flagSystem) == 0 || (flags & _flagUpdatedSystemApp) != 0;
}
