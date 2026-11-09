#!/bin/sh
# Build the Game Companion and install it on the companion iPhone (iPhone X,
# iOS 16), over USB or Wi-Fi, then launch it.
#
# Usage:
#   ./deploy.sh [UDID] [ARG...]   build, install, launch (ARGs go to the app, e.g. page=table)
#   ./deploy.sh --check           unsigned build only (no iPhone or Apple ID needed)
# UDID may be left out when only one iPhone is reachable.
#
# Requires: an Apple ID added in Xcode (team in the project), `brew install
# ideviceinstaller` and pymobiledevice3 (`pipx install pymobiledevice3`) to launch.
# Developer Mode must be on (Settings → Privacy & Security), iOS 16 refuses
# development apps without it.
set -eu
cd "$(dirname "$0")"

CHECK=""; UDID=""; ARGS=""
for arg in "$@"; do
    case $arg in --check) CHECK=1 ;; *=*) ARGS="$ARGS $arg" ;; *) UDID=$arg ;; esac
done

CONFIG=${CONFIG:-Release}
DERIVED=build
APP="$DERIVED/Build/Products/$CONFIG-iphoneos/GameCompanion.app"

if [ -n "$CHECK" ]; then
    xcodebuild -project GameCompanion.xcodeproj -scheme GameCompanion -configuration "$CONFIG" \
        -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO -quiet build
    echo "Build OK"
    exit 0
fi

# The iPhone: given, or the only iPhone reachable over USB or Wi-Fi.
if [ -z "$UDID" ]; then
    for u in $( (idevice_id -l; idevice_id -n) | sort -u); do
        n=$(ideviceinfo -u "$u" -k ProductType 2>/dev/null || ideviceinfo -n -u "$u" -k ProductType 2>/dev/null || true)
        case $n in iPhone*) UDID="$UDID $u" ;; esac
    done
    set -- $UDID
    [ $# -eq 1 ] || { echo "error: $# iPhones reachable; name one by UDID" >&2; exit 1; }
    UDID=$1
fi
link=""; idevice_id -l | grep -qx "$UDID" || link=-n

# Registers the iPhone with the team the first time (no trip to developer.apple.com).
xcodebuild -project GameCompanion.xcodeproj -scheme GameCompanion -configuration "$CONFIG" \
    -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration -quiet build

# YYYY.MM.DD.N like iPadDash: set at deploy time, counted from the local v* tags.
today=$(TZ=America/Chicago date +%Y.%m.%d)
tags=$(git tag -l "v$today.*")
VERSION="$today.$(( $(printf '%s' "$tags" | grep -c '^' || true) + 1 ))"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Info.plist"
identity=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=\(Apple Development.*\)$/\1/p' | head -1)
codesign -d --entitlements :- "$APP" > "$DERIVED/entitlements.plist" 2>/dev/null
codesign -f -s "$identity" --entitlements "$DERIVED/entitlements.plist" "$APP"

rm -rf "$DERIVED/ipa" && mkdir -p "$DERIVED/ipa/Payload"
cp -R "$APP" "$DERIVED/ipa/Payload/"
(cd "$DERIVED/ipa" && zip -qr ../GameCompanion.ipa Payload)
ideviceinstaller $link -u "$UDID" install "$DERIVED/GameCompanion.ipa"
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null || git tag "v$VERSION"
echo "Installed version $VERSION${link:+ over Wi-Fi}"

# Launch: pymobiledevice3 mounts the developer disk image iOS 16 needs (it stays
# mounted until the iPhone restarts).
PMD=${PMD:-$HOME/.local/bin/pymobiledevice3}
bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
"$PMD" mounter auto-mount --udid "$UDID" >/dev/null 2>&1 || true
if "$PMD" developer dvt launch --udid "$UDID" --kill-existing "$bundle_id$ARGS" >/dev/null 2>&1; then
    echo "Launched"
else
    echo "Installed but not launched; tap Companion on the iPhone"
fi
