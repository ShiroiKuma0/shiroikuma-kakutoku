import 'package:easy_localization/easy_localization.dart';
import 'package:obtainium/components/generated_form_renderer.dart';
import 'package:obtainium/components/sk_installed_app_picker.dart';
import 'package:obtainium/components/ui_widgets.dart';
import 'package:obtainium/custom_errors.dart';
import 'package:obtainium/providers/apps_provider.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/providers/sk_linked_version.dart';
import 'package:obtainium/providers/source_provider.dart';
import 'package:obtainium/sk_material.dart';
import 'package:obtainium/utils/nav_helper.dart';
import 'package:provider/provider.dart';

/// Opens the additional-options page for an app, optionally scrolled to the
/// section with the given [GeneratedFormHeader.id], and applies the changes.
Future<void> showAppAdditionalOptions(
  BuildContext context,
  String appId, {
  String? scrollToSection,
}) async {
  final appsProvider = context.read<AppsProvider>();
  final app = appsProvider.apps[appId];
  if (app == null) return;
  AppSource? source;
  try {
    source = SourceProvider().getSource(
      app.app.url,
      overrideSource: app.app.overrideSource,
    );
  } catch (_) {
    source = null;
  }
  final values = await showAdditionalOptionsPage(
    context,
    source,
    app,
    scrollToSection: scrollToSection,
  );
  if (values == null || !context.mounted) return;
  await applyAdditionalOptionChanges(context, source, app, values);
}

Future<Map<String, dynamic>?> showAdditionalOptionsPage(
  BuildContext context,
  AppSource? source,
  AppInMemory? app, {
  String? scrollToSection,
}) {
  Map<String, dynamic> values = {};

  // Fork: the "compare against installed app" row gets an app-picker button
  // (and a typeahead over installed packages, which is what makes the row
  // usable on TV and with a hardware keyboard). Picking rebuilds the form
  // with a fresh trailingKey — GeneratedForm re-initialises when the item
  // hash changes, which is how the new value reaches the field.
  final List<String> packageOptions =
      skInstalledPackages
          .where((p) => p.packageName != null && skIsUserApp(p))
          .map((p) => p.packageName!)
          .toList()
        ..sort();

  List<List<GeneratedFormItem>> buildItems(
    int pickerRevision,
    VoidCallback onPicked,
  ) {
    return (source?.combinedAppSpecificSettingFormItems ?? []).map((row) {
      return row.map((e) {
        // Seed from the live form state so an edit made before opening the
        // picker survives the rebuild, falling back to the saved settings.
        final current = values.containsKey(e.key)
            ? values[e.key]
            : app?.app.additionalSettings[e.key];
        if (current != null) {
          e.value = current;
        }
        // Fork: the Title field opens holding the title the entry currently
        // shows, so renaming one is an edit rather than a retype. Leaving it
        // as found stores nothing (see applyAdditionalOptionChanges), which
        // is what keeps an unrenamed entry following its source and its
        // linked build.
        if (e.key == 'appName' &&
            app != null &&
            (e.value as String?)?.trim().isEmpty != false) {
          e.value = app.autoName;
        }
        if (e.key != skLinkedPackageKey || e is! GeneratedFormTextField) {
          return e;
        }
        return GeneratedFormTextField(
          e.key,
          label: e.label,
          value: (e.value ?? '') as String,
          required: false,
          hint: e.hint,
          autoCompleteOptions: packageOptions,
          trailingKey: 'linkedPicker$pickerRevision',
          trailing: IconButton(
            icon: const Icon(Icons.apps),
            tooltip: tr('pickInstalledApp'),
            onPressed: onPicked,
          ),
        );
      }).toList();
    }).toList();
  }

  return Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      traversalEdgeBehavior: traversalEdgeBehaviorFor(context),
      builder: (ctx) => PopScope<Map<String, dynamic>>(
        // Leaving the page saves the settings; the Save button on the page
        // only says so and gives an explicit way out.
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          // While a text field is being edited, the first BACK only dismisses
          // the keyboard; it must not also save and leave.
          if (isEditingTextField()) {
            FocusManager.instance.primaryFocus?.unfocus();
            return;
          }
          Navigator.of(ctx).pop(values);
        },
        child: _AdditionalOptionsPage(
          title: tr('additionalOptions'),
          buildItems: buildItems,
          scrollToSection: scrollToSection,
          onValuesChanged: (v) => values = v,
          onSave: () => Navigator.of(ctx).pop(values),
          pickLinked: (pageContext) async {
            final picked = await showSkInstalledAppPicker(
              pageContext,
              selected:
                  (values[skLinkedPackageKey] ??
                          app?.app.additionalSettings[skLinkedPackageKey])
                      as String?,
              matchApp: app?.app,
            );
            if (picked == null) return false;
            values[skLinkedPackageKey] = picked;
            return true;
          },
        ),
      ),
    ),
  );
}

Future<void> applyAdditionalOptionChanges(
  BuildContext context,
  AppSource? source,
  AppInMemory app,
  Map<String, dynamic> values, {
  ValueChanged<bool>? onBusyChanged,
}) async {
  final appsProvider = context.read<AppsProvider>();
  final Map<String, dynamic> originalSettings = app.app.additionalSettings;
  // Fork: the options form knows nothing about a waved-through version, so
  // handing its values back wholesale would drop the mark and the entry
  // would report the same push as an update again.
  final String? setUpdatedVersion = skSetUpdatedVersion(app.app);
  // Fork: the Title field was prefilled with the automatic title, so handing
  // it back unchanged must not freeze that text as an override — it would
  // then stop following a renamed linked build or a renamed upstream. Only a
  // title the user actually altered is stored.
  final String prefilledTitle = app.autoName;
  final String? typedTitle = (values['appName'] as String?)?.trim();
  if (typedTitle != null && typedTitle == prefilledTitle) {
    values = Map<String, dynamic>.from(values)..['appName'] = '';
  }
  final savedValues = Map<String, dynamic>.from(values);
  // The additional-options form does not include every stored setting
  // (e.g. the add-time package ID field and source-config overrides such as
  // credentials), so carry those over instead of dropping them.
  originalSettings.forEach((key, value) {
    savedValues.putIfAbsent(key, () => value);
  });
  app.app = app.app.copyWith(additionalSettings: savedValues);
  if (setUpdatedVersion != null) {
    app.app = app.app.copyWith(
      additionalSettings: skSettingsWithSetUpdated(app.app, setUpdatedVersion),
    );
  }
  if (source?.enforceTrackOnlyFor(app.app.additionalSettings) == true) {
    app.app = app.app.copyWith(
      additionalSettings: Map<String, dynamic>.from(app.app.additionalSettings)
        ..['trackOnly'] = true,
    );
    if (context.mounted) {
      showMessage(tr('appsFromSourceAreTrackOnly'), context);
    }
  }
  // Fork: an app compared against a local build must never install the
  // upstream APK over it, so linking implies track-only.
  if (skLinkedPackage(app.app) != null &&
      !app.app.settings.getBool('trackOnly')) {
    app.app = app.app.copyWith(
      additionalSettings: Map<String, dynamic>.from(app.app.additionalSettings)
        ..['trackOnly'] = true,
    );
    if (context.mounted) {
      showMessage(tr('linkedAppsAreTrackOnly'), context);
    }
  }
  final versionDetectionEnabled =
      app.app.settings.getBool('versionDetection') &&
      originalSettings['versionDetection'] != true;
  final releaseDateVersionEnabled =
      app.app.settings.getBool('releaseDateAsVersion') &&
      originalSettings['releaseDateAsVersion'] != true;
  final releaseDateVersionDisabled =
      !app.app.settings.getBool('releaseDateAsVersion') &&
      originalSettings['releaseDateAsVersion'] == true;
  if (releaseDateVersionEnabled) {
    if (app.app.releaseDate != null) {
      final bool isUpdated = app.app.installedVersion == app.app.latestVersion;
      app.app = app.app.copyWith(
        latestVersion: app.app.releaseDate!.microsecondsSinceEpoch.toString(),
      );
      if (isUpdated) {
        app.app = app.app.copyWith(installedVersion: app.app.latestVersion);
      }
    }
  } else if (releaseDateVersionDisabled) {
    app.app = app.app.copyWith(
      installedVersion:
          app.installedInfo?.versionName ?? app.app.installedVersion,
    );
  }
  if (versionDetectionEnabled) {
    app.app = app.app.copyWith(
      additionalSettings: Map<String, dynamic>.from(app.app.additionalSettings)
        ..['versionDetection'] = true
        ..['releaseDateAsVersion'] = false,
    );
  }
  await appsProvider.saveApps([app.app]);
  if (!context.mounted) return;
  await refreshAppMetadata(
    context,
    appId: app.app.id,
    resetVersion: versionDetectionEnabled,
    onBusyChanged: onBusyChanged,
  );
}

/// Re-fetches an app's metadata, optionally resetting its version-detection
/// state, and reports transient busy state through [onBusyChanged].
Future<void> refreshAppMetadata(
  BuildContext context, {
  required String appId,
  bool resetVersion = false,
  ValueChanged<bool>? onBusyChanged,
}) async {
  final appsProvider = context.read<AppsProvider>();
  onBusyChanged?.call(true);
  try {
    await appsProvider.checkUpdate(appId);
    if (resetVersion) {
      final currentAim = appsProvider.apps[appId];
      if (currentAim != null) {
        var updatedApp = currentAim.app.copyWith(
          additionalSettings: Map<String, dynamic>.from(
            currentAim.app.additionalSettings,
          )..['versionDetection'] = true,
        );
        if (updatedApp.installedVersion != null) {
          updatedApp = updatedApp.copyWith(
            installedVersion: updatedApp.latestVersion,
          );
        }
        await appsProvider.saveApps([updatedApp]);
      }
    }
  } catch (err) {
    if (err is RepositoryRenamedError && context.mounted) {
      await appsProvider.updatePendingRepoRename(appId, err.newUrl);
    } else if (context.mounted) {
      showError(err, context);
    }
  } finally {
    onBusyChanged?.call(false);
  }
}

class _AdditionalOptionsPage extends StatefulWidget {
  const _AdditionalOptionsPage({
    required this.title,
    required this.buildItems,
    required this.onValuesChanged,
    required this.onSave,
    required this.pickLinked,
    this.scrollToSection,
  });

  final String title;

  /// Fork: the form's items, rebuilt whenever the linked-app picker hands a
  /// package back (see [showAdditionalOptionsPage]).
  final List<List<GeneratedFormItem>> Function(
    int pickerRevision,
    VoidCallback onPicked,
  )
  buildItems;
  final ValueChanged<Map<String, dynamic>> onValuesChanged;

  /// Fork: leaves the page with the current values.
  final VoidCallback onSave;

  /// Fork: opens the installed-app picker; true when a package was picked.
  final Future<bool> Function(BuildContext context) pickLinked;
  final String? scrollToSection;

  @override
  State<_AdditionalOptionsPage> createState() => _AdditionalOptionsPageState();
}

class _AdditionalOptionsPageState extends State<_AdditionalOptionsPage> {
  int _pickerRevision = 0;

  Future<void> _pickLinked() async {
    if (await widget.pickLinked(context) && mounted) {
      setState(() => _pickerRevision++);
    }
  }

  @override
  void initState() {
    super.initState();
    final target = widget.scrollToSection;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(target));
    }
  }

  Future<void> _scrollTo(String sectionId) async {
    BuildContext? targetContext;
    for (var attempt = 0; attempt < 4; attempt++) {
      targetContext = GlobalObjectKey(sectionId).currentContext;
      if (targetContext != null) break;
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
    }
    if (targetContext == null || !targetContext.mounted) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          CustomAppBar(title: widget.title),
          // Fork: leaving the page already saves, but nothing said so — this
          // states the outcome and gives an explicit way out. It is the main
          // action of the page.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    context.read<SettingsProvider>().selectionClick();
                    widget.onSave();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(tr('saveChanges')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                MediaQuery.of(context).padding.bottom,
              ),
              child: TvInitialFocus(
                child: GeneratedForm(
                  tileMode: true,
                  items: widget.buildItems(_pickerRevision, _pickLinked),
                  onValueChanges: (v, valid, isBuilding) {
                    widget.onValuesChanged(v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
