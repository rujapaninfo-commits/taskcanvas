import SwiftUI
import WidgetKit

@main
struct TaskCanvasWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskCanvasWidget()
    }
}

struct TaskCanvasEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TaskCanvasProvider: TimelineProvider {
    private let store = SharedStore()

    func placeholder(in context: Context) -> TaskCanvasEntry {
        TaskCanvasEntry(date: .now, snapshot: sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskCanvasEntry) -> Void) {
        let snapshot = context.isPreview ? sampleSnapshot : store.loadSnapshot()
        completion(TaskCanvasEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskCanvasEntry>) -> Void) {
        let entry = TaskCanvasEntry(date: .now, snapshot: store.loadSnapshot())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private var sampleSnapshot: WidgetSnapshot {
        WidgetSnapshot(
            updatedAt: .now,
            lists: [TaskList(id: "sample", title: "My Tasks", updated: .now)],
            tasksByListID: [
                "sample": [
                    TaskItem(id: "1", taskListID: "sample", title: "Review inbox", notes: nil, status: .needsAction, parentID: nil, position: "0001", due: nil),
                    TaskItem(id: "2", taskListID: "sample", title: "Confirm subtasks", notes: nil, status: .needsAction, parentID: "1", position: "0002", due: nil),
                    TaskItem(id: "3", taskListID: "sample", title: "Ship menu bar mode", notes: nil, status: .needsAction, parentID: nil, position: "0003", due: nil)
                ]
            ]
        )
    }
}

struct TaskCanvasWidgetEntryView: View {
    var entry: TaskCanvasProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let targetList = entry.snapshot.lists.first(where: { $0.id == entry.snapshot.widgetListID })
            ?? entry.snapshot.lists.first
        if let list = targetList {
            WidgetListView(
                title: list.title,
                tasks: TaskTreeBuilder.visibleTasks(from: entry.snapshot.tasksByListID[list.id] ?? [], treeView: true),
                family: family
            )
            .widgetURL(URL(string: "taskcanvas://open"))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("TaskCanvas")
                    .font(.headline)
                Text("アプリでログインすると、ここにタスクが表示されます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "taskcanvas://open"))
        }
    }
}

private struct WidgetListView: View {
    let title: String
    let tasks: [TaskItem]
    let family: WidgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(titleFont)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(tasks.count)件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(tasks.prefix(maxVisibleCount))) { task in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(iconFont)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    Text(task.title)
                        .font(rowFont)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.leading, task.parentID == nil ? 0 : indentWidth)
            }

            if tasks.count > maxVisibleCount {
                Text("他 \(tasks.count - maxVisibleCount) 件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var maxVisibleCount: Int {
        switch family {
        case .systemSmall:
            return 3
        case .systemMedium:
            return 6
        case .systemLarge:
            return 10
        default:
            return 6
        }
    }

    private var titleFont: Font {
        switch family {
        case .systemSmall:
            return .subheadline.weight(.semibold)
        case .systemMedium:
            return .headline
        case .systemLarge:
            return .title3.weight(.semibold)
        default:
            return .headline
        }
    }

    private var rowFont: Font {
        switch family {
        case .systemSmall:
            return .caption
        case .systemMedium:
            return .subheadline
        case .systemLarge:
            return .body
        default:
            return .subheadline
        }
    }

    private var iconFont: Font {
        switch family {
        case .systemSmall:
            return .caption
        case .systemMedium:
            return .footnote
        case .systemLarge:
            return .subheadline
        default:
            return .footnote
        }
    }

    private var rowSpacing: CGFloat {
        switch family {
        case .systemSmall:
            return 6
        case .systemMedium:
            return 8
        case .systemLarge:
            return 10
        default:
            return 8
        }
    }

    private var indentWidth: CGFloat {
        switch family {
        case .systemSmall:
            return 10
        case .systemMedium:
            return 14
        case .systemLarge:
            return 18
        default:
            return 14
        }
    }
}

struct TaskCanvasWidget: Widget {
    let kind: String = "TaskCanvasWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskCanvasProvider()) { entry in
            TaskCanvasWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TaskCanvas")
        .description("サイズに応じた件数で、上からタスクを表示します。クリックすると本体アプリを開きます。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
