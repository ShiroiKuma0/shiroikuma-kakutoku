// shiroikuma-kakutoku fork: drop-in replacements for the Material
// widgets whose look the theme alone cannot reach. They carry Material's own
// names and are picked up by import (lib/sk_material.dart), so upstream's
// call sites stay exactly as upstream wrote them:
//
//  * AlertDialog — its buttons follow the pill rule (the main action 3 dp
//    and bold, the others 1.25 dp, a deleting one red);
//  * Switch — the outlined pill with a solid dot, never filled.
//
//  * SwitchListTile — a list row with that same switch at its right.
//
// While the 白い熊 獲得 UI is switched off, all three are plain Material again.

import 'package:material_ui/material_ui.dart' as m;
import 'package:material_ui/material_ui.dart'
    hide AlertDialog, Switch, SwitchListTile;
import 'package:obtainium/components/sk_pills.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';

class AlertDialog extends m.AlertDialog {
  /// Same arguments as Material's, plus [destructive] for a dialog whose
  /// main action deletes something.
  AlertDialog({
    super.key,
    super.icon,
    super.iconPadding,
    super.iconColor,
    super.title,
    super.titlePadding,
    super.titleTextStyle,
    super.content,
    super.contentPadding,
    super.contentTextStyle,
    List<Widget>? actions,
    super.actionsPadding,
    super.actionsAlignment,
    super.actionsOverflowAlignment,
    super.actionsOverflowDirection,
    super.actionsOverflowButtonSpacing = 6,
    super.buttonPadding,
    super.backgroundColor,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.semanticLabel,
    super.insetPadding,
    super.clipBehavior,
    super.shape,
    super.alignment,
    super.constraints,
    super.scrollable,
    bool destructive = false,
  }) : super(actions: skDialogActions(actions, destructive: destructive));
}

class Switch extends StatelessWidget {
  const Switch({
    super.key,
    required this.value,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    if (SkPalette.maybeOf(context) == null) {
      return m.Switch(
        value: value,
        onChanged: onChanged,
        focusNode: focusNode,
        autofocus: autofocus,
      );
    }
    return SkSwitch(value: value, onChanged: onChanged);
  }
}

class SwitchListTile extends StatelessWidget {
  const SwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
    this.autofocus = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    if (SkPalette.maybeOf(context) == null) {
      return m.SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        contentPadding: contentPadding,
        dense: dense,
        autofocus: autofocus,
      );
    }
    final changed = onChanged;
    return ListTile(
      contentPadding: contentPadding,
      dense: dense,
      autofocus: autofocus,
      enabled: changed != null,
      leading: secondary,
      title: title,
      subtitle: subtitle,
      // The whole row is the touch target, so the switch only shows the state.
      trailing: IgnorePointer(
        child: SkSwitch(
          value: value,
          onChanged: changed == null ? null : (_) {},
        ),
      ),
      onTap: changed == null ? null : () => changed(!value),
    );
  }
}
