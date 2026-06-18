import SwiftUI

struct MenuBarTasksView: View {
    @EnvironmentObject private var repository: TasksRepository
    @Environment(\.openWindow) private var openWindow

    private func openMainApp() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main-window" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main-window")
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("TaskCanvas")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    Task { await repository.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("更新 (⌘R)")
                .keyboardShortcut("r", modifiers: .command)

                Button {
                    openMainApp()
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("メインウィンドウを開く")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("TaskCanvas を終了")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if let list = repository.primaryList {
                TaskListPanelView(
                    title: list.title,
                    taskRows: repository.visibleTaskRows(in: list.id, includeCompleted: false),
                    hasMoreActiveTasks: repository.hasMoreActiveTasks(in: list.id),
                    isLoadingActiveTasks: repository.isLoadingActiveTasks(in: list.id),
                    completedLoadState: .idle,
                    hasMoreCompletedTasks: false,
                    mode: .menuBar,
                    onToggle: { task in await repository.toggle(task: task) },
                    onAdd: { title in await repository.addTask(title: title, to: list.id) },
                    onAddSubtask: { title, parent in await repository.addTask(title: title, to: list.id, parentID: parent.id) },
                    onDelete: { task in await repository.deleteTask(task) },
                    onLoadMoreActive: { await repository.loadMoreActiveTasks(for: list.id) },
                    onLoadCompleted: nil,
                    onMove: nil,
                    onUpdateTask: nil,
                    onOpenTask: { _ in openMainApp() }
                )
            } else {
                ContentUnavailableView("リストが見つかりません", systemImage: "checklist")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await repository.bootstrap()
        }
        .alert(
            "ログインエラーが発生しました",
            isPresented: .constant(repository.alertError != nil),
            presenting: repository.alertError,
            actions: { error in
                Button("再ログイン") {
                    repository.dismissAlert()
                    openMainApp()
                    Task {
                        await repository.signIn()
                    }
                }
                Button("後で対応") {
                    repository.dismissAlert()
                }
            },
            message: { error in
                Text(error.message)
            }
        )
    }
}
