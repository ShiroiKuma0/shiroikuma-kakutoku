import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart';
import 'package:obtainium/utils/string_compare.dart';
import 'package:obtainium/components/generated_form_model.dart';
import 'package:obtainium/custom_errors.dart';
import 'package:obtainium/providers/apps_provider.dart';
import 'package:obtainium/core/logging/app_logger.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/providers/source_provider.dart';

class GitHub extends AppSource {
  static const int _fallbackCacheSeconds = 3600;

  GitHub({bool hostChanged = false}) {
    name = 'GitHub';
    hosts = ['github.com'];
    appIdInferIsOptional = true;
    showReleaseDateAsVersionToggle = true;
    this.hostChanged = hostChanged;
    allowIncludeZips = true;
    allowIncludeTarballs = true;
    canSearch = true;
  }

  @override
  List<GeneratedFormItem> get sourceConfigSettingFormItems => [
    GeneratedFormTextField(
      'github-creds',
      label: tr('githubPATLabel'),
      password: true,
      required: false,
      helpUrl:
          'https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token',
    ),
    GeneratedFormTextField(
      'GHReqPrefix',
      label: tr('GHReqPrefix'),
      hint: 'gh-proxy.org',
      required: false,
      additionalValidators: [
        (value) {
          try {
            if (value != null && Uri.parse(value).scheme.isNotEmpty) {
              throw true;
            }
            if (value != null) {
              Uri.parse('https://$value/api.github.com');
            }
          } catch (e) {
            return tr('invalidInput');
          }
          return null;
        },
      ],
      helpUrl: 'https://github.com/sky22333/hubproxy',
    ),
    GeneratedFormSwitch(
      'checkRepoRename',
      label: tr('repoRenamedCheck'),
      value: false,
    ),
  ];

  @override
  List<List<GeneratedFormItem>>
  get additionalSourceAppSpecificSettingFormItems => [
    [
      GeneratedFormSwitch(
        'includePrereleases',
        label: tr('includePrereleases'),
        value: false,
        disabledBy: const ['trackCommits'],
      ),
    ],
    // Fork: same switch as AppSource.fallbackToOlderReleasesFormItem, but
    // meaningless while commits are followed — there are no releases to fall
    // back to. Following commits turns both release options off and greys
    // them out; turning it off hands them back.
    [
      GeneratedFormSwitch(
        'fallbackToOlderReleases',
        label: tr('fallbackToOlderReleases'),
        value: true,
        disabledBy: const ['trackCommits'],
      ),
    ],
    // Fork: follow the repo's commits instead of its releases — for upstreams
    // we rebase onto and build ourselves (see sk_linked_version.dart).
    [
      GeneratedFormSwitch(
        'trackCommits',
        label: tr('trackCommits'),
        value: false,
        excludes: const ['includePrereleases', 'fallbackToOlderReleases'],
      ),
    ],
    [
      GeneratedFormTextField(
        'trackCommitsBranch',
        label: tr('trackCommitsBranch'),
        required: false,
        hint: tr('defaultBranch'),
      ),
    ],
    // Fork: where the upstream version comes from while commits are followed.
    // Without these the prefix is the repo's newest release tag, which is wrong
    // for upstreams that tag something other than the version they ship.
    [
      GeneratedFormTextField(
        'trackCommitsVersionFile',
        label: tr('trackCommitsVersionFile'),
        required: false,
        hint: 'app/build.gradle.kts',
      ),
    ],
    [
      GeneratedFormTextField(
        'trackCommitsVersionRegEx',
        label: tr('trackCommitsVersionRegEx'),
        required: false,
        hint: _defaultVersionFileRegEx,
        additionalValidators: [
          (value) {
            return regExValidator(value);
          },
        ],
      ),
    ],
    [
      GeneratedFormTextField(
        'filterReleaseTitlesByRegEx',
        label: tr('filterReleaseTitlesByRegEx'),
        required: false,
        additionalValidators: [
          (value) {
            return regExValidator(value);
          },
        ],
      ),
    ],
    [
      GeneratedFormTextField(
        'filterReleaseNotesByRegEx',
        label: tr('filterReleaseNotesByRegEx'),
        required: false,
        additionalValidators: [
          (value) {
            return regExValidator(value);
          },
        ],
      ),
    ],
    [GeneratedFormSwitch('verifyLatestTag', label: tr('verifyLatestTag'))],
    [
      GeneratedFormDropdown(
        'sortMethodChoice',
        [
          MapEntry('date', tr('releaseDate')),
          MapEntry('smartname', tr('smartname')),
          MapEntry('none', tr('none')),
          MapEntry(
            'smartname-datefallback',
            '${tr('smartname')} x ${tr('releaseDate')}',
          ),
          MapEntry('name', tr('name')),
        ],
        label: tr('sortMethod'),
        value: 'date',
      ),
    ],
    [
      GeneratedFormSwitch(
        'useLatestAssetDateAsReleaseDate',
        label: tr('useLatestAssetDateAsReleaseDate'),
        value: false,
      ),
    ],
    [
      GeneratedFormSwitch(
        'releaseTitleAsVersion',
        label: tr('releaseTitleAsVersion'),
        value: false,
      ),
    ],
  ];

  @override
  List<GeneratedFormItem> get searchQuerySettingFormItems => [
    GeneratedFormTextField(
      'minStarCount',
      label: tr('minStarCount'),
      value: '0',
      additionalValidators: [
        (value) {
          try {
            int.parse(value ?? '0');
          } catch (e) {
            return tr('invalidInput');
          }
          return null;
        },
      ],
    ),
  ];

  @override
  Future<String?> tryInferringAppId(
    String standardUrl, {
    Map<String, dynamic> additionalSettings = const {},
  }) async {
    const possibleBuildGradleLocations = [
      '/app/build.gradle',
      'android/app/build.gradle',
      'src/app/build.gradle',
    ];
    for (var path in possibleBuildGradleLocations) {
      try {
        final res = await sourceRequest(
          '${await convertStandardUrlToAPIUrl(standardUrl, additionalSettings)}/contents/$path',
          additionalSettings,
        );
        if (res.statusCode == 200) {
          try {
            final body = jsonDecode(res.body);
            final trimmedLines = utf8
                .decode(
                  base64.decode(
                    body['content'].toString().split('\n').join(''),
                  ),
                )
                .split('\n')
                .map((e) => e.trim());
            var appIds = trimmedLines.where(
              (l) =>
                  l.startsWith('applicationId "') ||
                  l.startsWith('applicationId \''),
            );
            appIds = appIds.map((appId) {
              final parts = appId.split(
                appId.startsWith('applicationId "') ? '"' : '\'',
              );
              return parts.length > 1 ? parts[1] : '';
            });
            appIds = appIds
                .map((appId) {
                  if (appId.startsWith('\${') && appId.endsWith('}')) {
                    final varLine = trimmedLines
                        .where(
                          (l) => l.startsWith(
                            'def ${appId.substring(2, appId.length - 1)}',
                          ),
                        )
                        .firstOrNull;
                    if (varLine == null) return '';
                    final parts = varLine.split(
                      varLine.contains('"') ? '"' : '\'',
                    );
                    appId = parts.length > 1 ? parts[1] : '';
                  }
                  return appId;
                })
                .where((appId) => appId.isNotEmpty);
            if (appIds.length == 1) {
              return appIds.first;
            }
          } catch (err) {
            AppLogger.info(
              'Error parsing build.gradle from ${res.request?.url.toString() ?? standardUrl}: ${err.toString()}',
            );
          }
        }
      } catch (err) {
        AppLogger.info(
          'Failed to extract ID from build.gradle or APK: ${err.toString()}',
        );
      }
    }
    return null;
  }

  @override
  String sourceSpecificStandardizeURL(
    String url, {
    bool forSelection = false,
  }) => standardizeUrlWithRegex(
    url,
    subdomainPrefix: r'(www\.)?',
    pathPattern: r'/[^/]+/[^/]+',
  );

  @override
  Future<Map<String, String>?> getRequestHeaders(
    Map<String, dynamic> additionalSettings,
    String url, {
    bool forAPKDownload = false,
  }) async {
    // A request with skipAuth is retried without the configured token (e.g.
    // after the token was rejected for this repository); see #3211.
    final token = additionalSettings['skipAuth'] == true
        ? null
        : await getTokenIfAny(additionalSettings);
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = 'Token $token';
    }
    if (forAPKDownload == true) {
      headers[HttpHeaders.acceptHeader] = 'application/octet-stream';
    }
    if (headers.isNotEmpty) {
      return headers;
    } else {
      return null;
    }
  }

  Future<String?> getTokenIfAny(Map<String, dynamic> additionalSettings) async {
    final SettingsProvider settingsProvider = SettingsProvider();
    await settingsProvider.initializeSettings();
    final sourceConfig = await getSourceConfigValues(
      additionalSettings,
      settingsProvider,
    );
    String? creds = sourceConfig['github-creds'];
    if ((additionalSettings['GHReqPrefix'] as String? ?? '').isNotEmpty) {
      creds = null;
    }
    if (creds != null) {
      final userNameEndIndex = creds.indexOf(':');
      if (userNameEndIndex > 0) {
        creds = creds.substring(
          userNameEndIndex + 1,
        ); // For old username-included token inputs
      }
      return creds;
    } else {
      return null;
    }
  }

  @override
  Future<String?> getSourceNote() async {
    if (!hostChanged && (await getTokenIfAny({})) == null) {
      return '${tr('githubSourceNote')} ${hostChanged ? tr('addInfoBelow') : tr('addInfoInSettings')}';
    }
    return null;
  }

  @override
  Future<String> generalReqPrefetchModifier(
    String reqUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    if ((additionalSettings['GHReqPrefix'] as String? ?? '').isNotEmpty) {
      final uri = Uri.parse(reqUrl);
      return 'https://${additionalSettings['GHReqPrefix']}/${uri.toString().substring('https://'.length)}';
    }
    return reqUrl;
  }

  @override
  bool enforceTrackOnlyFor(Map<String, dynamic> additionalSettings) =>
      enforceTrackOnly || additionalSettings['trackCommits'] == true;

  Future<String> getAPIHost(Map<String, dynamic> additionalSettings) async =>
      'https://api.${hosts[0]}';

  /// Whether [res] is a 401/403 whose JSON body says the configured token is
  /// the problem (e.g. "Resource not accessible by personal access token").
  static bool _isAuthRejection(Response res) {
    if (res.statusCode != 401 && res.statusCode != 403) return false;
    try {
      final message =
          (jsonDecode(res.body)['message'] as String? ?? '').toLowerCase();
      return message.contains('access token') ||
          message.contains('bad credentials');
    } catch (_) {
      return false;
    }
  }

  /// Runs [url] through [sourceRequest], retrying without the configured
  /// token when GitHub rejects the authenticated request (a token that is not
  /// authorized for this repository must not block updates of public repos).
  Future<Response> _sourceRequestWithAuthFallback(
    String url,
    Map<String, dynamic> additionalSettings,
  ) async {
    var res = await sourceRequest(url, additionalSettings);
    if (_isAuthRejection(res)) {
      AppLogger.info(
        'GitHub request for $url rejected due to token access, retrying without token.',
      );
      res = await sourceRequest(
        url,
        Map<String, dynamic>.from(additionalSettings)..['skipAuth'] = true,
      );
    }
    return res;
  }

  Future<String> convertStandardUrlToAPIUrl(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async =>
      '${await getAPIHost(additionalSettings)}/repos${standardUrl.substring('https://${hosts[0]}'.length)}';

  /// Checks if the repository has been renamed or transferred.
  ///
  /// This method explicitly disables automatic redirect following to detect when
  /// GitHub returns a redirect (indicating the repository has moved). A redirect
  /// from the GitHub API for a repository endpoint definitively indicates that
  /// the repository has been renamed or transferred to a different owner.
  ///
  /// Throws [RepositoryRenamedError] if a redirect is detected.
  Future<void> checkForRepositoryRename(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
    Map<String, String> sourceConfigSettingValues,
  ) async {
    if (sourceConfigSettingValues['checkRepoRename'] != 'true') {
      return;
    }
    final uri = Uri.tryParse(standardUrl);
    final host = uri?.host.toLowerCase() ?? '';
    // Guard against non-GitHub URLs
    if (host != hosts[0] && host != 'www.${hosts[0]}') {
      return;
    }
    final apiUrl = await convertStandardUrlToAPIUrl(
      standardUrl,
      additionalSettings,
    );
    final Response res = await sourceRequest(
      apiUrl,
      additionalSettings,
      followRedirects: false,
    );
    if (res.statusCode >= 300 && res.statusCode < 400) {
      final String? location =
          res.headers[HttpHeaders.locationHeader.toLowerCase()];
      if (location != null) {
        final Response res2 = await sourceRequest(
          location,
          additionalSettings,
          followRedirects: false,
        );
        String? newUrl;
        try {
          newUrl = jsonDecode(res2.body)['html_url'];
        } catch (e) {
          AppLogger.info(
            'Failed to parse redirect response for repo rename: ${e.toString()}',
          );
        }
        if (newUrl != null) {
          throw RepositoryRenamedError(standardUrl, newUrl);
        }
      }
    }
  }

  @override
  String? changeLogPageFromStandardUrl(String standardUrl) =>
      '$standardUrl/releases';

  List<dynamic> _findReleaseAssetUrls(
    dynamic release,
    bool includeZips,
    bool includeTarballs,
    Map<String, String> sourceConfigSettingValues,
  ) =>
      (release['assets'] as List<dynamic>?)?.map((e) {
        final name = e['name'].toString();
        var url =
            !AppSource.isApkOrContainerFile(
              name,
              includeArchives: includeZips,
              includeTarballs: includeTarballs,
            )
            ? (e['browser_download_url'] ?? e['url'])
            : (e['url'] ?? e['browser_download_url']);
        url = undoGHProxyMod(url, sourceConfigSettingValues);
        e['final_url'] = (e['name'] != null) && (url != null)
            ? MapEntry(e['name'] as String, url as String)
            : const MapEntry('', '');
        return e;
      }).toList() ??
      [];

  DateTime? _getPublishDateFromRelease(dynamic rel) {
    final pub = rel?['published_at'];
    if (pub is String) return DateTime.tryParse(pub);
    final commitCreated = rel?['commit']?['created'];
    if (commitCreated is String) return DateTime.tryParse(commitCreated);
    return null;
  }

  DateTime? _getNewestAssetDateFromRelease(dynamic rel) {
    final allAssets = rel['assets'] as List<dynamic>?;
    final filteredAssets = rel['filteredAssets'] as List<dynamic>?;
    final t = (filteredAssets ?? allAssets)
        ?.map((e) {
          final updated = e?['updated_at'];
          return updated is String ? DateTime.tryParse(updated) : null;
        })
        .where((e) => e != null)
        .toList();
    t?.sort((a, b) => b!.compareTo(a!));
    if (t?.isNotEmpty == true) {
      return t!.first;
    }
    return null;
  }

  DateTime? _getReleaseDateFromRelease(dynamic rel, bool useAssetDate) =>
      !useAssetDate
      ? _getPublishDateFromRelease(rel)
      : _getNewestAssetDateFromRelease(rel);

  /// Fork: orders two releases by date, with a name tie-break for the dateless.
  ///
  /// Every entry of the tag list the source falls back to when a repo lists no
  /// releases is dateless — the tags endpoint reports none — and comparing two
  /// of those as if one were newer is not an ordering at all: `compare(a, b)`
  /// and `compare(b, a)` both said "later", so Dart's quicksort left the list
  /// in an arbitrary permutation and "latest" came out a random tag
  /// (premnirmal/StockTicker resolved to its 2020 CI tag `300900719`).
  /// Dateless entries are therefore settled by name, which is the only thing
  /// that distinguishes them, so such a list still resolves to its highest tag.
  ///
  /// A dateless entry still loses to a dated one: a release that does not say
  /// when it was cut must never take "latest" from one that does.
  int _compareReleasesByDate(
    dynamic a,
    dynamic b,
    DateTime? dateA,
    DateTime? dateB,
  ) {
    if (dateA != null && dateB != null) return dateA.compareTo(dateB);
    if (dateA != null) return 1;
    if (dateB != null) return -1;
    return compareAlphaNumeric(
      (a['tag_name'] ?? a['name'])?.toString() ?? '',
      (b['tag_name'] ?? b['name'])?.toString() ?? '',
    );
  }

  void _sortGitHubReleases(
    List<dynamic> releases,
    String sortMethod,
    bool useLatestAssetDateAsReleaseDate,
  ) {
    if (sortMethod == 'none') return;

    // Precompute dates and (for smartname/name sorts) per-release format
    // sets once. Memoization in findStandardFormatsForVersion already handles
    // the per-version cache; we still precompute here so the sort comparator
    // only performs O(1) lookups instead of O(n) per comparison.
    final isDateOnly = sortMethod == 'date';
    final Map<dynamic, DateTime?> dates = {};
    final Map<dynamic, Set<String>> formats = {};
    if (!isDateOnly) {
      for (final r in releases) {
        if (r == null) continue;
        final name = (r['tag_name'] ?? r['name'])?.toString() ?? '';
        formats[r] = findStandardFormatsForVersion(name, false);
      }
    }

    releases.sort((a, b) {
      if (a == null) return -1;
      if (b == null) return 1;

      if (isDateOnly) {
        final dateA = dates.putIfAbsent(
          a,
          () => _getReleaseDateFromRelease(a, useLatestAssetDateAsReleaseDate),
        );
        final dateB = dates.putIfAbsent(
          b,
          () => _getReleaseDateFromRelease(b, useLatestAssetDateAsReleaseDate),
        );
        return _compareReleasesByDate(a, b, dateA, dateB);
      }

      final nameA = a['tag_name'] ?? a['name'];
      final nameB = b['tag_name'] ?? b['name'];
      final stdFormats = formats[a]!.intersection(formats[b]!);

      if (sortMethod == 'smartname-datefallback' && stdFormats.isEmpty) {
        final dateA = _getReleaseDateFromRelease(
          a,
          useLatestAssetDateAsReleaseDate,
        );
        final dateB = _getReleaseDateFromRelease(
          b,
          useLatestAssetDateAsReleaseDate,
        );
        return _compareReleasesByDate(a, b, dateA, dateB);
      }

      if (sortMethod != 'name' && stdFormats.isNotEmpty) {
        final sortedFormats = stdFormats.toList()
          ..sort((x, y) => y.length.compareTo(x.length));
        final regCache = <String, RegExp>{};
        final reg = regCache.putIfAbsent(
          sortedFormats.first,
          () => RegExp(sortedFormats.first),
        );
        final matchA = reg.firstMatch(nameA);
        final matchB = reg.firstMatch(nameB);
        if (matchA == null || matchB == null) {
          return compareAlphaNumeric(nameA as String, nameB as String);
        }
        return compareAlphaNumeric(
          (nameA as String).substring(matchA.start, matchA.end),
          (nameB as String).substring(matchB.start, matchB.end),
        );
      }

      return compareAlphaNumeric(nameA as String, nameB as String);
    });
  }

  void _positionLatestRelease(List<dynamic> releases, dynamic latestRelease) {
    if (latestRelease == null ||
        (latestRelease['tag_name'] ?? latestRelease['name']) == null ||
        releases.isEmpty ||
        (latestRelease['tag_name'] ?? latestRelease['name']) ==
            (releases[releases.length - 1]['tag_name'] ??
                releases[releases.length - 1]['name'])) {
      return;
    }
    final ind = releases.indexWhere(
      (element) =>
          (latestRelease['tag_name'] ?? latestRelease['name']) ==
          (element['tag_name'] ?? element['name']),
    );
    if (ind >= 0) {
      releases.add(releases.removeAt(ind));
    }
  }

  dynamic _selectGitHubTargetRelease({
    required List<dynamic> releases,
    required bool fallbackToOlderReleases,
    required bool includePrereleases,
    required String? regexFilter,
    required String? regexNotesFilter,
    required bool includeZips,
    required bool includeTarballs,
    required Map<String, dynamic> additionalSettings,
    required Map<String, String> sourceConfigSettingValues,
  }) {
    var releaseSkipped = 0;
    final titleRegex = regexFilter != null ? RegExp(regexFilter) : null;
    final notesRegex = regexNotesFilter != null
        ? RegExp(regexNotesFilter)
        : null;
    for (int i = 0; i < releases.length; i++) {
      if (!fallbackToOlderReleases && i > releaseSkipped) break;
      if (!includePrereleases && releases[i]['prerelease'] == true) {
        releaseSkipped++;
        continue;
      }
      if (releases[i]['draft'] == true) {
        releaseSkipped++;
        continue;
      }
      var nameToFilter = releases[i]['name'] as String?;
      if (nameToFilter == null || nameToFilter.trim().isEmpty) {
        nameToFilter = releases[i]['tag_name']?.toString() ?? '';
      }
      if (titleRegex != null && !titleRegex.hasMatch(nameToFilter.trim())) {
        continue;
      }
      if (notesRegex != null &&
          !notesRegex.hasMatch(
            ((releases[i]['body'] as String?) ?? '').trim(),
          )) {
        continue;
      }
      final allAssetsWithUrls = _findReleaseAssetUrls(
        releases[i],
        includeZips,
        includeTarballs,
        sourceConfigSettingValues,
      );
      final List<MapEntry<String, String>> allAssetUrls = allAssetsWithUrls
          .map((e) => e['final_url'] as MapEntry<String, String>)
          .toList();
      final apkAssetsWithUrls = allAssetsWithUrls.where((element) {
        final name = (element['final_url'] as MapEntry<String, String>).key;
        return AppSource.isApkOrContainerFile(
          name,
          includeArchives: includeZips,
          includeTarballs: includeTarballs,
        );
      }).toList();

      final filteredApkUrls = filterApks(
        apkAssetsWithUrls
            .map((e) => e['final_url'] as MapEntry<String, String>)
            .toList(),
        additionalSettings['apkFilterRegEx'],
        additionalSettings['invertAPKFilter'],
      );
      final filteredApks = apkAssetsWithUrls
          .where(
            (e) => filteredApkUrls
                .where(
                  (e2) =>
                      e2.key ==
                      (e['final_url'] as MapEntry<String, String>).key,
                )
                .isNotEmpty,
          )
          .toList();

      if (filteredApks.isEmpty && additionalSettings['trackOnly'] != true) {
        continue;
      }
      final targetRelease = releases[i];
      targetRelease['apkUrls'] = filteredApkUrls;
      targetRelease['filteredAssets'] = filteredApks;
      targetRelease['version'] =
          additionalSettings['releaseTitleAsVersion'] == true
          ? nameToFilter
          : targetRelease['tag_name'] ?? targetRelease['name'];
      if (targetRelease['tarball_url'] != null) {
        allAssetUrls.add(
          MapEntry(
            (targetRelease['version'] ?? 'source') + '.tar.gz',
            undoGHProxyMod(
              targetRelease['tarball_url'],
              sourceConfigSettingValues,
            ),
          ),
        );
      }
      if (targetRelease['zipball_url'] != null) {
        allAssetUrls.add(
          MapEntry(
            (targetRelease['version'] ?? 'source') + '.zip',
            undoGHProxyMod(
              targetRelease['zipball_url'],
              sourceConfigSettingValues,
            ),
          ),
        );
      }
      targetRelease['allAssetUrls'] = allAssetUrls;
      return targetRelease;
    }
    return null;
  }

  /// Fetches and parses GitHub releases, applying sort/filter/prelease settings,
  /// then resolves the best matching release to an [APKDetails] result.
  Future<APKDetails> _fetchReleaseDetails(
    String requestUrl,
    String standardUrl,
    Map<String, dynamic> additionalSettings, {
    Function(Response)? onHttpErrorCode,
  }) async {
    final SettingsProvider settingsProvider = SettingsProvider();
    await settingsProvider.initializeSettings();
    final sourceConfigSettingValues = await getSourceConfigValues(
      additionalSettings,
      settingsProvider,
    );
    await checkForRepositoryRename(
      standardUrl,
      additionalSettings,
      sourceConfigSettingValues,
    );
    final bool includePrereleases =
        additionalSettings['includePrereleases'] == true;
    final bool fallbackToOlderReleases =
        additionalSettings['fallbackToOlderReleases'] == true;
    final String? regexFilter =
        (additionalSettings['filterReleaseTitlesByRegEx'] as String?)
                ?.isNotEmpty ==
            true
        ? additionalSettings['filterReleaseTitlesByRegEx']
        : null;
    final String? regexNotesFilter =
        (additionalSettings['filterReleaseNotesByRegEx'] as String?)
                ?.isNotEmpty ==
            true
        ? additionalSettings['filterReleaseNotesByRegEx']
        : null;
    final bool verifyLatestTag = additionalSettings['verifyLatestTag'] == true;
    final bool useLatestAssetDateAsReleaseDate =
        additionalSettings['useLatestAssetDateAsReleaseDate'] == true;
    final String sortMethod =
        additionalSettings['sortMethodChoice'] ?? 'smartname-datefallback';
    final bool includeZips = additionalSettings['includeZips'] == true;
    final bool includeTarballs = additionalSettings['includeTarballs'] == true;
    dynamic latestRelease;
    if (verifyLatestTag) {
      final uri = Uri.parse(requestUrl);
      final latestUrl = uri.replace(query: null, path: '${uri.path}/latest');
      final Response res = await _sourceRequestWithAuthFallback(
        latestUrl.toString(),
        additionalSettings,
      );
      if (res.statusCode != 200) {
        if (onHttpErrorCode != null) {
          onHttpErrorCode(res);
        }
        throw getObtainiumHttpError(res);
      }
      latestRelease = jsonDecode(res.body);
    }
    final Response res = await _sourceRequestWithAuthFallback(
      requestUrl,
      additionalSettings,
    );
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is! List) {
        throw NoReleasesError();
      }
      var releases = decoded;
      if (latestRelease != null) {
        final latestTag = latestRelease['tag_name'] ?? latestRelease['name'];
        if (releases
            .where(
              (element) =>
                  (element['tag_name'] ?? element['name']) == latestTag,
            )
            .isEmpty) {
          releases = [latestRelease, ...releases];
        }
      }

      if (sortMethod == 'none') {
        releases = releases.reversed.toList();
      } else {
        _sortGitHubReleases(
          releases,
          sortMethod,
          useLatestAssetDateAsReleaseDate,
        );
      }
      _positionLatestRelease(releases, latestRelease);
      releases = releases.reversed.toList();
      final targetRelease = _selectGitHubTargetRelease(
        releases: releases,
        fallbackToOlderReleases: fallbackToOlderReleases,
        includePrereleases: includePrereleases,
        regexFilter: regexFilter,
        regexNotesFilter: regexNotesFilter,
        includeZips: includeZips,
        includeTarballs: includeTarballs,
        additionalSettings: additionalSettings,
        sourceConfigSettingValues: sourceConfigSettingValues,
      );
      if (targetRelease == null) {
        throw NoReleasesError();
      }
      final String? version = targetRelease['version'];
      final DateTime? releaseDate = _getReleaseDateFromRelease(
        targetRelease,
        useLatestAssetDateAsReleaseDate,
      );
      if (version == null || version.isEmpty) {
        throw NoVersionError();
      }
      final changeLog = (targetRelease['body'] ?? '').toString();
      return APKDetails(
        version,
        targetRelease['apkUrls'] as List<MapEntry<String, String>>,
        getAppNames(standardUrl),
        releaseDate: releaseDate,
        changeLog: changeLog.isEmpty ? null : changeLog,
        allAssetUrls:
            targetRelease['allAssetUrls'] as List<MapEntry<String, String>>,
      );
    } else {
      if (onHttpErrorCode != null) {
        onHttpErrorCode(res);
      }
      throw getObtainiumHttpError(res);
    }
  }

  Future<APKDetails> fetchReleaseDetailsWithTagFallback(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
    Future<String> Function(bool) reqUrlGenerator,
    dynamic Function(Response)? onHttpErrorCode,
  ) async {
    try {
      return await _fetchReleaseDetails(
        await reqUrlGenerator(false),
        standardUrl,
        additionalSettings,
        onHttpErrorCode: onHttpErrorCode,
      );
    } catch (err) {
      if (err is NoReleasesError && additionalSettings['trackOnly'] == true) {
        return await _fetchReleaseDetails(
          await reqUrlGenerator(true),
          standardUrl,
          additionalSettings,
          onHttpErrorCode: onHttpErrorCode,
        );
      } else {
        rethrowOrWrapError(err);
      }
    }
  }

  /// Fork: the version literal nearly every Gradle project carries, used when
  /// a version file is named without a regex of its own.
  static const String _defaultVersionFileRegEx =
      r'versionName\s*=\s*"([^"]+)"';

  /// Fork: a tag name as a version number — "v0.2.79" -> "0.2.79", the form
  /// our forks carry in their own version names. Null for an empty tag.
  String? _versionFromTag(String? tag) {
    var t = tag?.trim() ?? '';
    if (t.length > 1 &&
        (t[0] == 'v' || t[0] == 'V') &&
        t.codeUnitAt(1) >= 48 &&
        t.codeUnitAt(1) <= 57) {
      t = t.substring(1);
    }
    return t.isEmpty ? null : t;
  }

  /// Fork: the upstream version read out of a file in the repo, at the exact
  /// commit being followed — for upstreams that never tag a release the version
  /// they ship (Jami keeps `versionName = "20260731-01"` in its
  /// `build.gradle.kts` and tags only `android/release_502`).
  ///
  /// Reading at the commit's own sha rather than at the branch tip is the whole
  /// point: the version string then describes one commit consistently, instead
  /// of pairing a sha with a version literal that moved after it.
  ///
  /// Best-effort like [_fetchUpstreamVersionPrefix] — a missing file, a
  /// non-matching regex or an over-1MB file (which the contents API declines to
  /// inline) all return null and leave the prefix to the release-tag lookup,
  /// rather than failing an update check that already succeeded.
  Future<String?> _fetchVersionFromRepoFile(
    String apiUrl,
    String sha,
    Map<String, dynamic> additionalSettings,
  ) async {
    final path = (additionalSettings['trackCommitsVersionFile'] as String?)
        ?.trim();
    if (path == null || path.isEmpty) return null;
    try {
      final Response res = await sourceRequest(
        '$apiUrl/contents/${path.split('/').map(Uri.encodeComponent).join('/')}'
        '?ref=$sha',
        additionalSettings,
      );
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['encoding'] != 'base64') return null;
      final String? content = decoded['content'] as String?;
      if (content == null || content.isEmpty) return null;
      // The API wraps its base64 at 60 columns; the decoder rejects the breaks.
      final String text = utf8.decode(
        base64.decode(content.replaceAll(RegExp(r'\s'), '')),
        allowMalformed: true,
      );
      final pattern = (additionalSettings['trackCommitsVersionRegEx'] as String?)
          ?.trim();
      final match = RegExp(
        pattern == null || pattern.isEmpty
            ? _defaultVersionFileRegEx
            : pattern,
      ).firstMatch(text);
      if (match == null) return null;
      final String? version = match.groupCount >= 1
          ? match.group(1)
          : match.group(0);
      return _versionFromTag(version);
    } catch (e) {
      return null;
    }
  }

  /// Fork: the upstream version a followed commit sits on, so the reported
  /// version reads like the fork version it is compared against
  /// ("0.2.79.2026-08-02.gbc343f35", not a bare "2026-08-02.gbc343f35").
  ///
  /// Taken from the repo's latest release tag, falling back to its newest tag
  /// for repos that tag without releasing (and for ones whose releases are all
  /// prereleases, which `releases/latest` reports as 404). Entirely
  /// best-effort: the prefix is a label, never the thing that decides whether
  /// a fork is current, so any failure here — rate limit included — simply
  /// leaves it off rather than failing an update check that already succeeded.
  Future<String?> _fetchUpstreamVersionPrefix(
    String apiUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    try {
      final Response res = await sourceRequest(
        '$apiUrl/releases/latest',
        additionalSettings,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return _versionFromTag(decoded?['tag_name'] as String?);
      }
      if (res.statusCode != 404) return null;
      final Response tagRes = await sourceRequest(
        '$apiUrl/tags?per_page=1',
        additionalSettings,
      );
      if (tagRes.statusCode != 200) return null;
      final decoded = jsonDecode(tagRes.body);
      if (decoded is! List || decoded.isEmpty) return null;
      return _versionFromTag(decoded.first?['name'] as String?);
    } catch (e) {
      return null;
    }
  }

  /// Fork: the newest commit on the tracked branch, as a pseudo-release whose
  /// version mirrors the `<upstream version>.<commit date>.g<8-char sha>` name
  /// our git-versioned forks embed in their own version — so "up to date"
  /// means "rebased onto this commit".
  ///
  /// The date is the commit's committer date **in UTC**, and is there to sort:
  /// a sha alone orders builds arbitrarily. UTC is not a detail — GitHub
  /// normalises committer dates to Z and drops the original offset, so it is
  /// the only rendering both sides can compute. The git-versioning skill was
  /// changed to match on 2026-08-06; a fork still pinning the commit's own
  /// timezone (git's `--date=format:`) will disagree by a day for any commit
  /// made late in a negative-offset evening, and a linked entry then shows an
  /// update no rebase can satisfy.
  Future<APKDetails> _fetchLatestCommitDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    final branch = (additionalSettings['trackCommitsBranch'] as String?)
        ?.trim();
    final apiUrl = await convertStandardUrlToAPIUrl(
      standardUrl,
      additionalSettings,
    );
    final url =
        '$apiUrl/commits?per_page=1'
        '${branch != null && branch.isNotEmpty ? '&sha=${Uri.encodeQueryComponent(branch)}' : ''}';
    final Response res = await sourceRequest(url, additionalSettings);
    if (res.statusCode != 200) {
      rateLimitErrorCheck(res);
      throw getObtainiumHttpError(res);
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) {
      throw NoReleasesError();
    }
    final commit = decoded.first;
    final String? sha = commit['sha'] as String?;
    if (sha == null || sha.length < 8) {
      throw NoReleasesError();
    }
    final commitData = commit['commit'];
    final String? dateString =
        commitData?['committer']?['date'] ?? commitData?['author']?['date'];
    final String? message = commitData?['message'] as String?;
    final DateTime? commitDate = dateString != null
        ? DateTime.tryParse(dateString)
        : null;
    final String datePrefix = commitDate != null
        ? '${commitDate.toUtc().toIso8601String().substring(0, 10)}.'
        : '';
    // A named version file wins: it is the version the followed commit itself
    // declares, where the release tag is only the newest one the repo happens
    // to carry. Falls back when unset, unreadable or unmatched.
    final String? upstreamVersion =
        await _fetchVersionFromRepoFile(apiUrl, sha, additionalSettings) ??
        await _fetchUpstreamVersionPrefix(apiUrl, additionalSettings);
    final String versionPrefix = upstreamVersion != null
        ? '$upstreamVersion.'
        : '';
    return APKDetails(
      '$versionPrefix$datePrefix'
      'g${sha.substring(0, 8)}',
      [],
      getAppNames(standardUrl),
      releaseDate: commitDate,
      changeLog: message,
    );
  }

  @override
  Future<APKDetails> getLatestAPKDetails(
    String standardUrl,
    Map<String, dynamic> additionalSettings,
  ) async {
    if (additionalSettings['trackCommits'] == true) {
      try {
        return await _fetchLatestCommitDetails(standardUrl, additionalSettings);
      } catch (e) {
        rethrowOrWrapError(e);
      }
    }
    try {
      return await fetchReleaseDetailsWithTagFallback(
        standardUrl,
        additionalSettings,
        (bool useTagUrl) async {
          return '${await convertStandardUrlToAPIUrl(standardUrl, additionalSettings)}/${useTagUrl ? 'tags' : 'releases'}?per_page=100';
        },
        (Response res) {
          githubErrorCheck(res);
        },
      );
    } catch (e) {
      rethrowOrWrapError(e);
    }
  }

  AppNames getAppNames(String standardUrl) {
    final String temp = standardUrl.substring(standardUrl.indexOf('://') + 3);
    final pathStart = temp.indexOf('/');
    if (pathStart < 0) throw InvalidURLError(name);
    final List<String> names = temp.substring(pathStart + 1).split('/');
    if (names.isEmpty || names[0].isEmpty) throw InvalidURLError(name);
    return AppNames(names[0], names.sublist(1).join('/'));
  }

  Future<Map<String, List<String>>> searchCommon(
    String query,
    String requestUrl,
    String rootProp, {
    Function(Response)? onHttpErrorCode,
    Map<String, dynamic> querySettings = const {},
  }) async {
    final Response res = await sourceRequest(requestUrl, {});
    if (res.statusCode == 200) {
      final int minStarCount =
          int.tryParse(querySettings['minStarCount']?.toString() ?? '') ?? 0;
      final Map<String, List<String>> urlsWithDescriptions = {};
      for (var e in (jsonDecode(res.body)[rootProp] as List<dynamic>)) {
        if ((e['stargazers_count'] ?? e['stars_count'] ?? 0) >= minStarCount) {
          urlsWithDescriptions.addAll({
            e['html_url'] as String: [
              e['full_name'] as String,
              ((e['archived'] == true ? '[ARCHIVED] ' : '') +
                  (e['description'] != null
                      ? e['description'] as String
                      : tr('noDescription'))),
            ],
          });
        }
      }
      return urlsWithDescriptions;
    } else {
      if (onHttpErrorCode != null) {
        onHttpErrorCode(res);
      }
      throw getObtainiumHttpError(res);
    }
  }

  String undoGHProxyMod(
    String reqUrl,
    Map<String, String> sourceConfigSettingValues,
  ) {
    final ghReqPrefix = sourceConfigSettingValues['GHReqPrefix'];
    if (ghReqPrefix == null || ghReqPrefix.isEmpty) return reqUrl;
    final prefix = 'https://$ghReqPrefix/';
    return reqUrl.startsWith(prefix) ? reqUrl.substring(prefix.length) : reqUrl;
  }

  @override
  Future<Map<String, List<String>>> search(
    String query, {
    Map<String, dynamic> querySettings = const {},
  }) async {
    final sp = SettingsProvider();
    await sp.initializeSettings();
    final sourceConfigSettingValues = await getSourceConfigValues({}, sp);
    final results = await searchCommon(
      query,
      '${await getAPIHost({})}/search/repositories?q=${Uri.encodeQueryComponent(query)}&per_page=100',
      'items',
      onHttpErrorCode: (Response res) {
        githubErrorCheck(res);
      },
      querySettings: querySettings,
    );
    if ((sourceConfigSettingValues['GHReqPrefix'] ?? '').isNotEmpty) {
      final Map<String, List<String>> results2 = {};
      results.forEach((k, v) {
        results2[undoGHProxyMod(k, sourceConfigSettingValues)] = v;
      });
      return results2;
    } else {
      return results;
    }
  }

  void rateLimitErrorCheck(Response res) {
    if (res.headers['x-ratelimit-remaining'] == '0') {
      final now = DateTime.now();
      final resetEpochSeconds =
          int.tryParse(res.headers['x-ratelimit-reset'] ?? '') ??
          now.millisecondsSinceEpoch ~/ 1000 + _fallbackCacheSeconds;
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final remainingMinutes = ((resetEpochSeconds - nowSeconds) / 60)
          .ceil()
          .clamp(0, 9999);
      throw RateLimitError(remainingMinutes);
    }
  }

  /// Throws the actual GitHub error for failed API responses: rate limits
  /// (when the headers say so) and auth problems (e.g. a token that is not
  /// authorized for this repository), which the generic handler would
  /// otherwise mislabel as a rate limit (see #3211).
  void githubErrorCheck(Response res) {
    rateLimitErrorCheck(res);
    if (res.statusCode == 401 || res.statusCode == 403) {
      try {
        final message = (jsonDecode(res.body)['message'] as String?)?.trim();
        if (message != null &&
            message.isNotEmpty &&
            !message.toLowerCase().contains('rate limit')) {
          throw ObtainiumError(message);
        }
      } catch (_) {
        // Not a JSON error body; fall through to the generic handler.
      }
    }
  }
}
