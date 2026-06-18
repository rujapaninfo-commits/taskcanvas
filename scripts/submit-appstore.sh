#!/bin/bash
# App Store Connect への提出スクリプト
# 実行前に: xcodegen generate → Xcode で Archive → このスクリプトを実行
set -e

SCHEME="TaskCanvas"
PROJECT="TaskCanvas.xcodeproj"
ARCHIVE_PATH="build/TaskCanvas.xcarchive"
EXPORT_PATH="build/AppStore"
EXPORT_OPTIONS="ExportOptions-AppStore.plist"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Archiving..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Automatic

echo "==> Exporting for App Store..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo "==> Done: $EXPORT_PATH"
echo ""
echo "次のステップ:"
echo "  - Xcode Organizer または Transporter.app で $EXPORT_PATH/TaskCanvas.pkg を App Store Connect にアップロード"
