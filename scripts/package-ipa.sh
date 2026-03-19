#!/bin/bash
set -euo pipefail

PROJECT_NAME="Calculator"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/Build/Products/Release-iphoneos/$PROJECT_NAME.app"
PAYLOAD_DIR="$BUILD_DIR/Payload"
IPA_PATH="$BUILD_DIR/$PROJECT_NAME.ipa"

xcodegen generate

xcodebuild \
  -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$PROJECT_NAME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build

rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"
codesign -s - --force --deep "$PAYLOAD_DIR/$PROJECT_NAME.app"

rm -f "$IPA_PATH"
cd "$BUILD_DIR"
/usr/bin/zip -qry "$PROJECT_NAME.ipa" Payload

