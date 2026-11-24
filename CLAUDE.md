# shiroikuma-kakutoku

A fork of [Obtainium](https://github.com/ImranR98/Obtainium) (GPL-3.0) — the "get Android app
updates straight from the source" installer — package `shiroikuma.kakutoku`, label **"白い熊 獲得"**,
installable side-by-side with upstream Obtainium.

## Branch & remote model (same as the sister forks)

- `origin` = `git@github.com:ShiroiKuma0/shiroikuma-kakutoku.git` (ssh) — our fork.
- `upstream` = `https://github.com/ImranR98/Obtainium.git` (https, fetch only).
- **`main`** tracks the latest upstream **release tag** (current base `v1.7.5`).
- **`custom`** carries all our work, rebased onto `main` on each new upstream release. **All
  development happens on `custom`.**
- **Do not rename the `dev.imranr.obtainium` code namespace / Dart package `obtainium`** — only the
  installed `applicationId` differs (`shiroikuma.kakutoku`, driven by `fork.properties` → `APP_ID`).
  Renaming would make every rebase a mass-conflict.

## Skills (`.claude/skills/`)

- **`build-apk`** — build the signed release APK via `./build-fork.sh`, then deliver it
  automatically via the global `/after-build` skill (adb push to `/sdcard/tmp/` if a phone is
  connected, else scp to skhw) — **no transfer prompt**; never pause to ask how to transfer.
- **`upstream-new-version`** — check upstream Obtainium for a newer release tag; **proceed-gated
  new-features briefing table BEFORE any rebase**; advance `main`, rebase `custom`, reset
  `BUILD_NUMBER`, build the new `+1`.
- **`publish-version`** — publish the latest tested APK as a GitHub release of the fork. Pin `gh`
  with `-R ShiroiKuma0/shiroikuma-kakutoku` (the `upstream` remote otherwise wins).

## Build, versioning, signing

- **This is a Flutter app** (Dart ^3.12, Flutter ≥3.44 declared — but 1.7.5 needs **3.50.1** in
  practice: its `hsluv ^1.3.0` wants Dart 3.14). The pinned SDK lives at
  **`/home/shiroikuma/flutter`** (3.50.1 stable, upstream's own `.flutter` commit; moved there
  with `git fetch --tags && git checkout <version>`) — the old `~/git/flutter` (3.13.5) cannot
  build it.
  Upstream also pins Flutter as the `.flutter` submodule; we build with `~/flutter` instead
  (leave the submodule uninitialized).
- **Build env:** `export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 ANDROID_HOME=/home/shiroikuma/android-sdk`.
- **Build:** `./build-fork.sh` (release-signed, `normal` flavor, arm64-only; copies the APK to
  `~/tmp/shiroikuma-kakutoku_<VERSION_NAME>+<NNN>_arm64-v8a.apk` and bumps `BUILD_NUMBER`).
  Upstream's own `build.sh` is their release pipeline — never use or overwrite it.
- **Versioning** (`fork.properties` at repo root, read by `android/app/build.gradle.kts`):
  `VERSION_NAME` / `VERSION_CODE` track upstream (pubspec `version: <name>+<code>`, e.g.
  `1.6.9+2348`); `BUILD_NUMBER` is our increment (bumped every build, reset to 1 on each new
  upstream version). Fork `versionName = "<VERSION_NAME>+<NNN>"` — the counter is **zero-padded
  to three digits** in the name and the APK filename (`1.6.10+015`, never `+15`), so both sort in
  build order; see the global **`after-build`** rule. `BUILD_NUMBER` itself stays a plain integer
  in `fork.properties`, and `versionCode = VERSION_CODE * 10000 + BUILD_NUMBER` uses it unpadded
  (Obtainium 2348 → `23480001`, …).
  `pubspec.yaml`'s `version:` stays upstream's — never edit it for fork builds.
- **Signing:** release signed from gitignored `android/key.properties` →
  `~/.android-keystores/shiroikuma-kakutoku.jks` (alias `kakutoku`). Password recorded in 白い熊's
  `android-keystores.org`; a `.jks` backup lives in the same crypto directory. If
  `android/key.properties` is absent, restore it from `android/key.properties_sample`.
- **Delivery:** APK to `~/tmp`, then `/after-build` (adb push to `/sdcard/tmp/` or scp to skhw);
  **the user installs from the on-device file manager** (never `adb install`).

## Working rules (override harness defaults where noted)

- **No `Co-Authored-By: Claude` / "Generated with Claude" trailer** in commits or PR bodies — end
  the message at the last line of the body. (Overrides the harness default; global rule in
  `~/.claude/CLAUDE.md`.)
- **Never commit or push until the user says "Push".** Treat the working tree as scratch between
  "Push" commands. "Push" = `git commit` + `git push origin custom` (and `main` after an upstream
  sync). The user tests each build on-device first.
- **After every successful build, deliver the APK automatically via `/after-build`** — never ask
  how to transfer it, never pause.
- **Commit subjects:** plain descriptive summary, no prefix.

## Fork rules that every upstream sync must keep

- **Screens import the barrel, never `material_ui` directly.** Every file under `lib/` imports
  `package:obtainium/sk_material.dart`, which re-exports `material_ui` and replaces `AlertDialog`,
  `Switch` and `SwitchListTile` with the black-yellow drop-ins (`lib/components/sk_dropins.dart`).
  A new upstream screen arrives importing `material_ui` and must be switched. The check after a
  sync — it may list only `sk_theme.dart`, `sk_pills.dart`, `sk_dropins.dart`, `sk_roles.dart` and
  `sk_ui_provider.dart`:
  `grep -rL sk_material lib | xargs grep -l "material_ui/material_ui.dart"`
- **Colours come from roles.** `lib/providers/sk_roles.dart` holds the role table (`SkRole`,
  `SkPalette`); `lib/sk_theme.dart` builds the whole `ThemeData` from it, so upstream screens keep
  reading `Theme.of(context)` (the mixed way of the global **black-yellow-theme** skill), and fork
  screens read `SkPalette`. No colour literal outside the role table.
- **Translations are rebuilt, never merged by hand:** `python3 tool/sk_translations.py <new tag>`
  (in a rebase, take upstream's side of any conflicted locale file, then run it). Each locale is
  upstream's file of the new tag with `Obtainium` → `白い熊 獲得` in the values, plus the fork's
  own keys from `tool/sk_strings/en.json` — in English in every locale, because upstream's
  `test/translation_shape_test.dart` fails when a locale lacks a key that `en.json` has.
  **`ja.json` alone is fully Japanese**: it takes `tool/sk_strings/ja.json`, which holds the
  Japanese of every fork string and of the upstream strings upstream's own `ja.json` leaves in
  English (the tool stops when a fork string has no Japanese; names and placeholders such as
  `coolApk` or `hostHint` stay as they are). After a sync, list what upstream left in English
  and add it to that file.
- **No user-visible literal in the fork's Dart.** A string of the fork's own screens is a line of
  `tool/sk_strings/en.json` + `ja.json` (`skStr_…`, `skRole_…`, `skBase_…`, `skSection_…`,
  `skCat_…`); the tool writes `lib/sk_strings.dart` from it (`SkStr.name.t`, `skTr(key)`), with
  the English as the fallback where no translation is loaded (tests, the headless automation
  engine). The automation contract's own texts — `ERROR:…` replies, `SkExportCat.label`, thrown
  import errors — stay English.
- **Upstream's switch rows get their icon from `lib/components/sk_row_icons.dart`**, a table
  keyed by translation key (upstream's `ToggleTile` takes only a label). A new upstream switch
  row gets its line there on the sync that brings it.
- **App language:** `SkSection.language` is the first section of the UI page. The short list of
  languages is written once, in `lib/components/sk_language.dart` (Japanese, English, then the
  languages translated four fifths or more, by name); the picker, upstream's dropdown on the
  Settings screen and `android/app/src/main/res/xml/locales_config.xml` all follow it, and
  `test/sk_ui_test.dart` measures every listed language on each run. After a sync, a language
  that crossed the bar either way is added or removed in both the list and the XML. Both pickers
  set upstream's one stored value, `SettingsProvider.forcedLocale`.
- **Section icons:** each `SkSection` names its `SkSectionKind` — one of seven colours with one
  meaning each (roles `SkRole.section…`) — and the enum order is the default order, in which no
  two neighbours share a colour. A new section keeps both rules; `test/sk_ui_test.dart` checks.
- **A sync whose commit-by-commit rebase conflicts throughout is resolved once**, as a merge on a
  work branch, and lands on `custom` as **one fork-layer commit on top of the new tag** (done for
  `v1.7.4`, 2026-11-23). The history before it is kept under the tag `custom-1.6.17`.
- **Checks before a build:** `~/flutter/bin/flutter analyze` and `~/flutter/bin/flutter test`
  (upstream's tests plus `test/sk_ui_test.dart`).

## Repo layout (upstream Obtainium)

- `lib/` — Dart sources: `app_sources/` (per-site source drivers: GitHub, GitLab, F-Droid, APKPure,
  …), `providers/` (apps/settings/notifications/logs + import-export), `pages/`, `components/`,
  `main.dart` (self-tracking entry: on first run it adds Obtainium itself from `obtainiumUrl` —
  fork-sensitive), `main_fdroid.dart` (fdroid flavor entry).
- `android/` — Gradle wrapper around the Flutter build; `app/build.gradle.kts` carries our fork
  block (applicationId/versioning from `../fork.properties`, `key.properties` signing — both
  upstream mechanisms, minimally patched).
- `assets/graphics/` — logo master `icon.svg` + PNG exports (fork-sensitive: branding).
- Flavors: `normal` and `fdroid` (`applicationIdSuffix .fdroid`, entry `main_fdroid.dart`) — we
  ship `normal` only.
- Translations: `assets/translations/*.json` (easy_localization), 30+ locales — the app name
  appears in them (branding-sensitive).

## Current status

**Phase 0 complete** (fork identity + icon + rebranding, 2026-07-16): repackaged
`shiroikuma.kakutoku` / `白い熊 獲得`, fork versioning + signing + `build-fork.sh`, skills,
keystore. Black-yellow traced launcher icon (adaptive vector + legacy mipmaps + TV banner +
in-app `icon_small.png` + bundled masters). Full de-branding: self-tracking constants point at
this fork (first run adds the app itself as 白い熊 獲得, updating from our GitHub releases),
welcome/Help links → our repo, app title/share subjects/swatch label/export messages renamed,
all 29 translation locales rebranded (values only — keys + formatting untouched). Kept as
functional: internal class names, the `obtainium://` scheme, `apps.obtainium.imranr.dev`
services, the APKMirror user-agent. First build `1.6.9+1` (versionCode `23480001`) delivered.

**Black-yellow theme applied fully** (2026-11-23, build `1.6.17+002`): colour roles for every
item, pills, the outlined switch, role-coloured icons and the folding “白い熊 獲得 UI” page, behind
the “Use 白い熊 獲得 UI” switch.

**Base `v1.7.4`** (2026-11-23, build `1.7.4+001`, versionCode `23620001`): `custom` is one
fork-layer commit on the tag. Upstream moved the per-app options to
`lib/pages/app_additional_options.dart`; the linked-app picker, the prefilled title, “Save
changes” and the set-as-updated carry-over were ported there. APKCombo is gone, as upstream
removed it.

**Base `v1.7.5`** (2026-11-24, build `1.7.5+001`, versionCode `23630001`): a plain two-commit
rebase. Section icons in the seven colours on headings and chips, the four moved menu icon
defaults, icons on upstream's switch rows, and the whole fork layer translated — `ja.json` has
no English left but names and placeholders.
Build `1.7.5+002` (versionCode `23630002`) adds the “App language” section in first place,
with the picker in the settled look and the short list of thirteen languages.
