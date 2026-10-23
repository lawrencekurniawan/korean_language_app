#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

OUTPUT_DIR=${OUTPUT_DIR:-"$ROOT/build"}
DERIVED_DATA=${DERIVED_DATA:-"$ROOT/.build/DerivedDataDevice"}

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate

xcodebuild \
    -project Sori.xcodeproj \
    -scheme Sori \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    build

APP_PATH="$DERIVED_DATA/Build/Products/Release-iphoneos/Sori.app"
if [ ! -d "$APP_PATH" ]; then
    echo "The Release app was not produced at $APP_PATH" >&2
    exit 1
fi

rm -rf "$OUTPUT_DIR/Payload" "$OUTPUT_DIR/Sori.ipa"
mkdir -p "$OUTPUT_DIR/Payload"
cp -R "$APP_PATH" "$OUTPUT_DIR/Payload/Sori.app"
(cd "$OUTPUT_DIR" && /usr/bin/zip -qry Sori.ipa Payload)

echo "Created $OUTPUT_DIR/Sori.ipa (unsigned, for SideStore)"
