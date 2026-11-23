// shiroikuma-kakutoku fork: the black-yellow look every 白い熊 app shares, in
// one place — the outlined switch, dialog buttons that follow the pill rule,
// menu rows drawn as full-width pills, and icons coloured by what their row
// does. Nothing here is ever filled, and no colour is written here: every
// one is a role (lib/providers/sk_roles.dart).

import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';
import 'package:obtainium/sk_theme.dart';

// ---------------------------------------------------------------------------
// Icons coloured by role
// ---------------------------------------------------------------------------

/// What a row does, told from the icon it was given. Call sites mostly name
/// only an icon, so this is the one table that colours every list, sheet and
/// menu; a row can still pass its role outright.
SkIconRole skIconRoleFor(IconData? icon) {
  if (icon == null) return SkIconRole.view;
  if (_deleteIcons.contains(icon)) return SkIconRole.delete;
  if (_shareIcons.contains(icon)) return SkIconRole.share;
  if (_callIcons.contains(icon)) return SkIconRole.call;
  if (_messageIcons.contains(icon)) return SkIconRole.message;
  if (_contactIcons.contains(icon)) return SkIconRole.contact;
  if (_blockIcons.contains(icon)) return SkIconRole.block;
  return SkIconRole.view;
}

final Set<IconData> _deleteIcons = <IconData>{
  Icons.delete,
  Icons.delete_outline,
  Icons.delete_outline_rounded,
  Icons.delete_forever,
  Icons.delete_sweep,
  Icons.delete_sweep_outlined,
  Icons.clear_all,
  Icons.cleaning_services,
  Icons.remove_circle,
  Icons.remove_circle_outline,
  Icons.playlist_remove,
  Icons.restart_alt,
};

final Set<IconData> _shareIcons = <IconData>{
  Icons.copy,
  Icons.copy_all,
  Icons.share,
  Icons.share_outlined,
  Icons.share_rounded,
  Icons.ios_share,
  Icons.backup,
  Icons.restore,
  Icons.save,
  Icons.save_alt,
  Icons.file_upload,
  Icons.file_upload_outlined,
  Icons.file_download,
  Icons.file_download_outlined,
  Icons.upload,
  Icons.upload_file,
  Icons.import_export,
  Icons.send,
  Icons.folder_open,
  Icons.folder_outlined,
  Icons.key,
  Icons.vpn_key_outlined,
};

final Set<IconData> _callIcons = <IconData>{
  Icons.play_arrow,
  Icons.download,
  Icons.download_outlined,
  Icons.download_rounded,
  Icons.file_download_done,
  Icons.cloud_download,
  Icons.install_mobile,
  Icons.install_mobile_outlined,
  Icons.system_update,
  Icons.system_update_alt,
  Icons.update,
  Icons.update_outlined,
  Icons.refresh,
  Icons.refresh_rounded,
  Icons.sync,
  Icons.launch,
  Icons.open_in_new,
  Icons.open_in_browser,
  Icons.search,
  Icons.check,
  Icons.check_circle_outline,
  Icons.done_all,
  Icons.toggle_on_outlined,
  Icons.linear_scale,
};

final Set<IconData> _messageIcons = <IconData>{
  Icons.edit,
  Icons.edit_outlined,
  Icons.edit_note,
  Icons.mode_edit,
  Icons.drive_file_rename_outline,
  Icons.add,
  Icons.add_circle,
  Icons.add_circle_outline,
  Icons.playlist_add,
  Icons.bookmark,
  Icons.push_pin,
  Icons.push_pin_outlined,
  Icons.star,
  Icons.text_fields,
  Icons.title,
  Icons.font_download_outlined,
  Icons.format_size,
  Icons.format_bold,
  Icons.chat_bubble_outline,
  Icons.notifications_outlined,
  Icons.check_box_outlined,
  Icons.select_all,
  Icons.select_all_outlined,
  Icons.bug_report_outlined,
};

final Set<IconData> _contactIcons = <IconData>{
  Icons.person,
  Icons.account_circle,
  Icons.group,
  Icons.apps,
  Icons.android,
  Icons.category,
  Icons.category_outlined,
  Icons.label_outline,
  Icons.palette_outlined,
  Icons.brush_outlined,
  Icons.color_lens_outlined,
  Icons.interests_outlined,
  Icons.label_important_outline,
  Icons.colorize,
};

final Set<IconData> _blockIcons = <IconData>{
  Icons.visibility_off,
  Icons.visibility_off_outlined,
  Icons.hide_source,
  Icons.block,
  Icons.stop,
  Icons.close,
  Icons.cancel,
  Icons.cancel_outlined,
  Icons.unfold_less,
  Icons.pause,
  Icons.skip_next,
  Icons.skip_next_outlined,
  Icons.deselect,
  Icons.build_outlined,
  Icons.lock_outline,
};

/// An icon coloured by what its row does — the leading icon of a list row, a
/// sheet option or a settings row. See [skIconRoleFor]. While the 白い熊 獲得
/// UI is switched off it is a plain icon in [fallback].
class SkRoleIcon extends StatelessWidget {
  const SkRoleIcon(this.icon, {super.key, this.role, this.size, this.fallback});

  final IconData icon;
  final SkIconRole? role;
  final double? size;
  final Color? fallback;

  @override
  Widget build(BuildContext context) {
    final p = SkPalette.maybeOf(context);
    return Icon(
      icon,
      size: size,
      color: p == null ? fallback : p.icon(role ?? skIconRoleFor(icon)),
    );
  }
}

// ---------------------------------------------------------------------------
// The outlined switch
// ---------------------------------------------------------------------------

/// The theme's switch: an outlined pill with the ground showing through and a
/// solid dot inside it — right when on, left when off. Only the brightness
/// and the dot's side change between the states; nothing is ever filled.
class SkSwitch extends StatelessWidget {
  /// Same contract as [Switch]: a null [onChanged] disables it.
  const SkSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// The smaller size that sits in a menu row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = SkPalette.of(context);
    final size = compact ? const Size(44, 24) : const Size(52, 28);
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Opacity(
            opacity: enabled ? 1 : skDisabledAlpha,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: value ? 1 : 0),
              duration: const Duration(milliseconds: 180),
              curve: Curves.decelerate,
              builder: (context, position, _) => CustomPaint(
                size: size,
                painter: _SkSwitchPainter(
                  position: position,
                  outline: Color.lerp(
                    p[SkRole.switchOffOutline],
                    p[SkRole.switchOnOutline],
                    position,
                  )!,
                  dot: Color.lerp(
                    p[SkRole.switchOffDot],
                    p[SkRole.switchOnDot],
                    position,
                  )!,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkSwitchPainter extends CustomPainter {
  _SkSwitchPainter({
    required this.position,
    required this.outline,
    required this.dot,
  });

  final double position;
  final Color outline;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    final track = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(stroke / 2),
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = outline,
    );
    // The dot is 46 % of the track's height and keeps the same gap to the
    // frame all round.
    final radius = size.height * 0.46 / 2;
    final edge = size.height / 2;
    final x = edge + (size.width - 2 * edge) * position;
    canvas.drawCircle(Offset(x, size.height / 2), radius, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_SkSwitchPainter old) =>
      old.position != position || old.outline != outline || old.dot != dot;
}

// ---------------------------------------------------------------------------
// Dialog buttons
// ---------------------------------------------------------------------------

/// Labels that only leave the dialog; such a button is never the main one.
bool _isWayOut(String label) {
  final upper = label.trim().toUpperCase();
  for (final key in const ['cancel', 'close', 'no', 'dismiss']) {
    if (upper == tr(key).toUpperCase()) return true;
  }
  return const {
    'CANCEL',
    'CLOSE',
    'NO',
    'BACK',
    'SKIP',
    'LATER',
    'NOT NOW',
    'DISMISS',
  }.contains(upper);
}

/// Labels that destroy something; such a button is drawn in the delete red,
/// frame and label alike.
bool _isDestructive(String label) {
  final upper = label.trim().toUpperCase();
  if (upper == tr('remove').toUpperCase()) return true;
  return const {
    'DELETE',
    'REMOVE',
    'CLEAR',
    'PURGE',
    'WIPE',
    'DISCARD',
    'OVERWRITE',
  }.contains(upper);
}

String? _labelOf(Widget action) {
  if (action is! ButtonStyleButton) return null;
  final child = action.child;
  return child is Text ? child.data : null;
}

/// Wraps each of a dialog's [actions] so it draws as the pill its part calls
/// for, without the call site saying so: the one action that is not a way
/// out (Cancel, Close, No…) is the main pill — a button upstream drew filled
/// wins where there are several — and the rest are regular. With
/// [destructive], or a label that deletes, the main pill is red.
List<Widget>? skDialogActions(List<Widget>? actions, {bool destructive = false}) {
  if (actions == null) return null;
  final candidates = [
    for (final a in actions)
      if (a is ButtonStyleButton && !_isWayOut(_labelOf(a) ?? '')) a,
  ];
  final filled = candidates.whereType<FilledButton>().toList();
  final Widget? main = candidates.length == 1
      ? candidates.single
      : filled.length == 1
      ? filled.single
      : candidates.isNotEmpty
      ? candidates.last
      : null;
  return [
    for (final a in actions)
      if (a is ButtonStyleButton)
        _SkDialogAction(
          main: identical(a, main),
          destructive:
              _isDestructive(_labelOf(a) ?? '') ||
              (destructive && identical(a, main)),
          child: a,
        )
      else
        a,
  ];
}

class _SkDialogAction extends StatelessWidget {
  const _SkDialogAction({
    required this.child,
    required this.main,
    required this.destructive,
  });

  final ButtonStyleButton child;
  final bool main;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = SkPalette.maybeOf(context);
    // Upstream's own look while the 白い熊 獲得 UI is switched off.
    if (p == null) return child;
    final style = skPillStyle(
      frame: destructive ? p[SkRole.delete] : p[SkRole.dialogButtonFrame],
      label: destructive ? p[SkRole.delete] : p[SkRole.dialogButtonLabel],
      ground: p[SkRole.dialogGround],
      base: Theme.of(context).textTheme.labelLarge,
      main: main,
    );
    // Dialog buttons touch each other, so each pill keeps a little air.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButtonTheme(
        data: TextButtonThemeData(style: style),
        child: FilledButtonTheme(
          data: FilledButtonThemeData(style: style),
          child: OutlinedButtonTheme(
            data: OutlinedButtonThemeData(style: style),
            child: ElevatedButtonTheme(
              data: ElevatedButtonThemeData(style: style),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The style of a button that deletes: the delete red on frame and label,
/// still unfilled. Null while the 白い熊 獲得 UI is switched off, so a call
/// site can fall back to what upstream draws: `skDeletePill(context) ?? …`.
ButtonStyle? skDeletePill(BuildContext context, {bool main = false}) {
  final p = SkPalette.maybeOf(context);
  if (p == null) return null;
  return skPillStyle(
    frame: p[SkRole.delete],
    label: p[SkRole.delete],
    ground: p[SkRole.buttonGround],
    base: Theme.of(context).textTheme.labelLarge,
    main: main,
  );
}

// ---------------------------------------------------------------------------
// Menu rows
// ---------------------------------------------------------------------------

/// A menu row. An action row is an outlined pill as wide as the menu, its
/// icon inside at the left, coloured by what the row does, and a › at the
/// right when it opens something; a row with [checked] set is a toggle and
/// stays plain, with the outlined switch at its right. Flutter's popup
/// already uses the whole screen height before it scrolls.
class SkMenuItem<T> extends PopupMenuItem<T> {
  const SkMenuItem({
    super.key,
    required this.label,
    super.value,
    super.onTap,
    super.enabled,
    this.icon,
    this.role,
    this.opens = false,
    this.checked,
    this.iconColumn = true,
  }) : super(child: null, padding: EdgeInsets.zero, height: 0);

  final String label;
  final IconData? icon;

  /// What the row does; [SkIconRole.delete] also colours frame and label.
  final SkIconRole? role;

  /// Whether the row opens a screen, dialog, picker or submenu.
  final bool opens;

  /// Non-null makes this a toggle row showing this state.
  final bool? checked;

  /// Keep the icon column when [icon] is null, so labels share one edge.
  /// False only for lists of pure choices, where no row has an icon.
  final bool iconColumn;

  @override
  PopupMenuItemState<T, SkMenuItem<T>> createState() => _SkMenuItemState<T>();
}

class _SkMenuItemState<T> extends PopupMenuItemState<T, SkMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    final p = SkPalette.of(context);
    final role = widget.role ?? skIconRoleFor(widget.icon);
    final destructive = role == SkIconRole.delete;
    final rowColor = destructive ? p[SkRole.delete] : p[SkRole.menuLabel];
    final frame = destructive ? rowColor : p[SkRole.menuRowFrame];
    final toggle = widget.checked != null;
    final base = Theme.of(context).textTheme.bodyMedium;
    final size = (base?.fontSize ?? 14) + 6;

    final content = Row(
      children: [
        if (widget.icon != null)
          Icon(widget.icon, size: size, color: p.icon(role))
        else if (widget.iconColumn)
          SizedBox(width: size),
        if (widget.icon != null || widget.iconColumn) const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.label,
            style: base?.copyWith(color: rowColor),
          ),
        ),
        if (toggle) ...[
          const SizedBox(width: 8),
          IgnorePointer(
            child: SkSwitch(
              value: widget.checked!,
              onChanged: (_) {},
              compact: true,
            ),
          ),
        ] else if (widget.opens) ...[
          const SizedBox(width: 8),
          Text(
            '›',
            style: TextStyle(fontSize: size + 2, height: 1, color: rowColor),
          ),
        ],
      ],
    );

    const shape = StadiumBorder();
    final Widget row = toggle
        ? InkWell(
            onTap: widget.enabled ? handleTap : null,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: content,
              ),
            ),
          )
        : Material(
            type: MaterialType.transparency,
            shape: StadiumBorder(
              side: BorderSide(color: frame, width: skPillRegularWidth),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.enabled ? handleTap : null,
              customBorder: shape,
              splashColor: rowColor.withValues(alpha: 0.3),
              highlightColor: rowColor.withValues(alpha: 0.15),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 42),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: content,
                ),
              ),
            ),
          );

    return Semantics(
      enabled: widget.enabled,
      button: true,
      child: Opacity(
        opacity: widget.enabled ? 1 : skDisabledAlpha,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: row,
        ),
      ),
    );
  }
}

/// The line between two groups of a menu: 1 dp, a clear darker accent, its
/// ends on the pill edges.
class SkMenuDivider extends PopupMenuEntry<Never> {
  const SkMenuDivider({super.key});

  @override
  double get height => 9;

  @override
  bool represents(void value) => false;

  @override
  State<SkMenuDivider> createState() => _SkMenuDividerState();
}

class _SkMenuDividerState extends State<SkMenuDivider> {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Container(height: 1, color: SkPalette.of(context)[SkRole.menuDivider]),
  );
}
