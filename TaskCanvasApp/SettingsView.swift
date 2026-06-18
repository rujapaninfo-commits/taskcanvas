import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var repository: TasksRepository
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section("Google ログイン設定") {
                HStack(spacing: 8) {
                    Image(systemName: repository.isSignedIn ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(repository.isSignedIn ? .green : .secondary)
                    Text(repository.isSignedIn ? "ログイン中" : "未ログイン")
                        .foregroundStyle(repository.isSignedIn ? .primary : .secondary)
                }
                Text("Google アカウントでログインすると、そのまま Google Tasks を同期できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Google にログイン") {
                        Task {
                            let didSignIn = await repository.signIn()
                            guard didSignIn else { return }
                            openWindow(id: "main-window")
                            NSApplication.shared.activate(ignoringOtherApps: true)
                        }
                    }
                    .disabled(repository.isSignedIn)
                    Button("再ログイン") {
                        repository.dismissAlert()
                        Task {
                            let didSignIn = await repository.signIn()
                            guard didSignIn else { return }
                            openWindow(id: "main-window")
                            NSApplication.shared.activate(ignoringOtherApps: true)
                        }
                    }
                    .disabled(!repository.isSignedIn)
                    Button("ログアウト") {
                        repository.signOut()
                    }
                    .disabled(!repository.isSignedIn)
                }
            }

            Section("表示設定") {
                Picker("フォントサイズ", selection: $repository.fontSizeLevel) {
                    Text("小 (80%)").tag(0)
                    Text("中小 (90%)").tag(1)
                    Text("通常 (100%)").tag(2)
                    Text("中大 (110%)").tag(3)
                    Text("大 (120%)").tag(4)
                }
                .pickerStyle(.menu)

                Toggle("リスト名を表示", isOn: $repository.showListTitle)
                Toggle("モード説明を表示", isOn: $repository.showModeDescription)

                LabeledContent("サブタスク表示") {
                    Text("ツリー表示で常に表示")
                }
                LabeledContent("並び順") {
                    Text("Google の表示順を優先")
                }
                LabeledContent("メニューバー") {
                    Text("追加と完了チェック中心")
                }
            }

            if !repository.taskLists.isEmpty {
                Section("ウィジェット") {
                    Picker("表示するリスト", selection: Binding(
                        get: { repository.widgetListID ?? repository.taskLists.first?.id ?? "" },
                        set: { repository.widgetListID = $0 }
                    )) {
                        ForEach(repository.taskLists) { list in
                            Text(list.title).tag(list.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section("バージョン") {
                HStack {
                    Text("TaskCanvas")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }

            Section("状態") {
                Text(repository.statusMessage)
                    .foregroundStyle(.secondary)
                Text(repository.oauthDebugSummary)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    private var appVersion: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(shortVersion) (build \(buildVersion))"
    }
}
