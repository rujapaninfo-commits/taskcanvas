import SwiftUI

struct MainShellView: View {
    @EnvironmentObject private var repository: TasksRepository
    @State private var selectedListID: String?
    @State private var showsExpandedSidebar = false

    private func selectNextList() {
        guard let currentID = selectedListID,
              let currentIndex = repository.taskLists.firstIndex(where: { $0.id == currentID }),
              currentIndex + 1 < repository.taskLists.count else { return }
        selectedListID = repository.taskLists[currentIndex + 1].id
    }

    private func selectPreviousList() {
        guard let currentID = selectedListID,
              let currentIndex = repository.taskLists.firstIndex(where: { $0.id == currentID }),
              currentIndex > 0 else { return }
        selectedListID = repository.taskLists[currentIndex - 1].id
    }

    var body: some View {
        HSplitView {
            NavigationStack {
                SidebarView(
                    selectedListID: $selectedListID,
                    showsExpandedSidebar: $showsExpandedSidebar
                )
            }
            .frame(
                minWidth: showsExpandedSidebar ? 90 : 45,
                idealWidth: showsExpandedSidebar ? 100 : 45,
                maxWidth: showsExpandedSidebar ? 130 : 45
            )

            MainTaskColumnView(
                selectedListID: selectedListID,
                onPrimaryInteraction: collapseSidebar
            )
        }
        .onKeyPress(.downArrow, phases: .down) { press in
            if press.modifiers.contains(.command) {
                selectNextList()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow, phases: .down) { press in
            if press.modifiers.contains(.command) {
                selectPreviousList()
                return .handled
            }
            return .ignored
        }
        .onAppear {
            showsExpandedSidebar = false
        }
        .task {
            await repository.bootstrap()
            if selectedListID == nil {
                selectedListID = repository.taskLists.first?.id
            }
        }
        .onChange(of: repository.taskLists) { _, taskLists in
            if let selectedListID, taskLists.contains(where: { $0.id == selectedListID }) {
                return
            }
            self.selectedListID = taskLists.first?.id
        }
        .onChange(of: selectedListID) { _, newValue in
            if newValue == nil {
                selectedListID = repository.taskLists.first?.id
            }
        }
        .alert(
            "ログインエラーが発生しました",
            isPresented: .constant(repository.alertError != nil),
            presenting: repository.alertError,
            actions: { error in
                Button("再ログイン") {
                    repository.dismissAlert()
                    Task {
                        let didSignIn = await repository.signIn()
                        if !didSignIn {
                            // Keep showing the error if sign in failed
                        }
                    }
                }
                Button("後で対応") {
                    repository.dismissAlert()
                }
                Button("キャンセル", role: .cancel) {
                    repository.dismissAlert()
                }
            },
            message: { error in
                Text(error.message)
            }
        )
    }

    private func collapseSidebar() {
        guard showsExpandedSidebar else { return }
        withAnimation(.snappy(duration: 0.18)) {
            showsExpandedSidebar = false
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var repository: TasksRepository
    @Binding var selectedListID: String?
    @Binding var showsExpandedSidebar: Bool

    var body: some View {
        List(selection: $selectedListID) {
            Section("Lists") {
                ForEach(repository.taskLists) { list in
                    HStack(spacing: 4) {
                        if showsExpandedSidebar {
                            Text(list.title)
                                .font(.caption)
                                .lineLimit(1)
                        } else {
                            Text(list.title.prefix(1))
                                .font(.caption2)
                                .frame(width: 16, alignment: .center)
                        }
                        Spacer()
                        if showsExpandedSidebar {
                            Text("\(repository.totalTaskCount(in: list.id))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(Optional(list.id))
                    .contentShape(Rectangle())
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Google ToDo")
        .toolbar {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    showsExpandedSidebar.toggle()
                }
            } label: {
                Label(
                    showsExpandedSidebar ? "リストをたたむ" : "リストを広げる",
                    systemImage: showsExpandedSidebar ? "sidebar.leading" : "sidebar.left"
                )
            }

            Button {
                Task { await repository.refresh() }
            } label: {
                Label("更新", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)

            SettingsLink {
                Label("設定", systemImage: "gearshape")
            }
        }
    }
}

private struct MainTaskColumnView: View {
    @EnvironmentObject private var repository: TasksRepository
    let selectedListID: String?
    let onPrimaryInteraction: () -> Void

    var body: some View {
        Group {
            if let selectedListID, let taskList = repository.taskList(id: selectedListID) {
                TaskListPanelView(
                    title: taskList.title,
                    taskRows: repository.visibleTaskRows(in: selectedListID, includeCompleted: true),
                    hasMoreActiveTasks: repository.hasMoreActiveTasks(in: selectedListID),
                    isLoadingActiveTasks: repository.isLoadingActiveTasks(in: selectedListID),
                    completedLoadState: repository.completedLoadState(in: selectedListID),
                    hasMoreCompletedTasks: repository.hasMoreCompletedTasks(in: selectedListID),
                    mode: .fullApp,
                    onToggle: { task in await repository.toggle(task: task) },
                    onAdd: { title in await repository.addTask(title: title, to: selectedListID) },
                    onAddSubtask: { title, parent in await repository.addTask(title: title, to: selectedListID, parentID: parent.id) },
                    onDelete: { task in await repository.deleteTask(task) },
                    onLoadMoreActive: { await repository.loadMoreActiveTasks(for: selectedListID) },
                    onLoadCompleted: { await repository.loadCompletedTasks(for: selectedListID) },
                    onMove: { request in await repository.moveTask(request, in: selectedListID) },
                    onUpdateTask: { request in
                        await repository.updateTask(request, in: selectedListID)
                    },
                    onOpenTask: nil
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onPrimaryInteraction()
                }
            } else {
                if repository.taskLists.isEmpty {
                    ContentUnavailableView {
                        Label("タスクをまだ読み込めていません", systemImage: "checklist")
                    } description: {
                        Text(repository.statusMessage)
                    } actions: {
                        SettingsLink {
                            Label("設定を開く", systemImage: "gearshape")
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "リストを選んでください",
                        systemImage: "rectangle.stack",
                        description: Text("左のサイドバーから Google ToDo のリストを選んでください。")
                    )
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
