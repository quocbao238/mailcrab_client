#!/usr/bin/env bash
#
# Builds, signs and notarises the macOS DMG. Run on a Mac that holds the
# Developer ID private key; CI cannot do this, which is why macOS is not in
# the release workflow.
#
#   tool/build_macos_release.sh 1.1.1
#
# Requires MACOS_SIGN_IDENTITY, e.g.
#   export MACOS_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"
#   security find-identity -v -p codesigning     # to list what you have
#
# Notarisation is skipped unless a notarytool profile exists. Create one once,
# with an app-specific password from appleid.apple.com:
#   xcrun notarytool store-credentials mailcrab-notary \
#     --apple-id you@example.com --team-id TEAMID --password xxxx-xxxx-xxxx-xxxx
#
# Or with an App Store Connect API key, which is not tied to a personal Apple
# ID and is the better choice if this ever moves to CI:
#   xcrun notarytool store-credentials mailcrab-notary \
#     --key AuthKey_XXXX.p8 --key-id KEYID --issuer ISSUER-UUID
#
set -euo pipefail

VERSION="${1:-}"
[ -n "$VERSION" ] || { echo "usage: $0 <version>   e.g. $0 1.1.1" >&2; exit 1; }

IDENTITY="${MACOS_SIGN_IDENTITY:-}"
PROFILE="${NOTARY_PROFILE:-mailcrab-notary}"
APP="build/macos/Build/Products/Release/MailCrab.app"
DMG="MailCrab-macos.dmg"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

cd "$(dirname "$0")/.."

echo "==> Building $VERSION"
flutter build macos --release \
  --build-name="$VERSION" --build-number="$BUILD_NUMBER"

if [ -z "$IDENTITY" ]; then
  echo "!! MACOS_SIGN_IDENTITY unset — producing an UNSIGNED build."
  echo "   Gatekeeper will reject it; users must use Open Anyway."
else
  echo "==> Signing nested code"
  # -depth walks a directory's contents before the directory itself, so
  # anything nested is signed first — a bundle's signature is only valid if
  # everything inside it was already signed. No depth limit, so helpers and
  # nested frameworks a plugin adds later are covered too.
  find "$APP/Contents" -depth \
    \( -name "*.framework" -o -name "*.dylib" -o -name "*.xpc" \
       -o -name "*.app" -o -name "*.bundle" \) -print0 |
    while IFS= read -r -d '' item; do
      codesign --force --timestamp --options runtime \
        --sign "$IDENTITY" "$item"
    done

  echo "==> Signing the app"
  codesign --force --timestamp --options runtime \
    --entitlements macos/Runner/Release.entitlements \
    --sign "$IDENTITY" "$APP"
  codesign --verify --strict --deep --verbose=2 "$APP"
fi

echo "==> Packaging $DMG"
rm -rf dmg_stage "$DMG"
mkdir dmg_stage
cp -R "$APP" dmg_stage/
ln -s /Applications dmg_stage/Applications
hdiutil create -volname "MailCrab" -srcfolder dmg_stage -ov -format UDZO "$DMG"
rm -rf dmg_stage

if [ -n "$IDENTITY" ]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"

  if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "==> Notarising (a few minutes)"
    xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
    xcrun stapler staple "$DMG"
  else
    echo "!! No notarytool profile '$PROFILE' — signed but NOT notarised."
    echo "   Gatekeeper still rejects this; see the header of this script."
  fi
fi

echo
echo "==> Verifying"
codesign -dv --verbose=2 "$DMG" 2>&1 | grep -E "Authority|Signature" || true
xcrun stapler validate "$DMG" 2>&1 | tail -1 || true
spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 | tail -2 || true

echo
echo "Built $DMG — attach it with:"
echo "  gh release upload v$VERSION $DMG"
