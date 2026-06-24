# TaskCanvas App Review response — 2026-06-24

## App Store Connect で修正するメタデータ

- Subtitle: `タスクをすばやく整理`
- 旧文言に含まれていた `Mac` / `Google ToDo` への言及は削除する。
- スクリーンショット説明文も、可能ならブランド名を含まない新しい画像に差し替える。

## Review Notes / App Review 返信文

Hello App Review Team,

Thank you for reviewing TaskCanvas. We have addressed the issues in the submitted update.

1. Guideline 5.2.5 / 4.1(c)
We revised the app metadata to remove wording that could be confused with Apple products or third-party product names. The subtitle no longer references Apple product terms or “Google ToDo.”

2. Guideline 2.1
We added an in-app review demo mode so the reviewer can access the app’s main functionality without signing in. Please open TaskCanvas, go to Settings, and choose “デモモードを開始” in the “レビュー用デモ” section. The demo mode shows sample task lists and allows the reviewer to test adding, editing, completing, deleting, nesting, and reordering tasks. It does not connect to any external server.

3. Guideline 2.4.5(i)
TaskCanvas uses the `com.apple.security.network.server` entitlement only for the OAuth loopback redirect required during Google sign-in. When the user chooses Google sign-in, the app starts a temporary local TCP listener with `NWListener` on `127.0.0.1` and an ephemeral port, then opens the browser for OAuth. The listener receives only the local redirect callback at `/oauth2callback`, completes the OAuth code exchange, and is immediately cancelled. The app does not expose any user-facing server, remote network service, or long-running listener. This entitlement is required for the app’s sign-in flow to function in the macOS sandbox.

We uploaded build 2 with the demo mode and related changes.

Thank you.
