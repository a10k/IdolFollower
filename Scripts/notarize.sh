#!/usr/bin/env bash
# Signs the .app with a Developer ID certificate and notarizes it with Apple.
# Requires env vars: DEVELOPER_ID_CERT (base64 .p12), DEVELOPER_ID_CERT_PASSWORD,
#                    APPLE_ID, APPLE_ID_PASSWORD (app-specific), APPLE_TEAM_ID
set -euo pipefail

APP="$1"

# ── Keychain ──────────────────────────────────────────────────────────────────
KC="idol-$(uuidgen).keychain"
KC_PASS="$(uuidgen)"
security create-keychain -p "$KC_PASS" "$KC"
security set-keychain-settings -lut 21600 "$KC"
security unlock-keychain -p "$KC_PASS" "$KC"

echo "$DEVELOPER_ID_CERT" | base64 --decode > /tmp/cert.p12
security import /tmp/cert.p12 -k "$KC" -P "$DEVELOPER_ID_CERT_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -k "$KC_PASS" "$KC" 2>/dev/null
security list-keychain -d user -s "$KC" $(security list-keychain -d user | sed s/\"//g)
rm /tmp/cert.p12

# ── Sign ──────────────────────────────────────────────────────────────────────
# Sign nested frameworks individually before signing the app (--deep is unreliable)
# --timestamp is required for notarization
find "$APP/Contents/Frameworks" -name "*.framework" 2>/dev/null | while read -r fw; do
    codesign --force --options runtime --timestamp \
        --sign "Developer ID Application" \
        "$fw"
done

codesign --force --options runtime --timestamp \
    --sign "Developer ID Application" \
    "$APP"

echo "Signed: $APP"

# ── Notarize ──────────────────────────────────────────────────────────────────
ZIP=/tmp/idol-notarize.zip
zip -r "$ZIP" "$APP"

SUBMIT_OUT=$(xcrun notarytool submit "$ZIP" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_ID_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait 2>&1)
echo "$SUBMIT_OUT"

SUBMISSION_ID=$(echo "$SUBMIT_OUT" | grep '^\s*id:' | head -1 | awk '{print $2}')

STATUS=$(echo "$SUBMIT_OUT" | grep 'status:' | tail -1 | awk '{print $2}')
if [ "$STATUS" != "Accepted" ]; then
    echo "Notarization failed with status: $STATUS"
    if [ -n "$SUBMISSION_ID" ]; then
        echo "Fetching Apple notarization log for $SUBMISSION_ID..."
        xcrun notarytool log "$SUBMISSION_ID" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_ID_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" || true
    fi
    exit 1
fi

rm "$ZIP"

# ── Staple ────────────────────────────────────────────────────────────────────
xcrun stapler staple "$APP"
echo "Notarized and stapled: $APP"

# ── Cleanup ───────────────────────────────────────────────────────────────────
security delete-keychain "$KC" 2>/dev/null || true
