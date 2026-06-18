import Foundation

struct TaskList: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let updated: Date?
}

struct TaskItem: Codable, Identifiable, Hashable {
    let id: String
    let taskListID: String
    var title: String
    var notes: String?
    var status: TaskStatus
    var parentID: String?
    var position: String?
    var due: Date?

    var isCompleted: Bool { status == .completed }
}

enum TaskStatus: String, Codable {
    case needsAction
    case completed
}

struct OAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiryDate: Date?
}

struct WidgetSnapshot: Codable {
    let updatedAt: Date
    let lists: [TaskList]
    let tasksByListID: [String: [TaskItem]]
    var widgetListID: String?

    static let empty = WidgetSnapshot(updatedAt: .now, lists: [], tasksByListID: [:], widgetListID: nil)
}

struct VisibleTaskRow: Identifiable, Hashable {
    let task: TaskItem
    let depth: Int

    var id: String { task.id }
}

struct TaskMoveRequest: Hashable {
    enum Placement: Hashable {
        case before
        case after
        case makeChild
    }

    let sourceTaskID: String
    let targetTaskID: String
    let placement: Placement
}

struct TaskUpdateRequest: Hashable {
    let taskID: String
    let title: String
    let notes: String
    var due: Date?
}

enum TaskPanelMode {
    case widget
    case menuBar
    case fullApp
}

enum CompletedTasksLoadState: Equatable {
    case idle
    case loading
    case loaded
}
