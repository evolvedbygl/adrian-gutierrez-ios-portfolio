#!/bin/bash
# Archive, export, upload to App Store Connect, and attach to TestFlight internal testers.
#
# Release tooling only: it is NOT needed to build or run the app.
# No credentials live in this repo. Configuration is read from the environment, or from
# a git-ignored file at Scripts/.asc.env containing:
#
#   ASC_KEY_ID=...          # App Store Connect API key ID
#   ASC_ISSUER_ID=...       # App Store Connect API issuer ID
#   ASC_KEY_PATH=...        # absolute path to the AuthKey_XXXX.p8 file (kept outside the repo)
#   ASC_APP_ID=...          # numeric App Store Connect app ID
#   DEVELOPMENT_TEAM=...    # Apple Developer team ID
#   TESTER_EMAIL=...        # optional: also attach the build to this individual tester
#
# Requires: Xcode, python3 with PyJWT (pip3 install pyjwt cryptography).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if [ -f "$SCRIPT_DIR/.asc.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/.asc.env"
    set +a
fi

for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH ASC_APP_ID DEVELOPMENT_TEAM; do
    if [ -z "${!var:-}" ]; then
        echo "Missing $var. See the header of this script." >&2
        exit 1
    fi
done
if [ ! -f "$ASC_KEY_PATH" ]; then
    echo "API key file not found at ASC_KEY_PATH." >&2
    exit 1
fi

PROJECT="Portfolio.xcodeproj"
SCHEME="Portfolio"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/Portfolio.xcarchive"
EXPORT_PATH="$BUILD_DIR/exported"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

mkdir -p "$BUILD_DIR"

cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>$DEVELOPMENT_TEAM</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
PLIST

BUILD_NUMBER=$(xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" -configuration Release 2>/dev/null \
    | awk -F' = ' '/ CURRENT_PROJECT_VERSION =/ {print $2; exit}')
echo "Build number: $BUILD_NUMBER"

AUTH_ARGS=(
    -allowProvisioningUpdates
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

echo "Archiving..."
xcodebuild clean archive \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=iOS' \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    "${AUTH_ARGS[@]}" \
    -quiet

echo "Exporting..."
rm -rf "$EXPORT_PATH"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" \
    "${AUTH_ARGS[@]}" \
    -quiet

IPA_PATH=$(find "$EXPORT_PATH" -name "*.ipa" | head -n 1)
if [ -z "$IPA_PATH" ]; then
    echo "No .ipa produced." >&2
    exit 1
fi

echo "Uploading to App Store Connect..."
xcrun altool --upload-app -f "$IPA_PATH" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "Waiting for processing and attaching to TestFlight..."
python3 "$SCRIPT_DIR/distribute_testflight.py" --version "$BUILD_NUMBER"
