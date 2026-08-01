# 白い熊 獲得 — fork changelog

Everything built on top of stock [Obtainium](https://github.com/ImranR98/Obtainium). Upstream's own
notes live in the GitHub release history; this file tracks only the fork's changes.

## 1.6.10+019 — current

Base: upstream Obtainium **1.6.10** (`versionCode` 2349), fork `versionCode` `23490019`.

### Compare a tracked app against our own installed build (new)
- **Three per-app options, right under Track-only**: *Compare against installed app*, *Strip from
  the installed version (RegEx)* (default `\+\d+$`, our build counter), and *Only report genuinely
  higher versions*. They ride in the app's additional settings, so an existing entry gains them
  with no re-adding and they travel in the backup like every other per-app setting.
- **The entry's installed version is read from the linked package**, with our fork suffix stripped:
  a package reporting `1.6.10+015` makes the entry read `1.6.10`. Install a rebuilt fork and the
  entry clears **itself** on the next check — the "mark updated" tap this arrangement used to need
  every single time is gone.
- **An update means genuinely newer, not merely different.** The comparator walks version segments
  numerically (so `1.7` beats `1.6.10`, and unequal lengths compare correctly), ranks pre-releases
  below the release they lead to (`dev`/`snapshot`/`nightly` < `alpha` < `beta` < `rc`/`pre` <
  final, and `rc2` above `rc1`), and — crucially — **refuses to order what it cannot parse**,
  falling back to Obtainium's plain "they differ, so it is an update". An odd version string can
  never silently swallow a real update.
- **Linking implies track-only**, enforced on save: an entry compared against a local build must
  never offer to install the upstream APK over it.
- **A searchable installed-app picker** on both the add-an-app and edit-an-app screens: icon,
  label, package name and version per row, user-installed apps by default with a *Show system apps*
  toggle, an *Unlink* entry, and a ✨ **Suggested** mark on packages whose stripped version already
  matches what the source reports — usually the right fork, first row, first try. The field stays
  typeable with a typeahead over installed package names, which is what makes it usable on TV and
  with a hardware keyboard. It costs no extra package-manager enumeration: the picker reads the
  snapshot the app already takes at startup.
- **A linked entry wears the local build's face**: the fork's launcher icon in the list and on the
  detail page, and a name that states the relationship — **`Obtainium ⇒ 白い熊 獲得`**. Tapping the
  icon opens that local build rather than doing nothing. The stored app name is untouched, so
  exports, notifications and the automation contract keep the plain upstream name.
- On a device where the linked package is not installed, the entry simply behaves as a plain
  track-only app — the last known base version stays put, and the detail page says which package it
  is waiting for.

### GitHub — follow commits instead of releases (new)
- **A switch under *Include prereleases* and *Fallback to older releases***, with an optional
  **branch** field (blank = the repo's default branch). For an upstream we rebase onto and build
  ourselves, releases say nothing: the branch tip is the thing to watch.
- The head commit is reported as a pseudo-release versioned **`<commit date>.g<8-char sha>`** —
  deliberately the shape the `git-versioning` rule pins our forks to — with the commit date as the
  release date and the commit message as the changelog.
- **The comparison is by commit identity, not order.** Commits have no ordering, so being rebased
  onto upstream's head *is* being up to date, whatever version literal surrounds it:
  `6.3.0-alpha.2026-07-30.g5c0ed6a3+002` against `2026-07-30.g5c0ed6a3` reads as current, and moves
  to "update" the moment upstream's tip does. Both the sortable and the older `<upstream>.g<sha>+N`
  fork forms are recognised, since forks migrate one at a time. A `g` marker is required, so a
  date-style version like `20260801` — valid hexadecimal — is never mistaken for a commit.
- **Mutually exclusive with the two release options, without locking anything**: switching commit
  following on releases them, and switching either of them on releases commit following. Whichever
  you touch last wins. (Form switches gained an `excludes` list for this.)
- Commit following yields no APK, so it is **inherently track-only** — enforced through a new
  per-app source hook rather than a whole-source flag.

### Versions read as versions
- **A leading `v` is spelling, not a version difference.** It is stripped from every version shown —
  list tile, detail page, app-info dialog, changelog dialog, update checklist, notifications — and
  normalised before comparison, so `1.6.10` and `v1.6.10` can never read as an update. This also
  cures the permanent phantom update on any ordinary app whose source tags releases with a `v`
  while the OS reports the version without one.
- **Long versions are shown in full.** A version string contains no spaces, so
  `6.3.0-alpha.2026-07-30.g5c0ed6a3` had nowhere to wrap and was simply cut off; zero-width break
  opportunities after each separator let it fold over up to three lines in a wider column instead.
- The list tile shows the `installed → latest` arrow only when the app is genuinely outdated, and
  the big Install/Update button, the update badge, the Updates filter, the bulk actions and the
  background notifications all now ask the same single question.

### Add & edit screens
- **The bare `+` is gone.** Adding an app is now a full-width button below the URL that states what
  it will do — **“Accept options below and Add this GitHub app”** — in bold black on accent yellow,
  the loudest thing on the page, dimmed rather than disguised while the form is incomplete, and
  showing a spinner in place of its label while the source is fetched.
- The per-app options screen opens with an explicit **Save changes** button. Leaving the page always
  saved; nothing said so.
- **Form fields no longer have their borders clipped.** A tile-mode row was wrapped in a card that
  clipped its child to a 24 dp superellipse while the field drew its own outline at 8 dp, so the
  card's curve sliced the outline's corners off — visible as broken left and right edges on any
  single-row form. Fields now paint their own fill in the same shape as their outline, and card runs
  round off wherever a field interrupts them.

### Packaging
- **The build counter is zero-padded to three digits** in the version name and the APK filename
  (`1.6.10+019`, never `+19`), so builds sort in build order in `~/tmp/`, in the phone's file
  manager and in the release list. `versionCode` keeps the plain integer, and `BUILD_NUMBER` in
  `fork.properties` stays an unpadded integer. Tags published before this point keep their old
  spelling — nothing is ever retagged.

## 1.6.10+9

Base: upstream Obtainium **1.6.10** (`versionCode` 2349), fork `versionCode` `23490009`.

### 保存復元 — the export can now be stopped (new)
- **`shiroikuma.kakutoku.action.CANCEL_EXPORT`** — a third action on the same exported receiver, so
  a running headless export can be stopped from outside. Extras: `token` (the same gate as every
  other request) and an optional `reply_id` (absent = the export you are running, unambiguous
  because two at once are forbidden).
- **It comes in through the exported receiver on purpose.** The stop path lives in Dart, and a
  third-party caller can reach no non-exported component of this app — a stop button the requester
  cannot actually reach is the failure this action exists to avoid.
- **It bypasses the one-at-a-time request queue** on both the native and the Dart side: a cancel
  that waited its turn behind the very export it is meant to stop would never arrive.
- **The cancel answers nothing** — fire-and-forget, never `OK:`. The terminal **`ERROR:cancelled`**
  belongs to the *original* `EXPORT_STATE` request and goes out through the normal reply channel,
  under the existing `AtomicBoolean` guard, so a cancel and a success can never both fire.
- **Safe to send at any time.** Nothing running, an export that already finished, a token that does
  not match, an id naming another run — every one of them is a **silent no-op**: no error, no reply,
  no crash.
- **The backup folder is left exactly as it was found.** The flag is read between ZIP entries, so
  the export unwinds at an entry boundary — never mid-`write()`, never by interrupting a thread or
  killing the process. This app writes no `.part` file (the ZIP is built whole in memory and handed
  over in one call), so the same promise is kept by checking on **both** sides of the write and
  deleting the file again if the cancel landed while those bytes were going out — on the
  absolute-path and SAF paths alike. No short archive, no stray leftovers.
- A 5 s acknowledgement watchdog keeps the fire-and-forget cancel from holding its broadcast open
  while the export is inside a long synchronous stretch.

### 保存復元 — `LIST_CATEGORIES` states its own defaults
- Every reply line is now **`id⇥label⇥parent⇥on|off`**, with the empty parent field the positional
  format requires. The fourth field is this app **stating** whether an item starts ticked in the
  backup picker instead of the picker assuming it.
- **Every category is `on`** — nothing this app exports is large, derived *and* re-creatable — but
  the answer is stated rather than inferred, and a category added later inherits a field that is
  already there.
- The in-app Export/Import sheet seeds its checkboxes from **the same flag**, so it and the
  automation picker open on the same answer; an absent `items` extra now resolves through that
  default set rather than "everything".

### Shizuku — works with 白い熊 雫 without a compatibility stub
- **`af.shizuku.plus.permission.API_V23` is declared explicitly.** 白い熊 雫
  (`shiroikuma.shizuku`) defines that name and deliberately does *not* define
  `moe.shizuku.manager.permission.API_V23`, which stock Shizuku owns — declaring both would make the
  two managers uninstallable side by side.
- With stock Shizuku absent, the `moe.*` name is defined by **no package on the device**. An
  undefined permission can never be granted, so the server's `grantRuntimePermission` failed
  silently and `checkSelfPermission()` stayed denied however often the app was re-authorized in the
  manager. Declaring a name that actually **exists** is what lets the grant land, and drops the
  dependency on a compatibility stub being installed.
- The `moe.*` line (which arrives by manifest merge from the Shizuku provider AAR) is kept as the
  stock-Shizuku fallback: a `uses-permission` naming a permission no installed package defines is
  inert, so one build works against either server and costs nothing when only one is present.

## 1.6.10+8

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
