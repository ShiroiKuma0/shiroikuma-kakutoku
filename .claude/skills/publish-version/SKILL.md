---
name: publish-version
description: Publish the latest built shiroikuma-kakutoku APK as a GitHub release of the fork — create the version tag, attach the APK, update the fork README and the fork changelog (CHANGELOG-shiroikuma.md), ensure the GitHub default branch is `custom` so the repo page lands on our work, and write specific release notes. Use when the user says publish / release / cut a version / ship this build / make a GitHub release / publish the latest build.
---

# Publish a kakutoku version to GitHub

Turn the latest tested build into a public GitHub **release** of the fork
(`ShiroiKuma0/shiroikuma-kakutoku`): a version tag, the APK as a downloadable asset, an updated
README + fork changelog, and a default branch (`custom`) so the repo landing page shows our work.

> **This is outward-facing — it publishes to GitHub.** The user invoking this skill *is* the
> authorization. Still, summarise the exact version + assets first, then proceed. Never publish a
> build the user hasn't tested.

> **No `Co-Authored-By: Claude` / "Generated with Claude" trailer** in commits or release notes —
> end at the last line of the body. (Global rule.)

## What gets published

The **latest APK in `~/tmp/`** (`shiroikuma-kakutoku_<VERSION_NAME>+<BUILD_NUMBER>_arm64-v8a.apk`) —
the build the user just tested on-device. Derive the version from the **APK filename**, NOT
`fork.properties` (whose `BUILD_NUMBER` is already the *next* number, because `build-fork.sh` bumps
it after building).

```bash
APK=$(ls -t ~/tmp/shiroikuma-kakutoku_*.apk 2>/dev/null | head -1)
VERSION=$(basename "$APK" | sed -E 's/^shiroikuma-kakutoku_(.+)_arm64-v8a\.apk$/\1/')   # e.g. 1.6.9+1
TAG="$VERSION"   # the tag is the bare version, no "v" prefix (e.g. 1.6.9+1)
```

If `$APK` is empty, stop and tell the user there's no built APK to publish (run `build-apk` first).

## Preconditions to check

1. **The APK matches `HEAD`.** The user pushes after testing, so `custom`'s `HEAD` should be the
   code that produced this APK. If the working tree has uncommitted source changes, or `HEAD` was
   advanced past the build, warn — the safest path is to rebuild (`build-apk`) so the published APK
   and the tag agree. Don't publish a tag that points at code the APK wasn't built from.
2. **On `custom`** (`git rev-parse --abbrev-ref HEAD` = `custom`) and pushed
   (`git push origin custom` if ahead).
3. **The tag doesn't already exist** (`git tag -l "$TAG"` empty, and
   `gh release view "$TAG" -R ShiroiKuma0/shiroikuma-kakutoku` 404s). If it exists, the version was
   already published — confirm with the user before re-cutting.

## Steps

1. **Ensure the GitHub default branch is `custom`** so the repo page lands on our README, not
   upstream's `main`:
   ```bash
   gh repo edit ShiroiKuma0/shiroikuma-kakutoku --default-branch custom
   gh repo edit ShiroiKuma0/shiroikuma-kakutoku \
     --description "白い熊 獲得 — a fork of Obtainium, the get-updates-straight-from-the-source app installer: black-yellow 白い熊 styling and fork refinements. Side-by-side with upstream, GPL-3."
   ```
   (Idempotent — safe to run every time.)

2. **Update the fork README.** On the first publish, replace upstream's `README.md` with a
   futokxkb-style fork README (what this fork is, how it differs, the version scheme, a
   “📥 Latest release: [`<VERSION>`](…/releases/latest)” line, licence note, upstream credit).
   On later publishes just update the version in that line.

3. **Update `CHANGELOG-shiroikuma.md`** (the fork changelog — never fold fork notes into any
   upstream file). Keep it **specific — list everything**. Rename the `## <old> — current` heading
   to the released version and add a fresh `## <new> — current` section above it summarising what
   changed **since the last tag**:
   ```bash
   git log --oneline <previous-tag>..HEAD     # the commits to fold into the new section
   ```
   Group them by area, one specific bullet each — not raw commit subjects. On the very first
   publish there is no previous tag; enumerate everything built on top of stock Obtainium.

4. **Commit the docs** on `custom` and push:
   ```bash
   git add README.md CHANGELOG-shiroikuma.md
   git commit -m "Release <VERSION>: README + changelog"
   git push origin custom
   ```

5. **Tag and release.** Annotated tag at `HEAD`, then a GitHub release targeting `custom` with the
   APK attached and the new changelog section as the notes. **Always pin the repo with
   `-R ShiroiKuma0/shiroikuma-kakutoku`** — the working copy has an `upstream` remote
   (`ImranR98/Obtainium`), and bare `gh release` will otherwise act against upstream. Write the
   notes to a real file under `~/tmp` (do **not** rely on `$TMPDIR`, which is unset when the
   sandbox is off):
   ```bash
   REPO=ShiroiKuma0/shiroikuma-kakutoku
   git tag -a "$TAG" -m "白い熊 獲得 $VERSION"
   git push origin "$TAG"
   NOTES="$HOME/tmp/kakutoku_release_notes.md"
   # the current version's changelog section, heading line dropped (to the next "## " or EOF):
   sed -n "/^## ${VERSION} —/,/^## [0-9]/p" CHANGELOG-shiroikuma.md | sed '/^## [0-9]/d' | tail -n +2 > "$NOTES"
   gh release create "$TAG" "$APK" -R "$REPO" \
     --target custom \
     --title "白い熊 獲得 $VERSION" \
     --notes-file "$NOTES"
   rm -f "$NOTES"
   ```
   Keep the APK asset name as built (`shiroikuma-kakutoku_<VERSION>_arm64-v8a.apk`).

6. **Report** the release URL and confirm the default branch:
   ```bash
   gh release view "$TAG" -R ShiroiKuma0/shiroikuma-kakutoku --json url -q .url
   gh repo view ShiroiKuma0/shiroikuma-kakutoku --json defaultBranchRef -q .defaultBranchRef.name
   ```

## Notes

- `git push`, `gh` and `scp` need `~/.ssh` / `~/.config/gh`, which the command sandbox blocks — run
  the push / `gh` / tag steps with the sandbox disabled (`dangerouslyDisableSandbox: true`), same as
  the other fork skills.
- This skill **does not build** — it ships whatever is newest in `~/tmp/`. If the user wants a fresh
  build first, that's the `build-apk` skill's job.
- `main` stays tracking upstream; releases are always cut from `custom`. After an
  `upstream-new-version` rebase, the first release on the new base resets the build number to `+1`.
