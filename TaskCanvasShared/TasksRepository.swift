import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class TasksRepository: ObservableObject {
    @Published private(set) var taskLists: [TaskList] = []
    @Published private(set) var tasksByListID: [String: [TaskItem]] = [:]
    @Published private(set) var completedTasksByListID: [String: [TaskItem]] = [:]
    @Published private(set) var completedLoadStateByListID: [String: CompletedTasksLoadState] = [:]
    @Published private(set) var visibleTaskRowsByListID: [String: [VisibleTaskRow]] = [:]
    @Published private(set) var statusMessage = "設定の入力を待っています"
    @Published var alertError: (title: String, message: String)? = nil
    @Published var fontSizeLevel: Int {
        didSet { store.saveFontSizeLevel(fontSizeLevel) }
    }
    @Published var showModeDescription: Bool {
        didSet { store.saveShowModeDescription(showModeDescription) }
    }
    @Published var showListTitle: Bool {
        didSet { store.saveShowListTitle(showListTitle) }
    }

    private let store: SharedStore
    private let authService: GoogleOAuthService
    private let api: GoogleTasksAPI
    private var didBootstrap = false
    private var activeNextPageTokenByListID: [String: String] = [:]
    private var activeExhaustedListIDs = Set<String>()
    private var activeLoadingListIDs = Set<String>()
    private var completedNextPageTokenByListID: [String: String] = [:]
    private var completedExhaustedListIDs = Set<String>()
    private var widgetReloadTask: Task<Void, Never>?

    var oauthClientID: String { store.loadOAuthClientID() }
    var primaryList: TaskList? { taskLists.first }
    var oauthDebugSummary: String { authService.debugConfigurationSummary }
    var isSignedIn: Bool { authService.loadTokens() != nil }

    var widgetListID: String? {
        get { store.loadWidgetListID() ?? taskLists.first?.id }
        set { store.saveWidgetListID(newValue); scheduleWidgetReload() }
    }
    var widgetList: TaskList? { taskLists.first(where: { $0.id == widgetListID }) ?? taskLists.first }

    var taskFontSize: CGFloat {
        let scale: [CGFloat] = [0.8, 0.9, 1.0, 1.1, 1.2]
        let clampedLevel = max(0, min(fontSizeLevel, scale.count - 1))
        return 13 * scale[clampedLevel]
    }

    static func live() -> TasksRepository {
        let store = SharedStore()
        return TasksRepository(
            store: store,
            authService: GoogleOAuthService(store: store),
            api: GoogleTasksAPI()
        )
    }

    init(store: SharedStore, authService: GoogleOAuthService, api: GoogleTasksAPI) {
        self.store = store
        self.authService = authService
        self.api = api
        self.fontSizeLevel = store.loadFontSizeLevel()
        self.showModeDescription = store.loadShowModeDescription()
        self.showListTitle = store.loadShowListTitle()
        hydrateFromCache()
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        if authService.loadTokens() != nil {
            await refresh()
        } else {
            statusMessage = oauthClientID.isEmpty ? "設定画面で OAuth Client ID を入力してください。" : "Google にログインするとタスクを読み込めます。"
        }
    }

    func signIn() async -> Bool {
        do {
            statusMessage = "Google にログインしています..."
            let tokens = try await authService.signIn()
            didBootstrap = true
            statusMessage = "ログインできました。タスクを更新しています..."
            try await refresh(using: tokens)
            return true
        } catch {
            let errorMessage = error.localizedDescription
            statusMessage = errorMessage
            alertError = (title: "ログインエラー", message: errorMessage)
            return false
        }
    }

    func signOut() {
        authService.signOut()
        taskLists = []
        tasksByListID = [:]
        completedTasksByListID = [:]
        completedLoadStateByListID = [:]
        visibleTaskRowsByListID = [:]
        activeNextPageTokenByListID = [:]
        activeExhaustedListIDs = []
        activeLoadingListIDs = []
        completedNextPageTokenByListID = [:]
        completedExhaustedListIDs = []
        persistSnapshot()
        statusMessage = "ログアウトしました"
    }

    func refresh() async {
        do {
            statusMessage = "タスクを更新しています..."
            guard let tokens = try await refreshTokenWithRetry() else {
                statusMessage = "Google にログインするとタスクを取得できます。"
                return
            }
            try await refresh(using: tokens)
        } catch {
            let errorMessage = error.localizedDescription
            statusMessage = errorMessage
            alertError = (title: "ログインエラー", message: errorMessage)
        }
    }

    func loadCompletedTasks(for listID: String) async {
        guard completedLoadStateByListID[listID] != .loading else { return }

        do {
            completedLoadStateByListID[listID] = .loading
            statusMessage = "完了済みタスクを読み込んでいます..."
            guard let tokens = try await refreshTokenWithRetry() else {
                completedLoadStateByListID[listID] = .idle
                return
            }

            var collected = completedTasksByListID[listID] ?? []
            var nextPageToken = completedNextPageTokenByListID[listID]
            var exhausted = completedExhaustedListIDs.contains(listID)
            let targetIncrease = collected.count + 20

            while collected.count < targetIncrease && !exhausted {
                let page = try await api.fetchTaskPage(
                    taskListID: listID,
                    accessToken: tokens.accessToken,
                    scope: .all,
                    pageToken: nextPageToken,
                    pageSize: 20
                )

                collected.append(contentsOf: page.tasks.filter(\.isCompleted))
                if let token = page.nextPageToken {
                    nextPageToken = token
                    completedNextPageTokenByListID[listID] = token
                } else {
                    nextPageToken = nil
                    completedNextPageTokenByListID.removeValue(forKey: listID)
                    completedExhaustedListIDs.insert(listID)
                    exhausted = true
                }
            }

            completedTasksByListID[listID] = collected
            completedLoadStateByListID[listID] = .loaded
            rebuildVisibleTaskRowCache()
            statusMessage = "完了済みタスクを読み込みました。"
        } catch {
            completedLoadStateByListID[listID] = .idle
            statusMessage = error.localizedDescription
        }
    }

    func loadMoreActiveTasks(for listID: String) async {
        guard !activeLoadingListIDs.contains(listID), !activeExhaustedListIDs.contains(listID) else { return }

        do {
            activeLoadingListIDs.insert(listID)
            defer { activeLoadingListIDs.remove(listID) }

            guard let tokens = try await refreshTokenWithRetry() else { return }
            let page = try await api.fetchTaskPage(
                taskListID: listID,
                accessToken: tokens.accessToken,
                scope: .activeOnly,
                pageToken: activeNextPageTokenByListID[listID],
                pageSize: 20
            )

            var current = tasksByListID[listID] ?? []
            current.append(contentsOf: page.tasks.filter { task in
                !current.contains(where: { $0.id == task.id })
            })
            tasksByListID[listID] = current

            if let token = page.nextPageToken {
                activeNextPageTokenByListID[listID] = token
            } else {
                activeNextPageTokenByListID.removeValue(forKey: listID)
                activeExhaustedListIDs.insert(listID)
            }

            rebuildVisibleTaskRowCache()
        } catch {
            statusMessage = error.localizedDescription
            alertError = (title: "タスク読み込みエラー", message: error.localizedDescription)
        }
    }

    func toggle(task: TaskItem) async {
        // Optimistic: flip status immediately in local state
        applyLocalTaskUpdate(taskID: task.id, listID: task.taskListID) { $0.status = $0.isCompleted ? .needsAction : .completed }
        do {
            guard let tokens = try await refreshTokenWithRetry() else { return }
            try await api.updateTaskStatus(task: task, accessToken: tokens.accessToken)
            await refreshList(task.taskListID, using: tokens)
        } catch {
            // Rollback: revert the optimistic change
            applyLocalTaskUpdate(taskID: task.id, listID: task.taskListID) { $0.status = task.status }
            statusMessage = error.localizedDescription
            alertError = (title: "ステータス更新エラー", message: error.localizedDescription)
        }
    }

    func addTask(title: String, to listID: String, parentID: String? = nil) async {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        do {
            guard let tokens = try await refreshTokenWithRetry() else { return }
            try await api.addTask(title: cleaned, taskListID: listID, parentID: parentID, accessToken: tokens.accessToken)
            await refreshList(listID, using: tokens)
        } catch {
            statusMessage = error.localizedDescription
            alertError = (title: "タスク追加エラー", message: error.localizedDescription)
        }
    }

    func deleteTask(_ task: TaskItem) async {
        // Optimistic: remove from local state immediately
        removeLocalTask(taskID: task.id, listID: task.taskListID)
        do {
            guard let tokens = try await refreshTokenWithRetry() else { return }
            try await api.deleteTask(taskID: task.id, taskListID: task.taskListID, accessToken: tokens.accessToken)
        } catch {
            // Rollback: re-add the task
            var tasks = tasksByListID[task.taskListID] ?? []
            tasks.append(task)
            tasksByListID[task.taskListID] = tasks
            rebuildVisibleTaskRowCache()
            statusMessage = error.localizedDescription
            alertError = (title: "タスク削除エラー", message: error.localizedDescription)
        }
    }

    func updateTask(_ request: TaskUpdateRequest, in listID: String) async {
        let cleanedTitle = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else {
            statusMessage = "タイトルは空にできません。"
            return
        }

        let cleanedNotes = request.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes: String? = cleanedNotes.isEmpty ? nil : cleanedNotes

        // Snapshot for rollback
        let original = tasksByListID[listID]?.first(where: { $0.id == request.taskID })

        // Optimistic update
        applyLocalTaskUpdate(taskID: request.taskID, listID: listID) {
            $0.title = cleanedTitle
            $0.notes = notes
            $0.due = request.due
        }

        do {
            guard let tokens = try await refreshTokenWithRetry() else { return }
            try await api.updateTask(
                taskID: request.taskID,
                taskListID: listID,
                title: cleanedTitle,
                notes: notes,
                due: request.due,
                accessToken: tokens.accessToken
            )
            statusMessage = "タスクを更新しました。"
        } catch {
            // Rollback
            if let original {
                applyLocalTaskUpdate(taskID: request.taskID, listID: listID) {
                    $0.title = original.title
                    $0.notes = original.notes
                    $0.due = original.due
                }
            }
            statusMessage = error.localizedDescription
            alertError = (title: "タスク更新エラー", message: error.localizedDescription)
        }
    }

    func visibleTasks(in listID: String, includeCompleted: Bool = true) -> [TaskItem] {
        if includeCompleted {
            return visibleTaskRowsByListID[listID, default: []].map(\.task)
        }

        return TaskTreeBuilder.visibleTasks(
            from: tasksByListID[listID] ?? [],
            treeView: true,
            includeCompleted: false
        )
    }

    func visibleTaskRows(in listID: String, includeCompleted: Bool = true) -> [VisibleTaskRow] {
        if includeCompleted {
            return visibleTaskRowsByListID[listID, default: []]
        }

        return TaskTreeBuilder.visibleTaskRows(
            from: tasksByListID[listID] ?? [],
            treeView: true,
            includeCompleted: false
        )
    }

    func totalTaskCount(in listID: String) -> Int {
        let activeCount = tasksByListID[listID]?.count ?? 0
        let completedCount = completedTasksByListID[listID]?.count ?? 0
        return activeCount + completedCount
    }

    func completedLoadState(in listID: String) -> CompletedTasksLoadState {
        completedLoadStateByListID[listID] ?? .idle
    }

    func hasMoreActiveTasks(in listID: String) -> Bool {
        !activeExhaustedListIDs.contains(listID)
    }

    func isLoadingActiveTasks(in listID: String) -> Bool {
        activeLoadingListIDs.contains(listID)
    }

    func hasMoreCompletedTasks(in listID: String) -> Bool {
        !completedExhaustedListIDs.contains(listID)
    }

    func isLoadingCompletedTasks(in listID: String) -> Bool {
        completedLoadState(in: listID) == .loading
    }

    func taskList(id: String) -> TaskList? {
        taskLists.first(where: { $0.id == id })
    }

    func moveTask(_ request: TaskMoveRequest, in listID: String) async {
        do {
            guard let tokens = try await refreshTokenWithRetry() else { return }
            guard
                let tasks = tasksByListID[listID],
                let sourceTask = tasks.first(where: { $0.id == request.sourceTaskID }),
                let targetTask = tasks.first(where: { $0.id == request.targetTaskID })
            else {
                return
            }

            let descendantIDs = TaskTreeBuilder.descendantIDs(of: sourceTask.id, in: tasks)
            guard sourceTask.id != targetTask.id, !descendantIDs.contains(targetTask.id) else {
                return
            }

            let parentID: String?
            let previousID: String?

            switch request.placement {
            case .makeChild:
                let targetChildren = TaskTreeBuilder
                    .ordered(tasks.filter { $0.parentID == targetTask.id && $0.id != sourceTask.id })
                parentID = targetTask.id
                previousID = targetChildren.last?.id
            case .after:
                parentID = targetTask.parentID
                previousID = targetTask.id
            case .before:
                let siblings = TaskTreeBuilder.ordered(
                    tasks.filter { $0.parentID == targetTask.parentID && $0.id != sourceTask.id }
                )
                let previousSibling = sibling(before: targetTask.id, in: siblings)
                parentID = targetTask.parentID
                previousID = previousSibling?.id
            }

            try await api.moveTask(
                taskID: sourceTask.id,
                taskListID: listID,
                parentID: parentID,
                previousID: previousID,
                accessToken: tokens.accessToken
            )
            await refresh()
        } catch {
            statusMessage = error.localizedDescription
            alertError = (title: "タスク移動エラー", message: error.localizedDescription)
        }
    }

    private func sibling(before targetID: String, in siblings: [TaskItem]) -> TaskItem? {
        guard let index = siblings.firstIndex(where: { $0.id == targetID }), index > 0 else {
            return nil
        }
        return siblings[index - 1]
    }

    private func refresh(using tokens: OAuthTokens) async throws {
        let lists = try await api.fetchTaskLists(accessToken: tokens.accessToken)
        var taskMap: [String: [TaskItem]] = [:]
        for list in lists {
            let page = try await api.fetchTaskPage(
                taskListID: list.id,
                accessToken: tokens.accessToken,
                scope: .activeOnly,
                pageToken: nil,
                pageSize: 20
            )
            taskMap[list.id] = page.tasks
            if let token = page.nextPageToken {
                activeNextPageTokenByListID[list.id] = token
                activeExhaustedListIDs.remove(list.id)
            } else {
                activeNextPageTokenByListID.removeValue(forKey: list.id)
                activeExhaustedListIDs.insert(list.id)
            }
        }

        taskLists = lists
        tasksByListID = taskMap
        completedTasksByListID = completedTasksByListID.filter { taskMap.keys.contains($0.key) }
        completedLoadStateByListID = completedLoadStateByListID.filter { taskMap.keys.contains($0.key) }
        activeLoadingListIDs = []
        activeNextPageTokenByListID = activeNextPageTokenByListID.filter { taskMap.keys.contains($0.key) }
        activeExhaustedListIDs = Set(activeExhaustedListIDs.filter { taskMap.keys.contains($0) })
        completedNextPageTokenByListID = completedNextPageTokenByListID.filter { taskMap.keys.contains($0.key) }
        completedExhaustedListIDs = Set(completedExhaustedListIDs.filter { taskMap.keys.contains($0) })
        rebuildVisibleTaskRowCache()
        persistSnapshot()
        if lists.isEmpty {
            statusMessage = "Google ToDo のリストがまだ見つかりません。"
        } else {
            statusMessage = "最終更新: \(Date.now.formatted(date: .omitted, time: .shortened))"
        }
    }

    private func hydrateFromCache() {
        let snapshot = store.loadSnapshot()
        taskLists = snapshot.lists
        tasksByListID = snapshot.tasksByListID.mapValues { $0.filter { !$0.isCompleted } }
        completedTasksByListID = [:]
        completedLoadStateByListID = [:]
        activeNextPageTokenByListID = [:]
        activeExhaustedListIDs = []
        activeLoadingListIDs = []
        completedNextPageTokenByListID = [:]
        completedExhaustedListIDs = []
        rebuildVisibleTaskRowCache()
        if snapshot.lists.isEmpty {
            statusMessage = "まだ保存済みのタスクはありません"
        } else {
            statusMessage = "前回の保存内容を読み込みました"
        }
    }

    private func refreshList(_ listID: String, using tokens: OAuthTokens) async {
        do {
            let page = try await api.fetchTaskPage(
                taskListID: listID,
                accessToken: tokens.accessToken,
                scope: .activeOnly,
                pageToken: nil,
                pageSize: 20
            )
            tasksByListID[listID] = page.tasks
            if let token = page.nextPageToken {
                activeNextPageTokenByListID[listID] = token
                activeExhaustedListIDs.remove(listID)
            } else {
                activeNextPageTokenByListID.removeValue(forKey: listID)
                activeExhaustedListIDs.insert(listID)
            }
            completedTasksByListID.removeValue(forKey: listID)
            completedLoadStateByListID.removeValue(forKey: listID)
            rebuildVisibleTaskRowCache()
            persistSnapshot()
            statusMessage = "最終更新: \(Date.now.formatted(date: .omitted, time: .shortened))"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func applyLocalTaskUpdate(taskID: String, listID: String, mutation: (inout TaskItem) -> Void) {
        guard var tasks = tasksByListID[listID],
              let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        mutation(&tasks[index])
        tasksByListID[listID] = tasks
        rebuildVisibleTaskRowCache()
    }

    private func removeLocalTask(taskID: String, listID: String) {
        guard var tasks = tasksByListID[listID] else { return }
        tasks.removeAll { $0.id == taskID }
        tasksByListID[listID] = tasks
        rebuildVisibleTaskRowCache()
    }

    private func rebuildVisibleTaskRowCache() {
        visibleTaskRowsByListID = taskLists.reduce(into: [String: [VisibleTaskRow]]()) { partialResult, list in
            let activeTasks = tasksByListID[list.id] ?? []
            let completedTasks = completedTasksByListID[list.id] ?? []
            partialResult[list.id] = TaskTreeBuilder.visibleTaskRows(
                from: activeTasks + completedTasks,
                treeView: true,
                includeCompleted: true
            )
        }
    }

    private func persistSnapshot() {
        store.saveSnapshot(
            WidgetSnapshot(
                updatedAt: .now,
                lists: taskLists,
                tasksByListID: tasksByListID,
                widgetListID: store.loadWidgetListID()
            )
        )
        scheduleWidgetReload()
    }

    private func scheduleWidgetReload() {
        widgetReloadTask?.cancel()
        widgetReloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadTimelines(ofKind: "TaskCanvasWidget")
            self?.widgetReloadTask = nil
        }
    }

    func dismissAlert() {
        alertError = nil
    }

    // MARK: - Private Helper Methods

    private func refreshTokenWithRetry(maxAttempts: Int = 3) async throws -> OAuthTokens? {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await authService.refreshIfNeeded()
            } catch {
                lastError = error
                guard attempt < maxAttempts else { break }
                // Wait before retrying (exponential backoff: 500ms, 1s)
                try await Task.sleep(for: .milliseconds(500 * UInt64(attempt)))
            }
        }
        if let lastError {
            throw lastError
        }
        return nil
    }
}
