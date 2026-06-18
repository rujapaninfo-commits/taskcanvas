import Foundation

enum TaskTreeBuilder {
    static func visibleTaskRows(
        from tasks: [TaskItem],
        treeView: Bool = true,
        includeCompleted: Bool = true
    ) -> [VisibleTaskRow] {
        let filtered = ordered(tasks.filter { includeCompleted || !$0.isCompleted })
        guard treeView else {
            return filtered.map { VisibleTaskRow(task: $0, depth: 0) }
        }

        let childrenByParent = Dictionary(grouping: filtered.filter { $0.parentID != nil }) { task in
            task.parentID ?? ""
        }

        func appendRows(for parentID: String?, depth: Int) -> [VisibleTaskRow] {
            let children = ordered(
                filtered.filter { task in
                    if let parentID {
                        return task.parentID == parentID
                    }
                    return task.parentID == nil
                }
            )

            return children.flatMap { task in
                [VisibleTaskRow(task: task, depth: depth)] + appendChildRows(of: task.id, depth: depth + 1, childrenByParent: childrenByParent)
            }
        }

        return appendRows(for: nil, depth: 0)
    }

    static func visibleTasks(
        from tasks: [TaskItem],
        treeView: Bool = true,
        includeCompleted: Bool = true
    ) -> [TaskItem] {
        visibleTaskRows(from: tasks, treeView: treeView, includeCompleted: includeCompleted).map(\.task)
    }

    static func descendantIDs(of taskID: String, in tasks: [TaskItem]) -> Set<String> {
        let childrenByParent = Dictionary(grouping: tasks.filter { $0.parentID != nil }) { task in
            task.parentID ?? ""
        }
        var descendants = Set<String>()
        var stack = childrenByParent[taskID, default: []].map(\.id)

        while let current = stack.popLast() {
            guard descendants.insert(current).inserted else { continue }
            stack.append(contentsOf: childrenByParent[current, default: []].map(\.id))
        }

        return descendants
    }

    static func ordered(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted(by: isOrderedBefore)
    }

    private static func appendChildRows(
        of parentID: String,
        depth: Int,
        childrenByParent: [String: [TaskItem]]
    ) -> [VisibleTaskRow] {
        ordered(childrenByParent[parentID] ?? []).flatMap { child in
            [VisibleTaskRow(task: child, depth: depth)] + appendChildRows(of: child.id, depth: depth + 1, childrenByParent: childrenByParent)
        }
    }

    private static func isOrderedBefore(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        switch (lhs.position, rhs.position) {
        case let (l?, r?) where l != r:
            return l < r
        default:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
