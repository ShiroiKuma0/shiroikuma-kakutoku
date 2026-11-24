// shiroikuma-kakutoku fork: the app's language — the short list the fork
// offers, and its picker.
//
// The list is written once, here. The picker of the 白い熊 獲得 UI page,
// upstream's own dropdown on the Settings screen and the Android declaration
// (android/app/src/main/res/xml/locales_config.xml) all follow it: Japanese
// and English first, then only the languages the app is fully or mostly
// translated into — four fifths or more of upstream's strings, measured
// against en.json on each sync — sorted by name. Every translation stays in
// the package; a language chosen earlier that is no longer listed stays in
// force and is shown as the current row.
//
// Both pickers set the one stored value, SettingsProvider.forcedLocale, which
// upstream re-asserts at every start (lib/main.dart) and uses for the strings
// that leave the app (lib/utils/translation_loader.dart).

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:obtainium/main.dart' show supportedLocales;
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';
import 'package:obtainium/sk_material.dart';
import 'package:obtainium/sk_strings.dart';
import 'package:obtainium/sk_theme.dart';
import 'package:provider/provider.dart';

/// One language of the list: its name and its country in its own language,
/// and the tag shown at the row's end.
class SkLanguage {
  const SkLanguage(this.locale, this.name, this.region, this.tag);
  final Locale locale;
  final String name;
  final String region;
  final String tag;
}

/// The short list, in the order shown.
const List<SkLanguage> skLanguages = [
  SkLanguage(Locale('ja'), '日本語', '日本', 'ja-JP'),
  SkLanguage(Locale('en'), 'English', 'United Kingdom', 'en-GB'),
  SkLanguage(Locale('bs'), 'Bosanski', 'Bosna i Hercegovina', 'bs-BA'),
  SkLanguage(Locale('de'), 'Deutsch', 'Deutschland', 'de-DE'),
  SkLanguage(Locale('es'), 'Español', 'España', 'es-ES'),
  SkLanguage(Locale('fr'), 'Français', 'France', 'fr-FR'),
  SkLanguage(Locale('it'), 'Italiano', 'Italia', 'it-IT'),
  SkLanguage(Locale('hu'), 'Magyar', 'Magyarország', 'hu-HU'),
  SkLanguage(Locale('nl'), 'Nederlands', 'Nederland', 'nl-NL'),
  SkLanguage(Locale('pt'), 'Português', 'Portugal', 'pt-PT'),
  SkLanguage(Locale('el'), 'Ελληνικά', 'Ελλάδα', 'el-GR'),
  SkLanguage(Locale('ru'), 'Русский', 'Россия', 'ru-RU'),
  SkLanguage(Locale('zh'), '简体中文', '中国', 'zh-CN'),
];

/// The languages a picker offers: the short list, and — after it — the
/// language in force when it is not one of them.
List<SkLanguage> skOfferedLanguages(Locale? current) {
  if (current == null || skLanguages.any((l) => l.locale == current)) {
    return skLanguages;
  }
  final name = supportedLocales
      .where((e) => e.key == current)
      .map((e) => e.value)
      .firstOrNull;
  return [
    ...skLanguages,
    SkLanguage(
      current,
      name ?? current.toLanguageTag(),
      '',
      current.toLanguageTag(),
    ),
  ];
}

/// What the “Language: …” row shows.
String skLanguageName(Locale? current) => current == null
    ? SkStr.languageSystem.t
    : skOfferedLanguages(current).firstWhere((l) => l.locale == current).name;

/// Sets the app's language, at once and for this app only; null follows the
/// system.
void skSetLanguage(BuildContext context, Locale? locale) {
  final settings = context.read<SettingsProvider>();
  settings.forcedLocale = locale;
  if (locale != null) {
    context.setLocale(locale);
  } else {
    settings.resetLocaleSafe(context);
  }
}

/// The language list: plain rows, and only the current language in a pill.
Future<void> showSkLanguagePicker(BuildContext context) {
  final current = context.read<SettingsProvider>().forcedLocale;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(SkSection.language.title),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 340,
        child: SkLanguageList(
          current: current,
          onPick: (locale) {
            Navigator.of(ctx).pop();
            skSetLanguage(context, locale);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr('cancel')),
        ),
      ],
    ),
  );
}

class SkLanguageList extends StatelessWidget {
  const SkLanguageList({
    super.key,
    required this.current,
    required this.onPick,
  });
  final Locale? current;
  final ValueChanged<Locale?> onPick;

  @override
  Widget build(BuildContext context) {
    final p = SkPalette.of(context);
    final rows = <SkLanguage?>[null, ...skOfferedLanguages(current)];
    final chosen = rows.indexWhere((l) => l?.locale == current);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            // A hairline between rows, inset to the text; none directly
            // above or below the current row's pill.
            if (i > 0 && i != chosen && i - 1 != chosen)
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: 44, right: 12),
                color: p[SkRole.menuDivider],
              ),
            _SkLanguageRow(
              language: rows[i],
              chosen: i == chosen,
              onTap: () => onPick(rows[i]?.locale),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkLanguageRow extends StatelessWidget {
  const _SkLanguageRow({
    required this.language,
    required this.chosen,
    required this.onTap,
  });

  /// Null: “System default”, which has no country line and no tag.
  final SkLanguage? language;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = SkPalette.of(context);
    final ink = p[SkRole.dialogBody];
    final gold = p[SkRole.pageNote];
    final mark = chosen ? p[SkRole.radioOn] : p[SkRole.switchOffOutline];
    final name = theme.textTheme.bodyLarge?.copyWith(
      color: ink,
      fontWeight: chosen ? FontWeight.bold : FontWeight.normal,
    );
    final small = theme.textTheme.bodySmall?.copyWith(color: gold);
    final region = language?.region ?? '';
    return Material(
      type: MaterialType.transparency,
      shape: chosen
          ? StadiumBorder(
              side: BorderSide(
                color: p[SkRole.dialogButtonFrame],
                width: skPillMainWidth,
              ),
            )
          : null,
      clipBehavior: chosen ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: onTap,
        splashColor: ink.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          // The name stays at the row's start side and the tag in its own
          // column at the right, whatever the direction of the language.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                // The selection mark: a ring, with a dot on the current row.
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: mark, width: 2),
                  ),
                  child: chosen
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: mark,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language?.name ?? SkStr.languageSystem.t,
                        style: name,
                      ),
                      if (region.isNotEmpty) Text(region, style: small),
                    ],
                  ),
                ),
                if (language != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    language!.tag,
                    style: small?.copyWith(fontFamily: skMonospaceFamily),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
