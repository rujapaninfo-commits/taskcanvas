import SwiftUI
import UniformTypeIdentifiers

struct TaskListPanelView: View {
    @EnvironmentObject private var repository: TasksRepository

    let title: String
    let taskRows: [VisibleTaskRow]
    let hasMoreActiveTasks: Bool
    let isLoadingActiveTasks: Bool
    let completedLoadState: CompletedTasksLoadState
    let hasMoreCompletedTasks: Bool
    let mode: TaskPanelMode
    let onToggle: (TaskItem) async -> Void
    let onAdd: (String) async -> Void
    let onAddSubtask: ((String, TaskItem) async -> Void)?
    let onDelete: ((TaskItem) async -> Void)?
    let onLoadMoreActive: (() async -> Void)?
    let onLoadCompleted: (() async -> Void)?
    let onMove: ((TaskMoveRequest) async -> Void)?
    let onUpdateTask: ((TaskUpdateRequest) async -> Void)?
    let onOpenTask: ((TaskItem) -> Void)?

    @State private var draft = ""
    @State private var draggedTaskID: String?
    @State private var dropPreview: TaskDropPreview?
    @State private var editingTaskID: String?
    @State private var editingTitle = ""
    @State private var editingNotes = ""
    @State private var editingDue: Date? = nil
    @State private var editingDueEnabled = false
    @State private var showCompletedTasks = false
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var addFieldFocused: Bool

    private var supportsReordering: Bool {
        onMove != nil
    }

    private var activeTaskRows: [VisibleTaskRow] {
        taskRows.filter { !$0.task.isCompleted }
    }

    private var completedTaskRows: [VisibleTaskRow] {
        taskRows.filter(\.task.isCompleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if mode == .fullApp && repository.showListTitle {
                header
            }
            addBar
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    renderRows(activeTaskRows)

                    if hasMoreActiveTasks {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .onAppear {
                                Task { await onLoadMoreActive?() }
                            }
                    }

                    if mode == .fullApp && showCompletedTasks && (completedLoadState != .idle || onLoadCompleted != nil) {
                        completedSection
                    }
                }
                .padding(mode == .menuBar ? 8 : 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundStyle)
        .onChange(of: showCompletedTasks) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "showCompletedTasks")
        }
        .onAppear {
            showCompletedTasks = UserDefaults.standard.bool(forKey: "showCompletedTasks")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(mode == .fullApp ? .title3.weight(.semibold) : .headline)
                if repository.showModeDescription {
                    Text(modeDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if mode == .fullApp && !completedTaskRows.isEmpty {
                Button {
                    withAnimation(.snappy(duration: 0.15)) {
                        showCompletedTasks.toggle()
                    }
                } label: {
                    Image(systemName: showCompletedTasks ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(showCompletedTasks ? "完了済みタスクを隠す" : "完了済みタスクを表示")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var addBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Color.accentColor)
                .font(.system(size: mode == .menuBar ? 12 : 14))
            TextField("タスクを追加", text: $draft)
                .textFieldStyle(.plain)
                .font(.caption)
                .focused($addFieldFocused)
                .onSubmit(submit)
            // ⌘N でテキストフィールドにフォーカス
            Button("") { addFieldFocused = true }
                .keyboardShortcut("n", modifiers: .command)
                .hidden()
        }
        .padding(.horizontal, 12)
        .padding(.top, mode == .menuBar ? 6 : 0)
        .padding(.bottom, mode == .menuBar ? 4 : 8)
    }

    private var modeDescription: String {
        switch mode {
        case .widget:
            "ウィジェット向け表示"
        case .menuBar:
            "メニューバー向け表示"
        case .fullApp:
            "通常アプリ表示"
        }
    }

    private var backgroundStyle: some ShapeStyle {
        if mode == .fullApp {
            return AnyShapeStyle(.background)
        }
        return AnyShapeStyle(.regularMaterial)
    }

    private func submit() {
        let title = draft
        draft = ""
        Task { await onAdd(title) }
    }
    private func beginEditing(_ task: TaskItem) {
        guard mode == .fullApp, onUpdateTask != nil else { return }
        editingTaskID = task.id
        editingTitle = task.title
        editingNotes = task.notes ?? ""
        editingDue = task.due
        editingDueEnabled = task.due != nil
        titleFieldFocused = true
    }

    private func cancelEditing() {
        editingTaskID = nil
        editingTitle = ""
        editingNotes = ""
        editingDue = nil
        editingDueEnabled = false
        titleFieldFocused = false
    }

    private func saveEditing(task: TaskItem) {
        guard let onUpdateTask else { return }
        let request = TaskUpdateRequest(
            taskID: task.id,
            title: editingTitle,
            notes: editingNotes,
            due: editingDueEnabled ? (editingDue ?? Date()) : nil
        )
        cancelEditing()
        Task {
            await onUpdateTask(request)
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        if mode == .fullApp {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .padding(.top, 6)

                switch completedLoadState {
                case .idle:
                    Button {
                        Task { await onLoadCompleted?() }
                    } label: {
                        HStack(spacing: 10) {
                            Text("完了済みを読み込む")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                        }
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                case .loading:
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("完了済みを読み込み中...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                case .loaded:
                    Text("完了 (\(completedTaskRows.count)件)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    renderRows(completedTaskRows)

                    if hasMoreCompletedTasks {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .onAppear {
                                Task { await onLoadCompleted?() }
                            }
                    }
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func renderRows(_ rows: [VisibleTaskRow]) -> some View {
        ForEach(rows) { row in
            TaskRowView(
                task: row.task,
                depth: row.depth,
                compact: mode != .fullApp,
                dropPreview: dropPreview?.taskID == row.task.id ? dropPreview?.style : nil,
                supportsDragging: supportsReordering,
                isEditingInline: mode == .fullApp && editingTaskID == row.task.id && onUpdateTask != nil,
                editingTitle: $editingTitle,
                editingNotes: $editingNotes,
                editingDue: $editingDue,
                editingDueEnabled: $editingDueEnabled,
                titleFieldFocused: _titleFieldFocused,
                onOpenTask: {
                    onOpenTask?(row.task)
                },
                onBeginInlineEdit: {
                    beginEditing(row.task)
                },
                onCancelInlineEdit: {
                    cancelEditing()
                },
                onSaveInlineEdit: {
                    saveEditing(task: row.task)
                }
            ) {
                await onToggle(row.task)
            }
            .modifier(
                TaskRowReorderModifier(
                    enabled: supportsReordering && editingTaskID == nil,
                    row: row,
                    compact: mode != .fullApp,
                    draggedTaskID: $draggedTaskID,
                    dropPreview: $dropPreview,
                    performMove: { request in
                        guard let onMove else { return }
                        await onMove(request)
                    }
                )
            )
            .onAppear {
                guard mode == .fullApp else { return }
                if row.task.isCompleted, hasMoreCompletedTasks, row.id == completedTaskRows.last?.id {
                    Task { await onLoadCompleted?() }
                } else if !row.task.isCompleted, hasMoreActiveTasks, row.id == activeTaskRows.last?.id {
                    Task { await onLoadMoreActive?() }
                }
            }
            .contextMenu {
                if let onAddSubtask {
                    Button {
                        Task { await onAddSubtask("新しいサブタスク", row.task) }
                    } label: {
                        Label("サブタスクを追加", systemImage: "plus.circle")
                    }
                }
                if let onDelete {
                    Divider()
                    Button(role: .destructive) {
                        Task { await onDelete(row.task) }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
    }
}

private struct TaskRowReorderModifier: ViewModifier {
    let enabled: Bool
    let row: VisibleTaskRow
    let compact: Bool
    @Binding var draggedTaskID: String?
    @Binding var dropPreview: TaskDropPreview?
    let performMove: (TaskMoveRequest) async -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    draggedTaskID = row.task.id
                    return NSItemProvider(object: row.task.id as NSString)
                }
                .onDrop(
                    of: [UTType.plainText],
                    delegate: TaskDropDelegate(
                        row: row,
                        draggedTaskID: $draggedTaskID,
                        dropPreview: $dropPreview,
                        supportsChildDrop: true,
                        compact: compact,
                        performMove: performMove
                    )
                )
        } else {
            content
        }
    }
}

private struct TaskRowView: View {
    @EnvironmentObject private var repository: TasksRepository

    let task: TaskItem
    let depth: Int
    let compact: Bool
    let dropPreview: TaskDropPreview.Style?
    let supportsDragging: Bool
    let isEditingInline: Bool
    @Binding var editingTitle: String
    @Binding var editingNotes: String
    @Binding var editingDue: Date?
    @Binding var editingDueEnabled: Bool
    @FocusState var titleFieldFocused: Bool
    let onOpenTask: (() -> Void)?
    let onBeginInlineEdit: () -> Void
    let onCancelInlineEdit: () -> Void
    let onSaveInlineEdit: () -> Void
    let onToggle: () async -> Void

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 6 : 10) {
            Button {
                Task { await onToggle() }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 13 : 17))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: compact ? 1 : 3) {
                if isEditingInline {
                    TextField("タイトル", text: $editingTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFieldFocused)
                        .onSubmit {
                            onSaveInlineEdit()
                        }
                        .onAppear {
                            titleFieldFocused = true
                        }
                    TextField("メモ（任意）", text: $editingNotes)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    HStack(spacing: 8) {
                        Toggle("期限", isOn: $editingDueEnabled)
                            .toggleStyle(.checkbox)
                            .font(.caption)
                        if editingDueEnabled {
                            DatePicker("", selection: Binding(
                                get: { editingDue ?? Date() },
                                set: { editingDue = $0 }
                            ), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .font(.caption)
                        }
                    }
                } else {
                    Text(task.title)
                        .font(.system(size: compact ? min(repository.taskFontSize, 13) : repository.taskFontSize, weight: compact ? .regular : .medium))
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if compact {
                                onOpenTask?()
                            } else {
                                onBeginInlineEdit()
                            }
                        }
                }
                if let notes = task.notes, !notes.isEmpty, !compact, !isEditingInline {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let due = task.due, !isEditingInline {
                    DueDateBadge(due: due, isCompleted: task.isCompleted, compact: compact)
                }
            }
            Spacer(minLength: 0)

            if isEditingInline {
                HStack(spacing: 8) {
                    Button("キャンセル") {
                        onCancelInlineEdit()
                    }
                    .buttonStyle(.borderless)
                    Button("保存") {
                        onSaveInlineEdit()
                    }
                    .buttonStyle(.borderless)
                    .disabled(editingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .font(.caption)
            }
        }
        .padding(.leading, CGFloat(depth) * 18)
        .padding(.vertical, compact ? 2 : 3)
        .padding(.horizontal, 6)
        .background(backgroundOverlay)
        .overlay(alignment: .bottomLeading) {
            if dropPreview == .insertAfter, supportsDragging {
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(height: 2)
                    .padding(.leading, CGFloat(depth) * 18 + 8)
                    .padding(.trailing, 8)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 2, y: 1)
            }
        }
        .overlay(alignment: .topLeading) {
            if dropPreview == .insertBefore, supportsDragging {
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(height: 2)
                    .padding(.leading, CGFloat(depth) * 18 + 8)
                    .padding(.trailing, 8)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 2, y: 1)
            }
        }
    }

    @ViewBuilder
    private var backgroundOverlay: some View {
        if dropPreview == .makeChild, supportsDragging {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
        } else if (dropPreview == .insertAfter || dropPreview == .insertBefore), supportsDragging {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.04))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.clear)
        }
    }
}

private struct TaskDropDelegate: DropDelegate {
    let row: VisibleTaskRow
    @Binding var draggedTaskID: String?
    @Binding var dropPreview: TaskDropPreview?
    let supportsChildDrop: Bool
    let compact: Bool
    let performMove: (TaskMoveRequest) async -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTaskID, draggedTaskID != row.task.id else {
            self.draggedTaskID = nil
            dropPreview = nil
            return false
        }

        let placement = previewStyle(for: info, compact: compact)
        let request = TaskMoveRequest(
            sourceTaskID: draggedTaskID,
            targetTaskID: row.task.id,
            placement: placement.requestPlacement
        )
        self.draggedTaskID = nil
        dropPreview = nil
        Task {
            await performMove(request)
        }
        return true
    }

    func dropExited(info: DropInfo) {
        if dropPreview?.taskID == row.task.id {
            dropPreview = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let draggedTaskID, draggedTaskID != row.task.id else {
            dropPreview = nil
            return DropProposal(operation: .move)
        }
        dropPreview = TaskDropPreview(taskID: row.task.id, style: previewStyle(for: info, compact: compact))
        return DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggedTaskID, draggedTaskID != row.task.id else { return }
        dropPreview = TaskDropPreview(taskID: row.task.id, style: previewStyle(for: info, compact: compact))
    }

    private func previewStyle(for info: DropInfo, compact: Bool) -> TaskDropPreview.Style {
        let rowHeight: CGFloat = compact ? 32 : 44
        let insertionZoneHeight = max(14, rowHeight * 0.32)
        if info.location.y < insertionZoneHeight {
            return .insertBefore
        }
        if info.location.y > rowHeight - insertionZoneHeight {
            return .insertAfter
        }
        return supportsChildDrop ? .makeChild : .insertAfter
    }
}

private struct TaskDropPreview: Equatable {
    enum Style: Equatable {
        case insertBefore
        case insertAfter
        case makeChild

        var requestPlacement: TaskMoveRequest.Placement {
            switch self {
            case .insertBefore:
                return .before
            case .insertAfter:
                return .after
            case .makeChild:
                return .makeChild
            }
        }
    }

    let taskID: String
    let style: Style
}

private struct DueDateBadge: View {
    let due: Date
    let isCompleted: Bool
    let compact: Bool

    private var isOverdue: Bool {
        !isCompleted && due < Calendar.current.startOfDay(for: .now)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(due)
    }

    private var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(due)
    }

    private var label: String {
        if isToday { return "今日" }
        if isTomorrow { return "明日" }
        return due.formatted(date: .abbreviated, time: .omitted)
    }

    private var color: Color {
        if isCompleted { return .secondary }
        if isOverdue { return .red }
        if isToday { return .orange }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "calendar")
            Text(label)
        }
        .font(compact ? .caption2 : .caption)
        .foregroundStyle(color)
    }
}
