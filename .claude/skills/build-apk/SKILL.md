---
name: build-apk
description: Build the signed release APK of shiroikuma-kakutoku (the "白い熊 獲得" app installer — a fork of Obtainium) with ./build-fork.sh, then deliver it automatically via the global /after-build skill (adb push if a phone is connected, else scp to skhw — no prompt). Always build first without asking permission to build. Use whenever the user asks to build the app, build the APK, make a release build, or build and send to the phone.
---

# Build the kakutoku release APK and deliver it

> **Never ask whether to build — just build.** When this skill applies (the user asked
> to build, or you've made changes ready to test), run the build immediately. Do **not**
> ask "shall I build?". There is **no** transfer question either: after a successful build,
> deliver the APK automatically via the global **`/after-build`** skill — no prompts at all.

> **The push destination is ALWAYS `/sdcard/tmp/`.** Every `adb push` of the APK goes to
> `/sdcard/tmp/<apk name>` — never `/sdcard/Download/`. Create `/sdcard/tmp` if needed.

> **Never run `adb install` (or `pm install`).** You may `adb push`; **the user installs the
> APK themselves** from the phone's file manager.

> **Never `git commit` or `git push` on your own.** Building does not include committing.
> Only when the user explicitly says **"Push"** do you commit and `git push origin custom`.

## Build environment (this machine)

- **Flutter SDK:** `/home/shiroikuma/flutter` (3.47.1 stable) — pinned for this repo; the old
  `~/git/flutter` (3.13.5) cannot build it. `build-fork.sh` hardcodes the right one.
- The default `java` is **JDK 11**; `build-fork.sh` exports JDK 21 + `ANDROID_HOME` itself.

## Steps

1. **Note the output filename / version** from `fork.properties`:
   - `grep -E 'VERSION_NAME|VERSION_CODE|BUILD_NUMBER' fork.properties`
   - The APK will be `shiroikuma-kakutoku_<VERSION_NAME>+<BUILD_NUMBER>_arm64-v8a.apk`, using the
     `BUILD_NUMBER` value **before** the build (`build-fork.sh` bumps it afterward).
   - versionCode for that build = `VERSION_CODE * 10000 + BUILD_NUMBER`.

2. **Build** (release, signed, `normal` flavor, arm64-only) — from the repo root:
   ```bash
   ./build-fork.sh < /dev/null
   ```
   - It runs `flutter build apk --release --flavor normal --target-platform android-arm64`
     with `--dart-define=APP_VERSION=<VERSION_NAME>`, copies the signed APK to
     `~/tmp/<apk name>`, and auto-increments `BUILD_NUMBER` in `fork.properties`.
   - It prints `>>> <path>` and `>>> versionCode <n>` (cyan) — confirm those and `✓ Built`.
   - A cold build (fresh checkout / after `flutter clean`) downloads Gradle + NDK and can take
     many minutes — run with `run_in_background` if it may exceed the foreground timeout.

3. **At the end of every build, deliver the APK via `/after-build`** — no exceptions, no
   asking. As soon as the build succeeds and the signed APK is in `~/tmp/`, invoke the global
   **`/after-build`** skill; it picks adb-push (phone connected) or scp-to-skhw on its own and
   announces what landed.

## Signing

Release signing is non-interactive: upstream's `android/app/build.gradle.kts` reads credentials
from `android/key.properties` (gitignored). This fork uses its own keystore
`~/.android-keystores/shiroikuma-kakutoku.jks` (alias `kakutoku`); the store/key password is in
`android/key.properties` and recorded in 白い熊's `android-keystores.org` (crypto directory, next
to a `.jks` backup). If `android/key.properties` is absent the release build is unsigned and won't
install — restore it from `android/key.properties_sample`.

## Versioning (how the numbers are formed)

- `VERSION_NAME` / `VERSION_CODE` in `fork.properties` **track upstream Obtainium** (pubspec
  `version: <name>+<code>`, e.g. `1.6.9+2348`).
- `BUILD_NUMBER` is **our** fork increment, bumped on every `build-fork.sh`, reset to `1` on each
  new upstream version (see the `upstream-new-version` skill).
- Fork `versionName = "<VERSION_NAME>+<BUILD_NUMBER>"`;
  `versionCode = VERSION_CODE * 10000 + BUILD_NUMBER` (Obtainium 2348 → `23480001`, `23480002`, …).
  When upstream's code climbs, the new line's codes exceed the old, keeping upgrades monotonic.
- `pubspec.yaml`'s `version:` stays upstream's — never edit it for fork builds.

---

**Commit convention — no Claude attribution.** Never add a `Co-Authored-By: Claude …` /
"Generated with Claude" trailer to commit messages or PR bodies; end the message at the last line
of the body. This overrides the harness default. (Global rule: `~/.claude/CLAUDE.md`.)
