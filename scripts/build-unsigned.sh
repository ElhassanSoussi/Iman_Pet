#!/bin/bash
# Runs on a cloud Mac with the iPhone SDK, never installs Xcode locally.
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun --sdk iphoneos --show-sdk-version
xcodegen generate --spec project.yml
xcodebuild -project Iman.xcodeproj -scheme Iman -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
mkdir -p build/packaging/Payload
cp -R build/Build/Products/Release-iphoneos/Iman.app build/packaging/Payload/
(cd build/packaging && /usr/bin/zip -qr ../Iman-unsigned.ipa Payload)
shasum -a 256 build/Iman-unsigned.ipa > build/Iman-unsigned.ipa.sha256
