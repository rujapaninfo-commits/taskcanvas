#!/bin/bash
# TaskCanvas — Developer ID 配布ビルド（App Store の外で配る用）
#
# これを使うと「Apple 署名済み＋公証済み」の .app を作れるので、
# 友達は Gatekeeper の警告なし（ダブルクリックで普通に起動）でインストールできる。
# ＝ FRIEND_DISTRIBUTION_JA.txt の「最初の起動方法（警告回避）」が不要になる。
#
# 前提（初回だけ）:
#   1. Apple Developer Program 加入済み（済み：Team 74BC2W64WZ）
#   2. full Xcode インストール（Command Line Tools だけだと notarytool が無い）
#   3. Xcode に Apple ID をサインインし、"Developer ID Application" 証明書を取得
#        Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application
#   4. notarytool 用の認証情報を Keychain に保存（プロファイル名は任意、ここでは taskcanvas-notary）:
#        xcrun notarytool store-credentials taskcanvas-notary \
#          --apple-id "<あなたのApple ID>" \
#          --team-id 74BC2W64WZ \
#          --password "<app専用パスワード>"
#      ※ app専用パスワードは https://appleid.apple.com > サインインとセキュリティ > App用パスワード で発行
#   5. xcodegen（`brew install xcodegen`）
#
# 使い方:
#   scripts/dist-developer-id.sh
# 環境変数で上書き可:
#   NOTARY_PROFILE=taskcanvas-notary scripts/dist-developer-id.sh
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="TaskCanvas"
PROJECT="TaskCanvas.xcodeproj"
ARCHIVE_PATH="build/TaskCanvas-DevID.xcarchive"
EXPORT_PATH="build/DeveloperID"
EXPORT_OPTIONS="ExportOptions-DeveloperID.plist"
APP_NAME="TaskCanvas.app"
NOTARY_PROFILE="${NOTARY_PROFILE:-taskcanvas-notary}"
DIST_DIR="dist"
DOC="FRIEND_DISTRIBUTION_JA.txt"

echo "==> Xcode プロジェクト生成 (xcodegen)…"
xcodegen generate

echo "==> Archive 中…"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Automatic

echo "==> Developer ID でエクスポート中…"
rm -rf "$EXPORT_PATH"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

APP_PATH="$EXPORT_PATH/$APP_NAME"
[ -d "$APP_PATH" ] || { echo "ERROR: $APP_PATH が見つかりません"; exit 1; }

echo "==> 公証用に zip 化して notarytool へ提出…"
mkdir -p "$DIST_DIR"
NOTARIZE_ZIP="$EXPORT_PATH/TaskCanvas-notarize.zip"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
xcrun notarytool submit "$NOTARIZE_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> 公証チケットを .app にステープル…"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "==> 配布 zip を組み立て（.app ＋ 説明書）…"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
/usr/bin/ditto "$APP_PATH" "$STAGE/$APP_NAME"
[ -f "$DOC" ] && cp "$DOC" "$STAGE/"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo 0.0)"
OUT_ZIP="$DIST_DIR/TaskCanvas-${VERSION}-signed.zip"
rm -f "$OUT_ZIP"
( cd "$STAGE" && /usr/bin/zip -qr -X "$OLDPWD/$OUT_ZIP" . )

echo
echo "==> 完成: $OUT_ZIP"
echo "    署名・公証済みなので、友達は警告なしでそのまま起動できます。"
echo "    （Google Tasks のテストユーザー追加は従来どおり別途必要）"
