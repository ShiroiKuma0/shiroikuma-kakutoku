// shiroikuma-kakutoku fork: the installed-app picker behind the per-app
// "Compare against installed app" option. Same shape as the fork's colour and
// font pickers in sk_ui_widgets.dart — an AlertDialog with a search field and
// a scrolling list, here showing icon, label, package name and version name.
//
// The package list comes from the snapshot `loadApps` already collects, so
// opening the picker costs no extra package-manager enumeration; labels are
// fetched once per dialog (user apps only by default) and icons lazily per
// visible row.

import 'dart:typed_data';

import 'package:android_package_manager/android_package_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:obtainium/providers/sk_linked_version.dart';
import 'package:obtainium/providers/source_provider.dart';

/// Returns the chosen package name, an empty string when the user unlinked,
/// or null when the dialog was dismissed without a choice.
Future<String?> showSkInstalledAppPicker(
  BuildContext context, {
  String? selected,
  App? matchApp,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) =>
        _SkInstalledAppPickerDialog(selected: selected, matchApp: matchApp),
  );
}

class _SkInstalledAppPickerDialog extends StatefulWidget {
  const _SkInstalledAppPickerDialog({this.selected, this.matchApp});

  final String? selected;

  /// When given, packages whose stripped version equals this app's latest
  /// version are hoisted into a "Suggested" group — for a fork entry that puts
  /// the matching local build at the top of the list on the first try.
  final App? matchApp;

  @override
  State<_SkInstalledAppPickerDialog> createState() =>
      _SkInstalledAppPickerDialogState();
}

class _SkInstalledAppPickerDialogState
    extends State<_SkInstalledAppPickerDialog> {
  final Map<String, String> _labels = {};
  final Map<String, Uint8List?> _icons = {};
  final TextEditingController _search = TextEditingController();

  bool _showSystemApps = false;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PackageInfo> get _pool => skInstalledPackages
      .where(
        (p) =>
            p.packageName != null &&
            (_showSystemApps ||
                skIsUserApp(p) ||
                p.packageName == widget.selected),
      )
      .toList();

  Future<void> _loadLabels() async {
    final pending = _pool
        .where((p) => !_labels.containsKey(p.packageName))
        .toList();
    await Future.wait(
      pending.map((p) async {
        final label = await p.applicationInfo?.getAppLabel();
        if (label != null && label.trim().isNotEmpty) {
          _labels[p.packageName!] = label.trim();
        }
      }),
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<Uint8List?> _icon(PackageInfo info) async {
    final pkg = info.packageName!;
    if (_icons.containsKey(pkg)) return _icons[pkg];
    final icon = await info.applicationInfo?.getAppIcon();
    _icons[pkg] = icon;
    return icon;
  }

  String _labelOf(PackageInfo info) =>
      _labels[info.packageName!] ?? info.packageName!;

  /// True when this package's stripped version matches the tracked app's
  /// latest version — i.e. it is very likely the local build of that source.
  /// A git-versioned build matches on the commit it is pinned to, since its
  /// version number stands still between upstream releases.
  bool _isSuggested(PackageInfo info) {
    final app = widget.matchApp;
    if (app == null) return false;
    final base = skStripVersion(info.versionName, app);
    if (base == null) return false;
    final baseCommits = skExtractCommits(base);
    final latestCommits = skExtractCommits(app.latestVersion);
    if (baseCommits.isNotEmpty && latestCommits.isNotEmpty) {
      return skAnyCommitMatches(baseCommits, latestCommits);
    }
    return skCompareVersions(base, app.latestVersion) == 0;
  }

  List<PackageInfo> _filtered() {
    final q = _query.trim().toLowerCase();
    final list = _pool.where((p) {
      if (q.isEmpty) return true;
      return _labelOf(p).toLowerCase().contains(q) ||
          p.packageName!.toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) {
      final sa = _isSuggested(a), sb = _isSuggested(b);
      if (sa != sb) return sa ? -1 : 1;
      return _labelOf(a).toLowerCase().compareTo(_labelOf(b).toLowerCase());
    });
    return list;
  }

  Widget _row(PackageInfo info) {
    final theme = Theme.of(context);
    final pkg = info.packageName!;
    final isSelected = pkg == widget.selected;
    return InkWell(
      onTap: () => Navigator.of(context).pop(pkg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: FutureBuilder<Uint8List?>(
                future: _icon(info),
                builder: (context, snapshot) => snapshot.data != null
                    ? Image.memory(
                        snapshot.data!,
                        filterQuality: FilterQuality.medium,
                      )
                    : const Icon(Icons.android, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelOf(info),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$pkg${info.versionName != null ? '  ·  ${info.versionName}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_isSuggested(info))
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.check, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _loading ? const <PackageInfo>[] : _filtered();
    return AlertDialog(
      title: Text(tr('pickInstalledApp')),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 380,
        height: 460,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _search,
                autofocus: false,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  labelText: tr('search'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                tr('showSystemApps'),
                style: const TextStyle(fontSize: 13),
              ),
              value: _showSystemApps,
              onChanged: (v) {
                setState(() {
                  _showSystemApps = v;
                  if (v) _loading = true;
                });
                if (v) _loadLabels();
              },
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : entries.isEmpty
                  ? Center(child: Text(tr('none')))
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, i) => _row(entries[i]),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text(tr('unlink')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel')),
        ),
      ],
    );
  }
}
