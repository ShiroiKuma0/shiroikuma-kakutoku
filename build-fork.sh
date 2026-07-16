#!/usr/bin/env bash
# Build the signed release APK of shiroikuma-kakutoku (白い熊 獲得, Obtainium fork),
# copy it to ~/tmp/shiroikuma-kakutoku_<VERSION_NAME>+<BUILD_NUMBER>_arm64-v8a.apk,
# then bump BUILD_NUMBER in fork.properties.
#
# (Upstream's own build.sh is untouched — it drives their multi-flavor release
# pipeline; this script is the fork's build entry point.)
#
# Versioning: fork.properties drives android/app/build.gradle.kts —
#   versionName = "<VERSION_NAME>+<BUILD_NUMBER>"
#   versionCode = VERSION_CODE * 10000 + BUILD_NUMBER
set -euo pipefail
cd "$(dirname "$0")"

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export ANDROID_HOME=/home/shiroikuma/android-sdk
FLUTTER=/home/shiroikuma/flutter/bin/flutter

VERSION_NAME=$(grep '^VERSION_NAME=' fork.properties | cut -d= -f2)
VERSION_CODE=$(grep '^VERSION_CODE=' fork.properties | cut -d= -f2)
BUILD_NUMBER=$(grep '^BUILD_NUMBER=' fork.properties | cut -d= -f2)

"$FLUTTER" build apk --release --flavor normal \
    --target-platform android-arm64 \
    --dart-define=APP_VERSION="$VERSION_NAME"

OUT=build/app/outputs/flutter-apk/app-normal-release.apk
APK="$HOME/tmp/shiroikuma-kakutoku_${VERSION_NAME}+${BUILD_NUMBER}_arm64-v8a.apk"
cp "$OUT" "$APK"

sed -i "s/^BUILD_NUMBER=.*/BUILD_NUMBER=$((BUILD_NUMBER + 1))/" fork.properties

printf '\033[36m>>> %s\033[0m\n' "$APK"
printf '\033[36m>>> versionCode %s\033[0m\n' "$((VERSION_CODE * 10000 + BUILD_NUMBER))"
