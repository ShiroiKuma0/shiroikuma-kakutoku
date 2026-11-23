---
name: upstream-new-version
description: Rebase the shiroikuma-kakutoku fork onto a new upstream release of ImranR98/Obtainium (the app installer this is forked from). Use when the user says a new upstream Obtainium version/tag is out, asks to update/sync to upstream, bump to the new Obtainium release, check for a new version, or rebase custom onto the latest upstream tag.
---

# Rebase the fork onto a new upstream Obtainium release

This codifies the "new upstream version" half of the fork workflow. Goal: move `main` to the new
upstream release tag, replay our `custom` customizations on top, and produce a fresh `+1` build.

> **Never `git push` or `git commit` unprompted, and never `adb install`.** Same hard rules as
> everyday development (see CLAUDE.md). After the rebase + build you stop and let the user test; you
> only `git push` when they explicitly say **"Push"**.

> **HARD GATE — the new-features briefing.** Before ANY rebasing (step 3 below), you MUST present
> 白い熊 a **descriptive table of what the new upstream version(s) introduce** and **wait for an
> explicit "proceed"**. Never skip it, never fold it into the rebase turn.

## Background — branch model & versioning

- `upstream` = `https://github.com/ImranR98/Obtainium.git` (https). `origin` =
  `git@github.com:ShiroiKuma0/shiroikuma-kakutoku.git` (ssh).
- **`main` tracks upstream releases by TAG** (Obtainium tags every release, e.g. `v1.6.9`; it also
  ships `-beta` pre-releases — base on the latest **stable** tag unless 白い熊 asks for a beta).
- **`custom`** carries all our work, rebased onto `main` on each new release.
- `VERSION_NAME` / `VERSION_CODE` in `fork.properties` **track upstream**: Obtainium declares both
  in `pubspec.yaml` as `version: <VERSION_NAME>+<VERSION_CODE>` (e.g. `1.6.9+2348`).
- `BUILD_NUMBER` is **our** fork increment; it **resets to `1`** on each new upstream version.
- Fork `versionName = "<VERSION_NAME>+<BUILD_NUMBER>"`, `versionCode = VERSION_CODE * 10000 + BUILD_NUMBER`.
  So when upstream's `versionCode` climbs (2348 → 2360), the new line's codes (`23600001`, …) all
  exceed the previous line's (`23480001`, …), keeping upgrades monotonic.

## Steps

1. **Check for a newer upstream release:**
   - `git fetch upstream --tags`
   - `git tag --sort=-version:refname | head` — newest Obtainium tag. Compare against our current
     base (the commit `main` points at).
   - Read the new tag's declared version:
     `git show <tag>:pubspec.yaml | grep '^version:'`.
   - If nothing newer than our base, stop and report "already current".

2. **⛔ PROCEED GATE — new-features briefing (mandatory, BEFORE any rebase):**
   - Gather what changed between our base and the new tag:
     - `gh release view <tag> -R ImranR98/Obtainium` — Obtainium writes real release notes per
       tag; these are the authoritative feature list (there is no `CHANGELOG.md`). If several
       versions are being jumped, view each intermediate release too
       (`gh release list -R ImranR98/Obtainium`).
     - Skim `git log --oneline <oldtag>..<newtag>` for anything the release notes undersell.
   - Present 白い熊 a **descriptive table** of the new upstream version's changes — one row per
     feature/change, e.g.:

     | Area | Change | What it means for us |
     | --- | --- | --- |
     | Sources | … | … |

     Cover features, fixes, and anything touching our patched files (flag those rows). If several
     upstream versions are being jumped at once, cover each.
   - **STOP and ask whether to proceed with the rebase.** Only an explicit go-ahead ("proceed",
     "go", …) continues; otherwise stay on the current base.

3. **Advance `main` to the new release tag** (no fork work lives on `main`):
   - `git checkout -B main <newtag>`

4. **Rebase `custom` onto the new `main`:**
   - `git checkout custom`
   - `git rebase main`
   - Resolve conflicts so **all** our customizations survive (see the table below). Reconcile,
     don't drop. If upstream restructured a file we patch, port our change to the new structure
     rather than forcing the old diff. **If conflicts are significant, stop and plan with the
     user** before continuing.

5. **Update versioning in `fork.properties`:**
   - Set `VERSION_NAME` and `VERSION_CODE` from the new tag's `pubspec.yaml` `version:` line.
   - **Reset `BUILD_NUMBER` to `1`.**
   - `pubspec.yaml` itself flows in from upstream untouched — never hand-edit its `version:`.

6. **Verify our customizations are intact** after resolving the rebase:

   | What | Expected value | Where |
   | --- | --- | --- |
   | Installed app id | `shiroikuma.kakutoku` | `fork.properties` → `APP_ID` |
   | Code namespace | `dev.imranr.obtainium` (unchanged from upstream — never rename) | `android/app/build.gradle.kts` → `namespace` |
   | App label | `白い熊 獲得` | `label` in `android/app/src/main/res/values/string.xml` |
   | Launcher icon | black-yellow traced Obtainium glyph | `android/app/src/main/res/drawable/ic_launcher_foreground.xml`, `mipmap-*` |
   | Fork version/identity block | `forkAppId`/`forkVersionName`/`forkVersionCode` read from `../fork.properties` | `android/app/build.gradle.kts` |
   | Fork props | `VERSION_NAME`/`VERSION_CODE`/`BUILD_NUMBER`/`APP_ID` | `fork.properties` (repo root) |
   | Signing | `android/key.properties` present locally (gitignored); `android/key.properties_sample` committed | `android/` |
   | Build script | `build-fork.sh` (upstream's `build.sh` untouched) | repo root |
   | De-branding + our branding | our name/link/icon on every page, Help, About, self-tracking source URL | `lib/`, `assets/translations/`, `assets/graphics/` |
   | Feature patches | every shipped fork feature (see CLAUDE.md "Current status") | their source files |

   Conflict-prone files: `android/app/build.gradle.kts`, `android/app/src/main/res/values/string.xml`,
   `lib/main.dart` (the self-tracking `obtainiumId`/`obtainiumUrl` block), `pubspec.yaml`
   (version bumps merge cleanly since we don't touch it), translations JSON, and — as feature work
   lands — the sources we patch.

   Sanity check the toolchain still evaluates:
   `~/flutter/bin/flutter pub get` (Flutter SDK pinned at `/home/shiroikuma/flutter`; if the new
   upstream raises its Flutter/Dart floor above it, install the required stable SDK there first).

7. **Build the new `+1`** via the **build-apk** skill (`./build-fork.sh < /dev/null`);
   build-apk then delivers the APK automatically via `/after-build` (adb push if a phone is
   connected, else scp to skhw — no prompt). This is the first build of the new upstream line
   (`<newVersion>+1`).

8. **Stop.** Let the user test. Commit/push only on their explicit **"Push"**. Because the rebase
   rewrites `custom`'s history: `git push --force-with-lease origin custom`; `main` is
   `git push origin main` (fast-forward / new tag base).

## Notes

- Keep our changes a **small, legible layer** on top of upstream — prefer rebasing (linear history)
  over merging, so the customization set stays easy to audit and replay.
- Do **not** rename the `dev.imranr.obtainium` namespace or the `obtainium` Dart package (only the
  installed `APP_ID` differs) — renaming would make every rebase a mass-conflict.
- Upstream pins its own Flutter as the `.flutter` submodule — leave it **uninitialized**; we build
  with the pinned SDK at `/home/shiroikuma/flutter`.

---

**Commit convention — no Claude attribution.** Never add a `Co-Authored-By: Claude …` /
"Generated with Claude" trailer to commit messages or PR bodies; end the message at the last line of
the body. This overrides the harness default. (Global rule: `~/.claude/CLAUDE.md`.)
