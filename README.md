<div align="center">

<img src="assets/graphics/icon.png" width="120" alt="白い熊 獲得 icon" />

# 白い熊 獲得

**Get app updates straight from the source — in black and yellow.**

A fork of [Obtainium](https://github.com/ImranR98/Obtainium) with **major additions**: tracking an
upstream project while comparing it against **your own build of it** (releases *or* git commits),
**waving through a push not worth rebuilding for**, **updating several apps at once**, a granular black-yellow 白い熊 獲得 UI theming page (colours,
fonts, borders, sizes — all live-previewed), **category Export/Import** of the whole setup,
**headless backup on demand** over a token-gated intent, and a tightened edge-to-edge main screen.

Installs **side-by-side** with Obtainium (app id `shiroikuma.kakutoku`).

**📥 Latest release: [`1.6.14+001`](https://github.com/ShiroiKuma0/shiroikuma-kakutoku/releases/latest)** — [all releases & APK downloads »](https://github.com/ShiroiKuma0/shiroikuma-kakutoku/releases)

</div>

---

## 🔗 Track upstream, compare against your own build
For every project you follow only because you patch and build the fork yourself, an entry can be
**linked to the build installed on this phone**. Its "installed" version is then read from that
package with the fork's `+N` build counter stripped, so upstream `1.6.10` and your
`1.6.10+015` are recognised as the same release — and an update is reported only when upstream is
**genuinely higher**, never merely different. A suffix that only names the **build variant** counts
the same way: an upstream that cuts every release as `1.0.52-oss` is the same release as your
`1.0.52`, not an update that can never be cleared. Anything carrying a digit — `-hotfix2`, a date, a
commit sha — stays a real difference. Rebuild your fork, install it, and the entry clears
itself; the endless "mark updated" tapping is gone. Pick the local build from a searchable dialog of
installed apps (icon, label, package, version, and a ✨ mark on the one that already matches). The
entry then wears **that build's icon and label** — even when the tracked upstream is installed on
the same phone — reads **`白い熊 獲得 ⇒ Obtainium`**, ours first, and names your build in full,
`+NNN` counter included, so you can see at a glance which one is on the device. When upstream moves
ahead, the entry raises the **same download arrow as any other app with an update**; pressing it
says which fork to rebase and onto which upstream version, since that APK is yours to build.

## ✏️ Name each entry yourself
Every entry's **Title** is editable and leads its Edit page, opening filled with the title it
currently shows — so renaming is an edit, not a retype. A hand-set title replaces the whole line,
which is what lets two entries tracking **sibling repos of one project** (a desktop repo and its
Android port, say) be told apart. Leave it as found and it stays automatic, following the source
and your build's label.

## 🌱 Follow git commits, not just releases
For a GitHub project whose releases stand still for months while its branch moves daily, follow
**commits** instead: the head is reported as `<upstream version>.<commit date>.g<8-char sha>` —
exactly the shape our git-versioned forks carry, right down to the version it sits on — and "up to
date" means *your build is rebased onto that commit*. No version arithmetic, no false updates when
a tag is re-cut; the sha decides. A fork rebased onto **several** upstreams pins one sha per
upstream, and **every** sha in the version is read, so each upstream gets its own entry and each
matches its own pin. Pick a branch to follow, and the release-only options grey themselves out
while commits are followed rather than quietly undoing the setting. Where the project's version
lives in a **file** rather than in a tag — Jami keeps `versionName = "20260731-01"` in its
`build.gradle.kts` and tags only `android/release_502` — name that file and, if the default
`versionName = "…"` does not fit, a regex; it is read **at the followed commit's own sha**, so the
version and the sha always describe the same commit.

## ✅ Wave a push through without rebuilding
Not every commit upstream is worth a rebase and a rebuild — but until now the download arrow sat
there all the same, and nothing short of building could clear it. **Set as updated** sits left of
**Rebase & build** and does exactly that: it records the upstream version you waved through, and the
entry reads as current until upstream **moves past it** — for a followed branch, until the next
push, matched by the commit's identity rather than by the version literal around it. The mark is
kept with the entry rather than faked into its installed version (which is read from your local
build and would overwrite it within seconds), so it survives every refresh, every edit of the
entry's options, and a restart. The detail page states plainly when an entry is current only by that
mark and at which version, and **Reset install status** takes it back.

## 🔄 Refresh one source, not all of them
Every app page carries a **Refresh from upstream** pill next to its primary button, so a single
source can be re-checked without a full sweep of everything you track — and the page answers a
**pull-down** too, with the same running yellow line the main window shows while it refreshes. Our
own builds sort to the **top of every block** in the list — updates available, installed, and not
installed alike — each still alphabetical within.

## ⚡ Update several apps at once
Stock disables **every** app's download button the moment one download starts. Here each button
watches only its own app, so you can tap as many as you like and they all run. Downloads go three
at a time; installs go through a single lock, because the platform installer shows one prompt at a
time — so install prompts never overlap and a download never waits on one. Each app installs the
instant its own download lands, apps waiting their turn read **`Queued`**, and the same app can
never be started twice by a double tap, a swipe, or a bulk run overlapping a single one. A
self-update still goes last and alone.

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
folder is checked on opening for the latest export (loud red warning until one is set); **exactly
one ZIP per backup** (`shiroikuma-kakutoku_<yyyy-MM-dd_HH-mm-ss>.zip`, a `manifest.json` plus one
`<category>.json` inside); import **merges, never wipes**, and offers an in-place app restart.
Round pill buttons — Cancel left, Import/Export right — and black-yellow result dialogs that close
the whole chain on success.

## 🤖 Headless backup on demand
The app can back **itself** up with no Activity and no tapping: a companion automation app fires a
token-gated broadcast, and 白い熊 獲得 writes the very same ZIP and answers with its absolute path,
byte count, and human size. A master switch (**off** until you turn it on) and a copy-on-tap token
sit right under the export rows; the token is generated on first sight, compared in constant time,
and deliberately kept **out of the backup**. While it works the app reports **real counts, never a
percentage** — `区分 3/5 — Sources`, `アプリ 128/240` — so a long export is legible from the
outside. The requester may name the target directory, and the file it gets back is a perfectly
ordinary backup you can restore from the Import button. A running export can also be **stopped from
outside**, and a stopped one leaves the backup folder *exactly* as it found it — no short archive,
no leftovers, and a terminal answer that proves the run ended rather than carrying on unseen.

## 🔌 Silent installs through 白い熊 雫
Obtainium's Shizuku installer, taught to work with **白い熊 雫** (`shiroikuma.shizuku`) directly.
That manager defines its own permission name because stock Shizuku owns the classic one and two
apps cannot define the same permission and still install side by side — so this fork declares
`af.shizuku.plus.permission.API_V23` explicitly, and the authorization you grant in the manager
actually lands instead of failing silently. The classic name is kept alongside it as the
stock-Shizuku fallback, so one build works against either server with no compatibility stub in
between.

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
yellow text and a yellow border**. On such a button the fill is the page's own black, so the label
and the border are the whole button — and **an action with nothing to do fades both**, rather than
sitting there in full yellow looking like work waiting to be done. The knob-driven theme covers the
whole app: app bars, cards, dialogs, inputs, switches, sliders, the FAB, search bar, and menus.

## 📱 Tightened main screen
A compact app bar (no tall expanding header), full-width content with no dead side margins, and app
cards that run nearly edge-to-edge. The **Install/update apps** banner is off by default — the
per-app buttons and the selection menu already do the job — and can be switched back on in Settings.

## 🩸 A removal dialog that reads like one
The confirm button says **Remove**, not "Continue", and sits at the far left with Cancel at the far
right, so the destructive action is nowhere near the reflex tap. Dark blood red `#8B0000` in fill
and border with a white label — **both colours settable in Settings** — while Cancel carries the
accent border filled buttons wear in this theme.

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
`BUILD_NUMBER` is the fork increment. Fork `versionName = "<VERSION_NAME>+<NNN>"` — the counter is
zero-padded to three digits so builds and tags sort in build order — and
`versionCode = VERSION_CODE * 10000 + BUILD_NUMBER` uses it unpadded.
