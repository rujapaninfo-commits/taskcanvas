#!/bin/bash
# App Store Connect への提出スクリプト
# 実行前に: xcodegen generate → Xcode で Archive → このスクリプトを実行
set -e

SCHEME="TaskCanvas"
PROJECT="TaskCanvas.xcodeproj"
ARCHIVE_PATH="build/TaskCanvas.xcarchive"
EXPORT_PATH="build/AppStore"
EXPORT_OPTIONS="ExportOptions-AppStore.plist"
UPLOAD="${UPLOAD:-0}"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Archiving..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic

echo "==> Exporting for App Store..."
ACTIVE_EXPORT_OPTIONS="$EXPORT_OPTIONS"
if [ "$UPLOAD" = "1" ]; then
  ACTIVE_EXPORT_OPTIONS="$(mktemp -t TaskCanvas-UploadOptions).plist"
  cp "$EXPORT_OPTIONS" "$ACTIVE_EXPORT_OPTIONS"
  /usr/libexec/PlistBuddy -c "Add :destination string upload" "$ACTIVE_EXPORT_OPTIONS"
  trap 'rm -f "$ACTIVE_EXPORT_OPTIONS"' EXIT
  echo "==> App Store Connect へ直接アップロードします..."
fi

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$ACTIVE_EXPORT_OPTIONS" \
  -allowProvisioningUpdates

if [ "$UPLOAD" = "1" ]; then
  echo "==> App Store Connect へのアップロード完了"
else
  echo "==> Done: $EXPORT_PATH"
  echo ""
  echo "次のステップ:"
  echo "  - UPLOAD=1 scripts/submit-appstore.sh で直接アップロード"
  echo "  - または Xcode Organizer / Transporter で $EXPORT_PATH/TaskCanvas.pkg をアップロード"
fi
