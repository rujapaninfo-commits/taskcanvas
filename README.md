# TaskCanvas

macOS 向けの Google Tasks クライアントです。

3つの表示モードを前提にしています。

- `ウィジェット`: 表示中心
- `メニューバー`: 追加と完了チェック中心
- `通常アプリ`: 並べ替え、詳細確認、設定

## いま入っているもの

- SwiftUI ベースの macOS アプリ
- `MenuBarExtra` ベースのメニューバー UI
- WidgetKit 拡張
- Google OAuth / Tasks API の接続土台
- ウィジェットとアプリで共有する簡易キャッシュ

## まだ必要なもの

- Xcode を有効にした環境
- Google Cloud で作成した OAuth Client ID
- App Group / Signing 設定

## セットアップ

1. `xcodegen generate`
2. `TaskCanvas.xcodeproj` を Xcode で開く
3. Signing と App Group を調整する
4. アプリの `Settings` から OAuth Client ID を入力する

## 補足

この作業環境ではフル Xcode が有効化されていなかったため、ここではプロジェクト生成とソース作成までを行っています。
