# 白い熊 獲得 — fork changelog

Everything built on top of stock [Obtainium](https://github.com/ImranR98/Obtainium). Upstream's own
notes live in the GitHub release history; this file tracks only the fork's changes.

## 1.6.11+001 — current

Base: upstream Obtainium **1.6.11** (`versionCode` 2350), fork `versionCode` `23500001`.

First build on the new upstream line. Obtainium 1.6.11 is a large release — a codebase-wide
refactor, a settings-page rewrite, and an install pipeline of its own — and in three places it
arrived at the same problems the fork had already solved by hand. Those places were reconciled
rather than re-patched, so the fork layer is now smaller than it was on 1.6.10.

### Update detection runs through upstream's own choke point
- **Upstream centralised the question the fork had been answering in eight places.** 1.6.11
  introduces `isAppUpdateable`, one function deciding whether an app counts as having an update,
  where 1.6.10 asked that inline at every call site — each of which the fork had patched to call
  `skIsOutdated` instead.
- **The fork's rules now live inside upstream's function.** `isAppUpdateable` consults
  `skIsOutdated` first, so bare build-variant suffixes, pushes waved through with **Set as
  updated**, commit identity for entries following an upstream head, and the linked-package "only
  if newer" rule govern **every** call site — including any upstream adds later — instead of the
  eight the fork used to hold open.
- **`versionExtractionRegEx` works again.** The 1.6.10 patch had replaced the update-detection
  block wholesale, taking upstream's version-extraction regex with it as collateral. Routing
  through upstream's function restores it. With no regex configured — the default — nothing
  changes.
- **Update notifications honour "hide downgrades".** A source that moves *backwards* no longer
  raises a notification when that setting is on. Linked entries are unaffected: they still answer
  to `skIsOutdated` alone.

### Upstream's install pipeline replaces the fork's
- **Both had built the same thing.** Upstream 1.6.11 begins installing each app the moment its
  download finishes, serialising the installs behind a chain — which is what the fork's install
  queue did. Upstream's is now the one that runs, and the fork's `_obtainApp` machinery is gone.
- **Self-update-last needed no porting.** Upstream moves 獲得 itself to the end of the queue and
  defers its install until every other app is done, for the same reason the fork did: committing a
  self-update can end the process and strand whatever is still queued behind it.
- **Two things upstream does not do were kept.** Downloads stay **bounded** — upstream starts every
  download at once, where the fork holds them to a few in flight so parsing does not saturate the UI
  isolate — and an app waiting for a slot still shows as **queued** rather than blank. The
  double-claim guard also stays: a second tap, or a bulk run started while a per-app one is going,
  still cannot download or install the same app twice.

### Settings moved into sub-pages
- **Upstream split one long settings page into navigable sub-pages.** The **白い熊 獲得 UI**
  theming page is a row there now, wearing a brush icon since upstream's own *Appearance* page took
  the palette. Long-pressing the settings icon on the main screen still opens it directly.
- **The fork's page footer is gone, because upstream's is.** The icon row it was built on no longer
  exists; the **Help** link now lives in upstream's about section and still points at this repo.
- The remove-button colour settings moved into the new tile list, unchanged.

### What upstream 1.6.11 brings
- Installs begin as each download completes during batch updates; parallel downloads default on.
- A new **`obtainium://refresh`** deep link triggers an update check.
- Background update checks are separated from silent installs: the interval gates checks, the
  toggle gates installs only.
- A failed install-status reconciliation no longer marks an app as up to date.
- Settings reorganised into sub-pages; the filter dialog is now a bottom sheet; haptic feedback
  across UI actions and the download/install lifecycle.
- Export gains an installed-only filter; import reads via bytes when the path is null, fixing
  import on Samsung devices.
- Fixes for the vivo app store, uptodown (English locale, `.apk` extension), F-Droid
  `versionCode`-as-version, `obtainium://` unicode double-decoding, and a per-app empty GitHub
  token shadowing the global one.
- `compileSdk` 37; `permission_handler` 13, `fluttertoast` 10 and `workmanager` 0.10.7.

## 1.6.10+036

Base: upstream Obtainium **1.6.10** (`versionCode` 2349), fork `versionCode` `23490036`.

### A disabled action button no longer reads as an update (fix)
- **A dead button looked exactly like a live one.** The fork's filled-button theme pinned
  foreground, border and fill with `WidgetStatePropertyAll` — one value for every widget state,
  `disabled` included — which overrode Material's own dimming without putting anything in its place.
  Black fill, yellow label, yellow border, whether the button did something or nothing.
- **On the app page that was not merely cosmetic.** A linked entry's primary button always renders
  and always reads **Rebase & build**, disabled only by a null press handler, so an entry that was
  perfectly current showed what looked like a lit call to rebase — an update the entry itself never
  claimed, its version line reading `Installed / Latest` a few rows above it.
- **The label and the border are what fade.** They are the whole button, the fill being the page's
  own black; dimming black against black would say nothing, so the fill stays put. The alpha is the
  one `SkPillButton` already uses, so **Refresh from upstream** and **Rebase & build** fade alike
  when they share a row.
- **Every filled button in the app is covered** — dialog actions, the install/update banner, the
  per-app download button — so a disabled action now reads as disabled wherever it appears.

## 1.6.10+035

Base: upstream Obtainium **1.6.10** (`versionCode` 2349), fork `versionCode` `23490035`.

### A build-variant suffix no longer reads as an update (fix)
- **An upstream that tags its variant left a linked entry outdated forever.** Episteme cuts every
  Android release as `v<X.Y.Z>-oss`. Our own build strips that, so the two versions tie on every
  numeric part and differ only in the tail — and the comparator, unable to parse `-oss`, declined to
  order them at all. That refusal is deliberately read as "assume an update", so `1.0.52` against
  `1.0.52-oss` raised the download arrow on a fork that was exactly current, and no rebuild could
  ever clear it.
- **Such a tail is not a version component.** It names which artifact was cut, not which release,
  and it is a constant of the project — so it is now *understood* rather than merely tolerated. A
  tail of nothing but words leaves the parse exact, in the plain and the pre-release branch alike,
  making `1.0.52-oss` and `1.0.52-beta-oss` equal to their bare forms.
- **Digits are what keep it safe.** A respin (`-hotfix2`, `-r2`), and the date and `g<sha>` tails
  the `git-versioning` skill pins forks to, all carry one and stay unparsed — those comparisons
  remain exactly as conservative as before, so a real difference can still never be swallowed.
- **Commit-pinned builds are untouched.** They are settled by commit identity before the comparator
  is consulted at all, and their tails would not qualify as variant labels regardless.

## 1.6.10+034

Base: upstream Obtainium **1.6.10** (`versionCode` 2349), fork `versionCode` `23490034`.

### The upstream version of a followed commit can come from a file in the repo (new)
- **A release tag is the wrong source for projects that do not tag their version.** Commit tracking
  prefixed its version with the repo's newest release tag, which only works where that tag *is* the
  version. Jami keeps `versionName = "20260731-01"` in its `build.gradle.kts` and tags nothing but
  `android/release_502`, so a followed commit reported `android/release_502.<date>.g<sha>` — a
  string no rebase of the fork could ever match.
- **Name the file instead, and optionally a regex.** Two new fields under **`Follow commits instead
  of releases`** take a path in the repo and a pattern (default `versionName = "…"`, capture group
  one), and the version they yield becomes the prefix.
- **Read at the followed commit's own sha, not at the branch tip.** The whole string then describes
  one commit, instead of pairing a sha with a version literal that moved after it.
- **Best-effort, so nothing that works today can break.** An unset field, a missing file, a pattern
  that does not match, or a file over 1 MB (which the contents API declines to inline) all fall back
  to the release-tag lookup exactly as before.
- **The commit date is stated as UTC.** GitHub normalises committer dates to `Z` and drops the
  original offset, so UTC is the only rendering a fork's build script and this app can both compute.
  A fork pinning the commit's *own* timezone disagrees by a day for roughly one upstream commit in
  twenty — every one of them an update no rebase could satisfy. The `git-versioning` skill now
  specifies UTC on the other side.

## 1.6.10+033

Base: upstream Obtainium **1.6.10** (`versionCode` 2349), fork `versionCode` `23490033`.

### Set as updated (new)
- **A push not worth a rebuild can now be waved through.** A commit-followed source moves on every
  push, and most of those pushes are not worth rebasing and rebuilding the fork for — yet the
  download arrow stayed up until one happened. **`Set as updated`** records the upstream version the
  entry was told to ignore, and the entry counts as current until upstream **moves past it**.
- **Matched by the commit, not by the version literal.** When both sides name a commit, identity
  decides — the same sha spelled at a different length still reads as the same commit — and
  otherwise the version strings must match exactly. Either way the very next push brings the entry
  back.
- **Kept with the entry, not faked into its installed version.** A linked entry's installed version
  is refilled from the local build on every load, so a value written there would be undone within
  seconds; the mark is stored as a per-app setting instead. It rides along with export/import,
  survives an update check, and survives a trip through the **Additional options** page, whose form
  knows nothing about it and would otherwise drop it on the way out.
- **The whole app falls silent together.** The mark is read by the same `skIsOutdated` every
  decision site already uses, so the list badge, the *Updates* filter, the update count and the
  background notifications all clear with the arrow.
- **The detail page says why.** An entry that reads as current only by that mark states it, and at
  which version, under the linked-build note — nothing silently claims to be up to date.
- **`Reset install status` is the undo**, clearing the mark along with the recorded install, since
  the entry has gone up to date *by* that mark and there would be no other way back.
- **The bottom bar takes a second row for it.** On a linked entry the icon actions and the
  **`Refresh from upstream`** pill keep the top row, while **`Set as updated`** and
  **`Rebase & build`** share the row below, half the width each — three buttons fit no phone-width
  row. Entries without the new button keep the single row exactly as before, and the row does not
  reshuffle mid-refresh: while a check or a download runs the button is disabled, not removed.

## 1.6.10+032

Base: upstream Obtainium **1.6.10** (`versionCode` 2349), fork `versionCode` `23490032`.

### Name each entry yourself
- **The `Title` setting is now the whole title of an entry**, not one half of a composed one.
  Upstream's *App name* override only ever replaced the source's name, so a linked entry still read
  `<your build> ⇒ <source>` and two entries tracking **sibling repos of the same project** — a
  desktop repo and its Android port — were indistinguishable in the list. A hand-set title now
  replaces the line outright; the composed form moved to an internal `autoName` used only when no
  title is set.
- **It leads the Edit page** instead of sitting below the source's own switches, and **opens
  prefilled** with the title the entry currently shows, so renaming is an edit rather than a retype.
- **Handing the prefilled text back unchanged stores nothing.** That is what keeps an unrenamed
  entry following its source's name and its linked build's label; clearing the field returns it to
  automatic at any time.
- The field is labelled **Title** (it was *App name*), in the Edit page and in *Filter apps* alike —
  that filter matches the displayed title.

### A linked entry's update points at the rebuild it needs
- **The update button is back for linked entries**, wearing the **same filled download arrow** every
  other app with an update carries. It had been hidden because a linked entry's installed version is
  owned by the package it is compared against, so "mark updated" was undone by the very next save.
- **Pressing it says what to do instead.** A dialog names the fork to rebase and the upstream
  version to rebase onto, and points out that the entry clears itself as soon as the new build is on
  the phone. The APK for these entries is yours to build; 白い熊 獲得 only tracks the source.
- **The detail page's primary button follows the same route**, reading **`Rebase & build`** and
  opening the same dialog, in place of a *Mark updated* that would have been undone anyway. It stays
  disabled while the entry is up to date, and swipe-to-update still leaves linked entries alone.

## 1.6.10+028

Base: upstream Obtainium **1.6.10** (`versionCode` 2349), fork `versionCode` `23490028`.

### Refreshing one source
- **A `Refresh from upstream` pill** sits in every app page's bottom bar, next to the primary
  button. It re-checks that one source, so a single entry can be brought up to date without sweeping
  everything you track, and greys out while a check or a download for that app is already running.
- **Pull-down refresh on the app page now works at all.** The gesture was wired up from the start,
  but the scroll view lacked `AlwaysScrollableScrollPhysics`: a page short enough to fit on the
  screen could not overscroll, so the pull never reached the indicator.
- **A running yellow progress line** appears just under the status bar for the duration of a check —
  the same signal the main window shows — whether it came from the pill, the pull-down, or the
  automatic check when the page opens.
- The icon row scrolls sideways if it runs out of room, so the pill and the primary button keep
  their full width on a narrow screen.

### Comparing against your own build
- **A linked entry takes its icon and label from the build it is linked to**, in preference to the
  tracked package's own — an upstream that happens to be installed on the same phone no longer lends
  the entry its icon. The on-disk icon cache refreshes whenever a link supplies the icon, so a
  re-link survives a restart.
- **The list names your build in full**, `+NNN` counter included (`0.25.1+039`, not `0.25.1`). The
  stored installed version stays stripped, since that is the form the source's version is compared
  against; only the label changed.
- **Titles read ours-first**: `白い熊 自由動画 ⇒ FreeTube`, `白い熊 獲得 ⇒ Obtainium`.
- **The two versions in the "Compared against" note line up under each other**, each on its own row
  at the same left edge, instead of `(A → B)` where the leading parenthesis offset the first one by
  half a character.

### Following commits
- **A followed commit carries the upstream version it sits on** — `0.2.79.2026-08-02.gbc343f35`
  rather than a bare `2026-08-02.gbc343f35` — so both sides of the comparison read alike. The
  version comes from the repo's latest release tag with a leading `v` dropped, falling back to its
  newest tag. It is strictly a label: any failure, rate limits included, simply leaves it off rather
  than failing an update check that already succeeded.
- **Every `g<sha>` in a version string is read, not just the first.** A fork rebased onto more than
  one upstream pins one sha per upstream, each upstream gets its own tracked entry, and an entry
  counts as current as soon as **one** of those shas is the head it follows. Adjacent pins share the
  `.` between them, so the separators are matched as lookarounds; consuming one used to hide the
  next. The installed-app picker's ✨ suggestion follows the same rule.
- **`Include prereleases` and `Fallback to older releases` grey out while commits are followed.**
  They used to stay live and mutually exclusive, so switching one back on silently turned commit
  following off again. A disabled toggle row now greys its whole row, not just the thumb.

### List ordering
- **Our own builds lead every block.** The ordering pass partitions them out first, and every split
  that follows preserves the order it is handed, so 白い熊 entries head the updates-available,
  installed and not-installed runs alike — each still alphabetical within, and the same inside
  category and source groups.

## 1.6.10+022

Base: upstream Obtainium **1.6.10** (`versionCode` 2349), fork `versionCode` `23490022`.

### Update several apps at once (new)
- **The per-app download button no longer goes dead when another app is downloading.** Stock gates
  it — and swipe-to-update, and the detail page's install button — on a *global* "is any download
  running", so the first tap disabled every other app on the screen. Each button now looks only at
  **its own** app, so you can fire off as many as you like and watch them run together.
- **Downloads run concurrently, installs strictly one at a time.** Installing is exclusive by
  nature: the platform installer shows one prompt at a time, and the stock installer waits for you
  to come back to the foreground. So downloads pass through a **semaphore (three at once)** while
  installs pass through a **single global lock** — no overlapping install prompts, ever, and no
  download waiting on one.
- **Each app installs the moment its own download lands.** The obtain flow is pipelined per app
  rather than "download everything, then install everything", and the queued install is awaited
  separately, so an install prompt can never hold up the next download. The installer-permission
  prompt and the foreground wait moved under the lock with the install they belong to.
- **The same app can never be started twice** — a double tap, a swipe, or a bulk run overlapping a
  per-app one is dropped rather than downloaded again. Bulk update is therefore no longer disabled
  while downloads run: it queues what is new and skips what is already going.
- **A self-update still runs last and on its own**, since committing it can end the process that
  everything else is queued in.
- Apps waiting for a download slot or for the install lock read **`Queued`** in the list and on the
  detail page, with an empty progress track — distinct from both downloading and installing.

### The app-removal dialog
- The confirm button is now **`Remove`**, not `Continue` — it says what it does.
- It sits at the **far left**, with Cancel at the far right, so the destructive action is nowhere
  near where a reflex tap lands.
- **Dark blood red `#8B0000`** in both fill and border, with a **white** label. Cancel takes the
  border filled buttons carry in this theme — read off the theme itself, so it follows your accent
  colour and border-width knobs rather than a hardcoded value.
- **Both Remove colours are settable** in Settings (*Remove button colour*, which drives fill and
  border together, and *Remove button text colour*), through the same picker the theme colour uses.
  The picker no longer writes the setting when it is merely opened and dismissed.

### The action banner is gone by default
- The **Install/update apps** header row and its **Update** pill no longer appear unless you ask
  for them: *Action banner* now defaults to **None**, and upstream's legacy
  `showActionBannerForUpdateOnly` preference is no longer consulted, so the default holds on
  existing installs too. The dropdown still turns it back on. Nothing is lost — the per-app buttons
  and the selection menu's *Install/update selected apps* cover the same ground.

## 1.6.10+019

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
