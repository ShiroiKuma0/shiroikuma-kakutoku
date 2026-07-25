# 白い熊 獲得 — fork changelog

Everything built on top of stock [Obtainium](https://github.com/ImranR98/Obtainium). Upstream's own
notes live in the GitHub release history; this file tracks only the fork's changes.

## 1.6.10+8 — current

Base: upstream Obtainium **1.6.10** (`versionCode` 2349) — `custom` rebased onto the new upstream
release tag, fork versioning moved to `1.6.10+…` (`versionCode` `23490008` here).

### Export / Import — a real backup section (new)
- New **Export / Import** section at the top of the 白い熊 獲得 UI page, in the sister-fork house
  style: an export-folder row that names the chosen folder and, below it, the timestamp of the
  **latest export found in it** (a loud red warning until a folder is set), and an
  **Export / Import…** entry opening the panel.
- The panel backs up **everything by category** — **Sources (tracked apps) first**, then app
  settings, source credentials, categories, and the 白い熊 獲得 UI (knobs, recent colours, and the
  imported font files themselves) — with a **Select all** master checkbox, ArcaneChat-style round
  pill buttons (Cancel separated left, Import + Export right), and black-yellow bordered result
  dialogs that close the whole chain on success while leaving the panel open on failure.
- **Import merges, never wipes**: absent categories are skipped, existing keys are updated in
  place, tracked apps keep their installed-version state, and the result dialog offers an in-place
  **Restart now** (a small `restartApp` platform channel) or Later.
- The folder query is hardened against the OEM document provider: every stage has its own timeout,
  concurrent queries are serialised onto one chain (two `listFiles` listeners share a single
  platform event channel and the second orphans the first), only the `id` column is requested, and
  each stage reports itself on screen so a stall is visible instead of an eternal "…".

### 保存復元 — headless, token-gated state export (new)
- **One ZIP per backup, family-named.** Every backup this app writes — from the panel and from the
  automation path alike — is `shiroikuma-kakutoku_<yyyy-MM-dd_HH-mm-ss>.zip`, holding a
  `manifest.json` (format/version/app/appVersion/createdTs/categories) plus one `<category id>.json`
  per exported category. No version, no infix, no suffix, and never a second file: all sister apps'
  backups share one directory and must sort and read uniformly. v1 single-JSON exports still import,
  and the "last exported" query still recognises their names.
- **`shiroikuma.kakutoku.action.EXPORT_STATE` / `.LIST_CATEGORIES`** — an exported receiver with no
  `android:permission` (the caller cannot hold one; the token is the gate). It holds the broadcast
  open with `goAsync()`, boots the app's Dart code in a **headless `FlutterEngine`** (no Activity)
  and drives the app's *own* export core, so the automated backup is a normal, restorable one and
  the export logic exists exactly once.
- **The reply is a fresh broadcast** carrying `FLAG_INCLUDE_STOPPED_PACKAGES` — never a
  `ResultReceiver`, `PendingIntent` or `Messenger`, and never only the ordered-broadcast result
  (EMUI drops live Binders into third-party manifest receivers and severs the ordered channel; the
  ordered result is still set, as correct AOSP behaviour, but is never the reply). Exactly one
  terminal reply per request, `AtomicBoolean`-guarded, with a watchdog so a wedged engine still
  answers.
- **Real numbers, never a percentage.** Progress broadcasts carry a display line plus structured
  `current`/`total`/`unit` extras — `区分 3/5 — Sources (tracked apps)`, `アプリ 128/240`,
  `フォント 2/5` — throttled to at most one every 500 ms with a forced final one at completion.
- **Requests are honoured in full**: `items` selects a subset of categories by id (absent = all,
  unknown ids rejected without writing anything), `path` overrides the configured export folder,
  and `reply_id` is echoed back verbatim. The success reply is
  `OK:<absolute path>|<bytes>|<human size>|<n> categories`; failures are distinct one-line reasons
  (`automation disabled`, `bad token`, `no-directory`, `no-storage-access`, …).
- **Automation switch + token**, appended directly below the existing export rows — not a section of
  their own. The switch defaults **off**; the token is 24 bytes from the platform's cryptographic
  RNG, hex-encoded, generated lazily so the row always shows a value, **compared in constant time**,
  copied to the clipboard on tap, and re-issuable with a warning that pasted copies must be updated.
  The whole `skAutomation*` prefs namespace is excluded from the settings dump, so the token can
  never travel inside a backup.
- `MANAGE_EXTERNAL_STORAGE` is declared so an absolute `path` can actually be written; turning the
  switch on asks for All-files access. Without the grant the export falls back to the configured
  SAF folder and the switch row says so in red.

## 1.6.9+6

Base: upstream Obtainium **1.6.9** (`versionCode` 2348). First public release of the fork.

### Fork identity & packaging
- Repackaged as **`shiroikuma.kakutoku`**, label **白い熊 獲得**, installable side-by-side with
  Obtainium. Code namespace `dev.imranr.obtainium` and the Dart package `obtainium` are left
  unchanged (only the installed application id differs), to keep upstream rebases clean.
- Fork versioning from `fork.properties`: `VERSION_NAME`/`VERSION_CODE` track upstream;
  `BUILD_NUMBER` is the fork increment. `versionName = "<VERSION_NAME>+<BUILD_NUMBER>"`,
  `versionCode = VERSION_CODE * 10000 + BUILD_NUMBER` (→ `23480006` here).
- `build-fork.sh` builds the signed release APK (normal flavour, arm64), names it
  `shiroikuma-kakutoku_<version>_arm64-v8a.apk`, and bumps the build number. Signed with the fork's
  own keystore.
- Self-tracking retargeted: on first run the app adds **itself** (`shiroikuma.kakutoku`, author
  白い熊) tracking this fork's GitHub releases; the app title, share subjects, in-app links
  (welcome/Help), and export-schema messages all say 白い熊 獲得; all 29 translation locales
  rebranded (values only — keys and formatting untouched).

### Icon & branding
- Black-yellow **traced Obtainium ribbon-arrow glyph** — yellow `#FFFF00` line-art on a black
  adaptive-icon background — as the launcher icon (adaptive vector + monochrome, legacy mipmaps at
  all densities, TV banner, in-app placeholder glyph, and the bundled master PNG/SVG).
- Launcher glyph enlarged ~50% so it fills the icon.

### 白い熊 獲得 UI — granular theming (new)
- New **白い熊 獲得 UI** page reached from the top of Settings and by **long-pressing the main-screen
  Settings cog**. Sister-repo house style: big bold underlined section headings, subgroups
  underlined to text width, 40 dp indent per hierarchy level, tight single-line rows.
- **Live preview everywhere** — the knob-driven theme restyles the whole app (and the page itself)
  as you drag; changes persist immediately; one-tap reset to defaults in the page's top bar.
- **12 colour slots** (background, surface, accent, on-accent, text, secondary text, border, icon,
  top-bar background/foreground, action-button background/foreground) grouped under Foundation /
  Text / Borders & icons / Top bar / Action button.
- **RGBA colour picker**: four R/G/B/A sliders (0–255), old→new preview with a checkerboard behind
  translucent colours and a hex readout, and one-click **recent-colour boxes** (10, shared across
  every picker, persisted, prefilled with the house palette). Live while dragging; Cancel restores,
  OK persists and remembers the colour.
- **Size/shape sliders** with inline live previews: font size, font weight (100–900), corner
  roundness (0–32 dp), border thickness (0–6 dp, 0 = none), icon size, and row density (0 =
  tightest).
- **External fonts**: import `.ttf`/`.otf` (copied into `files/fonts`), listed with **each entry
  rendered in its own typeface** and a sample string, plus App-default / System / Monospace and
  per-font delete; the choice is applied app-wide and persisted.
- **Black-yellow defaults**: pure `#FFFF00` on `#000000` (never material `#FFEB3B`), yellow
  borders/icons, covering app bars, cards, dialogs, inputs, switches, sliders, the FAB, search bar,
  and menus.

### Main-screen refinements
- **Action buttons** (Add FAB, Update, per-app download): black fill, yellow text/icon, yellow
  border — the new house default for the action-button colour knobs, with a one-time migration that
  flips an already-saved yellow-fill state.
- **Cog gesture**: tap opens Settings, long-press opens the 白い熊 獲得 UI page.
- **Whitespace removed**: compact app bar (replacing the tall `SliverAppBar.large`), removed the
  720 dp max-width body cap that left dead side margins, and trimmed card/search/banner side insets
  to a 2 px gutter so app cards run nearly edge-to-edge.
