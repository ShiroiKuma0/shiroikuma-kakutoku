# 白い熊 獲得 — fork changelog

Everything built on top of stock [Obtainium](https://github.com/ImranR98/Obtainium). Upstream's own
notes live in the GitHub release history; this file tracks only the fork's changes.

## 1.6.9+6 — current

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
