#!/bin/bash
# TaskCanvas — 配布の準備状況チェック（doctor）
#
# Apple Developer Program で署名・公証・配布するのに必要なものが揃っているかを点検し、
# 足りないものは「直すコマンド」を出す。配布ビルドの前に走らせる。
#
# 使い方:  scripts/check-signing-setup.sh
set -uo pipefail

TEAM_ID="49BW44PPG7"
NOTARY_PROFILE="${NOTARY_PROFILE:-taskcanvas-notary}"
ok=0; ng=0
say_ok()   { printf "  ✅ %s\n" "$1"; ok=$((ok+1)); }
say_ng()   { printf "  ❌ %s\n" "$1"; ng=$((ng+1)); }
say_note() { printf "  ℹ️  %s\n" "$1"; }
say_fix()  { printf "       → %s\n" "$1"; }

echo "===== TaskCanvas 配布準備チェック ====="
echo "Team ID: $TEAM_ID / notary profile: $NOTARY_PROFILE"
echo

echo "[1] ビルドツール"
# full Xcode が選択されているか
XSEL="$(xcode-select -p 2>/dev/null || true)"
if echo "$XSEL" | grep -q "Xcode.app"; then
  say_ok "xcode-select は full Xcode を指している ($XSEL)"
else
  say_ng "xcode-select が full Xcode を指していない ($XSEL)"
  if [ -d /Applications/Xcode.app ]; then
    say_fix "sudo xcode-select -s /Applications/Xcode.app   (Xcode.app は存在)"
  else
    say_fix "App Store から Xcode をインストール後、sudo xcode-select -s /Applications/Xcode.app"
  fi
fi
# xcodebuild
if xcodebuild -version >/dev/null 2>&1; then
  say_ok "xcodebuild 利用可 ($(xcodebuild -version 2>/dev/null | head -1))"
else
  say_ng "xcodebuild が使えない（上の xcode-select を直すと解決することが多い）"
fi
# xcodegen
if command -v xcodegen >/dev/null 2>&1; then
  say_ok "xcodegen 利用可 ($(xcodegen --version 2>/dev/null))"
else
  say_ng "xcodegen が無い"
  say_fix "brew install xcodegen"
fi
# Xcode ライセンス承認（未承認だと notarytool/clang が exit 69 で全部弾かれる）
if xcrun clang --version >/dev/null 2>&1; then
  say_ok "Xcode ライセンス承認済み"
else
  say_ng "Xcode ライセンス未承認（これがあると notarytool/ビルドが全部止まる）"
  say_fix "sudo xcodebuild -license accept   （続けて sudo xcodebuild -runFirstLaunch）"
fi
# notarytool
if xcrun notarytool --help >/dev/null 2>&1; then
  say_ok "notarytool 利用可"
else
  say_ng "notarytool が使えない（full Xcode 選択＋ライセンス承認が必要）"
fi
echo

echo "[2] 署名証明書"
IDS="$(security find-identity -v -p codesigning 2>/dev/null)"
if echo "$IDS" | grep -q "Developer ID Application"; then
  say_ok "Developer ID Application 証明書あり（直接配布・公証用）"
else
  say_ng "Developer ID Application 証明書が無い"
  say_fix "Xcode > Settings > Accounts > Apple ID > Manage Certificates > + > Developer ID Application"
fi
if echo "$IDS" | grep -qi "Apple Distribution\|3rd Party Mac"; then
  say_ok "App Store 用の配布証明書あり"
else
  say_note "Apple Distribution のローカル identity は無し（Automatic signing の Xcode-managed 証明書で App Store export 可）"
fi
echo

echo "[3] 公証の認証情報（notarytool）"
# プロファイルの存在は直接照会できないので、軽い疎通で判定（ネットに出る）
if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  say_ok "notary keychain profile '$NOTARY_PROFILE' が使える"
else
  say_ng "notary keychain profile '$NOTARY_PROFILE' が未設定 or 認証失敗"
  say_fix "xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <ID> --team-id $TEAM_ID --password <app専用pw>"
  say_fix "app専用pw は appleid.apple.com > サインインとセキュリティ > App用パスワード で発行"
fi
echo

echo "===== 結果: OK $ok 件 / 要対応 $ng 件 ====="
if [ "$ng" -eq 0 ]; then
  echo "✅ 全部そろっています。配布ビルド可能:"
  echo "   - 直接配布（警告ゼロ）: scripts/dist-developer-id.sh"
  echo "   - App Store 提出      : scripts/submit-appstore.sh"
else
  echo "上の ❌ を順に潰してください。詳細手順は Obsidian:"
  echo "   Knowledge/apple-developer-program-distribution.md"
fi
