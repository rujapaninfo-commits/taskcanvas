import Foundation

struct GoogleTasksAPI {
    enum FetchScope {
        case activeOnly
        case all
    }

    struct TaskPage {
        let tasks: [TaskItem]
        let nextPageToken: String?
    }

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchTaskLists(accessToken: String) async throws -> [TaskList] {
        let url = URL(string: "https://www.googleapis.com/tasks/v1/users/@me/lists")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let data = try await perform(request)
        let response = try JSONDecoder.google.decode(TaskListsResponse.self, from: data)
        return response.items.compactMap {
            guard let id = $0.id else { return nil }
            return TaskList(id: id, title: $0.title ?? "Untitled List", updated: $0.updated)
        }
    }

    func fetchTaskPage(
        taskListID: String,
        accessToken: String,
        scope: FetchScope = .activeOnly,
        pageToken: String? = nil,
        pageSize: Int = 20
    ) async throws -> TaskPage {
        var components = URLComponents(string: "https://www.googleapis.com/tasks/v1/lists/\(taskListID)/tasks")!
        var queryItems: [URLQueryItem] = [.init(name: "maxResults", value: "\(pageSize)")]
        if scope == .all {
            queryItems.append(.init(name: "showCompleted", value: "true"))
            queryItems.append(.init(name: "showHidden", value: "true"))
        }
        if let pageToken {
            queryItems.append(.init(name: "pageToken", value: pageToken))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let data = try await perform(request)
        let response = try JSONDecoder.google.decode(TasksResponse.self, from: data)

        let tasks: [TaskItem] = response.items.compactMap { item in
            guard let id = item.id else { return nil }
            return TaskItem(
                id: id,
                taskListID: taskListID,
                title: item.title ?? "Untitled Task",
                notes: item.notes,
                status: item.status ?? .needsAction,
                parentID: item.parent,
                position: item.position,
                due: item.due
            )
        }

        let filteredTasks = scope == .all ? tasks : tasks.filter { !$0.isCompleted }
        return TaskPage(tasks: filteredTasks, nextPageToken: response.nextPageToken)
    }

    func addTask(title: String, taskListID: String, parentID: String? = nil, accessToken: String) async throws {
        var components = URLComponents(string: "https://www.googleapis.com/tasks/v1/lists/\(taskListID)/tasks")!
        if let parentID {
            components.queryItems = [URLQueryItem(name: "parent", value: parentID)]
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CreateTaskRequest(title: title))
        _ = try await perform(request)
    }

    func updateTaskStatus(task: TaskItem, accessToken: String) async throws {
        let url = URL(string: "https://www.googleapis.com/tasks/v1/lists/\(task.taskListID)/tasks/\(task.id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let nextStatus: TaskStatus = task.isCompleted ? .needsAction : .completed
        request.httpBody = try JSONEncoder.google.encode(UpdateTaskRequest(status: nextStatus))
        _ = try await perform(request)
    }

    func updateTask(
        taskID: String,
        taskListID: String,
        title: String,
        notes: String?,
        due: Date?,
        accessToken: String
    ) async throws {
        let url = URL(string: "https://www.googleapis.com/tasks/v1/lists/\(taskListID)/tasks/\(taskID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.google.encode(
            UpdateTaskDetailsRequest(
                title: title,
                notes: notes,
                due: due
            )
        )
        _ = try await perform(request)
    }

    func deleteTask(taskID: String, taskListID: String, accessToken: String) async throws {
        let url = URL(string: "https://www.googleapis.com/tasks/v1/lists/\(taskListID)/tasks/\(taskID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try await perform(request)
    }

    func moveTask(
        taskID: String,
        taskListID: String,
        parentID: String?,
        previousID: String?,
        accessToken: String
    ) async throws {
        var components = URLComponents(string: "https://www.googleapis.com/tasks/v1/lists/\(taskListID)/tasks/\(taskID)/move")!
        var queryItems: [URLQueryItem] = []
        if let parentID {
            queryItems.append(URLQueryItem(name: "parent", value: parentID))
        }
        if let previousID {
            queryItems.append(URLQueryItem(name: "previous", value: previousID))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return data
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let googleError = try? JSONDecoder().decode(GoogleAPIErrorResponse.self, from: data)
            throw GoogleTasksAPIError(
                statusCode: httpResponse.statusCode,
                message: googleError?.error.message ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
        return data
    }
}

private struct TaskListsResponse: Decodable {
    let items: [TaskListPayload]

    private enum CodingKeys: String, CodingKey {
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let payloads = try container.decodeIfPresent([FailableDecodable<TaskListPayload>].self, forKey: .items) ?? []
        items = payloads.compactMap(\.value)
    }
}

private struct TaskListPayload: Decodable {
    let id: String?
    let title: String?
    let updated: Date?
}

private struct TasksResponse: Decodable {
    let items: [TaskPayload]
    let nextPageToken: String?

    private enum CodingKeys: String, CodingKey {
        case items
        case nextPageToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let payloads = try container.decodeIfPresent([FailableDecodable<TaskPayload>].self, forKey: .items) ?? []
        items = payloads.compactMap(\.value)
        nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
    }
}

private struct TaskPayload: Decodable {
    let id: String?
    let title: String?
    let notes: String?
    let status: TaskStatus?
    let parent: String?
    let position: String?
    let due: Date?
}

private struct CreateTaskRequest: Encodable {
    let title: String
}

private struct UpdateTaskRequest: Encodable {
    let status: TaskStatus
}

private struct UpdateTaskDetailsRequest: Encodable {
    let title: String
    let notes: String?
    let due: Date?
}

private struct GoogleAPIErrorResponse: Decodable {
    let error: GoogleAPIErrorPayload
}

private struct GoogleAPIErrorPayload: Decodable {
    let message: String
}

struct GoogleTasksAPIError: LocalizedError {
    let statusCode: Int
    let message: String

    var errorDescription: String? {
        "Google Tasks API error (\(statusCode)): \(message)"
    }
}

private struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

private extension JSONDecoder {
    static let google: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: string) { return date }
            let withoutFractional = ISO8601DateFormatter()
            withoutFractional.formatOptions = [.withInternetDateTime]
            if let date = withoutFractional.date(from: string) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: container.codingPath, debugDescription: "Cannot parse date: \(string)")
            )
        }
        return decoder
    }()
}

private extension JSONEncoder {
    static let google: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
