// shiroikuma-kakutoku fork: the icons of upstream's switch rows.
//
// Upstream's ToggleTile takes a label and nothing else, and its forty call
// sites are upstream's to keep. So the icon is found from the label: the
// table below is keyed by translation key, and a row whose key is not in it
// yet still gets the plain toggle icon, so the icon column never breaks. A
// new upstream switch row gets its line here on the sync that brings it.

import 'package:easy_localization/easy_localization.dart' show tr;
import 'package:obtainium/components/sk_pills.dart';
import 'package:obtainium/components/sk_ui_widgets.dart';
import 'package:obtainium/sk_material.dart';
import 'package:obtainium/providers/sk_roles.dart';

const Map<String, (IconData, SkIconRole)> _toggleIcons = {
  'allowAddingAppsWithoutCheck': (Icons.add_task, SkIconRole.message),
  'alwaysUsePhoneLayout': (Icons.smartphone, SkIconRole.view),
  'androidCertStore': (Icons.verified_user_outlined, SkIconRole.block),
  'autoExportOnChanges': (Icons.save_alt, SkIconRole.share),
  'beforeNewInstallsShareToAppVerifier': (
    Icons.share_outlined,
    SkIconRole.share,
  ),
  'checkOnStart': (Icons.refresh, SkIconRole.call),
  'checkSystemDisabledApps': (Icons.sync, SkIconRole.call),
  'checkUpdateOnDetailPage': (Icons.update, SkIconRole.call),
  'collapseGroupsOnStartup': (Icons.unfold_less, SkIconRole.view),
  'disableSwipeActions': (Icons.swipe, SkIconRole.block),
  'dontShowAPKOriginWarnings': (Icons.warning_amber, SkIconRole.block),
  'dontShowTrackOnlyWarnings': (Icons.warning_amber, SkIconRole.block),
  'enableBackgroundSilentInstalls': (Icons.download_outlined, SkIconRole.call),
  'enableCertificatePinning': (Icons.push_pin_outlined, SkIconRole.block),
  'exportInstalledOnly': (Icons.file_upload_outlined, SkIconRole.share),
  'hideDowngrades': (Icons.visibility_off_outlined, SkIconRole.block),
  'highlightTouchTargets': (Icons.touch_app_outlined, SkIconRole.view),
  'includePrereleasesByDefault': (Icons.science_outlined, SkIconRole.view),
  'includeSubdomains': (Icons.account_tree_outlined, SkIconRole.view),
  'moveNonInstalledAppsToBottom': (
    Icons.vertical_align_bottom,
    SkIconRole.view,
  ),
  'onlyCheckInstalledOrTrackOnlyApps': (
    Icons.filter_alt_outlined,
    SkIconRole.view,
  ),
  'parallelDownloads': (Icons.downloading, SkIconRole.call),
  'pinUpdates': (Icons.push_pin_outlined, SkIconRole.view),
  'removeOnExternalUninstall': (Icons.delete_outline, SkIconRole.delete),
  'shizukuPretendToBeGooglePlay': (
    Icons.storefront_outlined,
    SkIconRole.contact,
  ),
  'showAppDowngradeError': (Icons.error_outline, SkIconRole.view),
  'showUpdateHealthIndicator': (Icons.monitor_heart_outlined, SkIconRole.view),
  'showWebInAppView': (Icons.public, SkIconRole.view),
  'skipBulkUpdateConfirmation': (Icons.skip_next, SkIconRole.block),
  'tactileFeedbackEnabled': (Icons.vibration, SkIconRole.view),
  'updateHealthArchivedCheck': (Icons.archive_outlined, SkIconRole.view),
  'useBlackTheme': (Icons.dark_mode_outlined, SkIconRole.view),
  'useRefreshButton': (Icons.refresh, SkIconRole.call),
  'useSystemFont': (Icons.font_download_outlined, SkIconRole.message),
  'verifySigningCertHashes': (Icons.verified_outlined, SkIconRole.block),
};

/// The icon of the switch row labelled [label], coloured by what the row
/// does and sized by the label — or null while the 白い熊 獲得 UI is switched
/// off, when the row keeps upstream's look.
Widget? skToggleLeading(BuildContext context, String label) {
  if (SkPalette.maybeOf(context) == null) return null;
  var entry = (Icons.toggle_on_outlined, SkIconRole.view);
  for (final e in _toggleIcons.entries) {
    if (tr(e.key) == label) {
      entry = e.value;
      break;
    }
  }
  return SkRoleIcon(
    entry.$1,
    role: entry.$2,
    size: skRowIconSize(Theme.of(context).textTheme.bodyLarge),
  );
}
