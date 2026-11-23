// shiroikuma-kakutoku fork: Material, with the fork's drop-in AlertDialog,
// Switch and SwitchListTile in place of Material's own (lib/components/sk_dropins.dart).
//
// Every screen imports this file instead of package:material_ui — that one
// import line is the whole change to an upstream file, and it is what gives
// its dialogs and switches the black-yellow look. After a rebase, a new
// upstream file that imports material_ui directly must be switched over:
//
//   grep -rL sk_material lib | xargs grep -l "material_ui/material_ui.dart"
//
// should list only the fork's own sk_* files.

export 'package:material_ui/material_ui.dart'
    hide AlertDialog, Switch, SwitchListTile;
export 'package:obtainium/components/sk_dropins.dart'
    show AlertDialog, Switch, SwitchListTile;
