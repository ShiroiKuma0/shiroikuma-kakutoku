<div align="center">

<img src="assets/graphics/icon.png" width="120" alt="白い熊 獲得 icon" />

# 白い熊 獲得

**Get app updates straight from the source — in black and yellow.**

A fork of [Obtainium](https://github.com/ImranR98/Obtainium) with **major additions**: a granular
black-yellow 白い熊 獲得 UI theming page (colours, fonts, borders, sizes — all live-previewed),
**category Export/Import** of the whole setup, a tightened edge-to-edge main screen, and
house-styled action buttons.

Installs **side-by-side** with Obtainium (app id `shiroikuma.kakutoku`).

**📥 Latest release: [`1.6.10+7`](https://github.com/ShiroiKuma0/shiroikuma-kakutoku/releases/latest)** — [all releases & APK downloads »](https://github.com/ShiroiKuma0/shiroikuma-kakutoku/releases)

</div>

---

## 🎨 白い熊 獲得 UI — granular theming page
A dedicated theming screen in the sister-repo house style, reached from the top of Settings **or by
long-pressing the Settings cog** on the main screen. Bold headings underlined exactly as wide as
their text, hairline section spacers, deeply indented rows, and tight spacing so the hierarchy reads
instantly. **Everything previews live** — the whole app (and the page itself) restyles as you drag.
One-tap reset to the black-yellow defaults.

## 📦 Category Export / Import
The first section of the UI page backs up **everything** by category — **Sources (tracked apps)
first**, then app settings, source credentials, categories, and the 白い熊 獲得 UI itself (knobs,
recent colours, and your imported font files ride along inside the export). A settable export
folder is checked on opening for the latest export (loud red warning until one is set); one JSON
file per export; import **merges, never wipes**, and offers an in-place app restart. Round pill
buttons — Cancel left, Import/Export right — and black-yellow result dialogs that close the whole
chain on success.

## 🌈 RGBA colour pickers with preset boxes
Twelve colour slots (background, surface, text, secondary text, accent, borders, icons, top bar,
action buttons). Each picker has **four R/G/B/A sliders (0–255)**, an old→new preview with a
checkerboard behind translucent colours, and a row of **one-click recent-colour boxes** — shared
across every picker, persisted, and prefilled with the house palette.

## 🔤 External fonts, rendered in their own glyphs
Import any `.ttf`/`.otf` and the app loads it as a selectable family. The font list draws **each
entry in its own typeface** (with a Latin + 白い熊 kanji + diacritics sample), alongside the app
default, the system font, and monospace. Pick, apply, delete — all persisted.

## 📏 Size & shape sliders — everything to zero
Font size, font weight, **corner roundness (0–32 dp)**, **border thickness (0–6 dp, 0 = none)**, icon
size, and row density are all sliders with an inline live preview. Borders and roundness go all the
way to flat.

## ⬛🟨 Black-yellow by default
Pure yellow `#FFFF00` on black `#000000` (never the muddy material yellow) out of the box — text,
borders, and icons in yellow, and **action buttons (Add, Update, per-app download) as black fill with
yellow text and a yellow border**. The knob-driven theme covers the whole app: app bars, cards,
dialogs, inputs, switches, sliders, the FAB, search bar, and menus.

## 📱 Tightened main screen
A compact app bar (no tall expanding header), full-width content with no dead side margins, and app
cards that run nearly edge-to-edge.

---

## Built on Obtainium
A fork of [Obtainium](https://github.com/ImranR98/Obtainium) (app id `shiroikuma.kakutoku`, so it
coexists with the official build). Obtainium lets you install and update Android apps directly from
their releases — GitHub, GitLab, F-Droid, and many more sources — with no central store in between.
All upstream functionality is intact; this fork only layers the 白い熊 identity and theming on top.
The code remains under **GPL-3.0**.

## Building
```bash
git clone git@github.com:ShiroiKuma0/shiroikuma-kakutoku.git
cd shiroikuma-kakutoku
./build-fork.sh    # signed release APK -> ~/tmp/shiroikuma-kakutoku_<version>_arm64-v8a.apk
```
Versioning: `VERSION_NAME`/`VERSION_CODE` in `fork.properties` track upstream Obtainium;
`BUILD_NUMBER` is the fork increment. Fork `versionName = "<VERSION_NAME>+<BUILD_NUMBER>"`,
`versionCode = VERSION_CODE * 10000 + BUILD_NUMBER`.
