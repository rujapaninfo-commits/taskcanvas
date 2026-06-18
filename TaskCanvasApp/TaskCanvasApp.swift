import SwiftUI

@main
struct TaskCanvasApp: App {
    @StateObject private var repository = TasksRepository.live()

    var body: some Scene {
        Window("TaskCanvas", id: "main-window") {
            MainShellView()
                .environmentObject(repository)
                .frame(minWidth: 280, minHeight: 380)
        }
        .defaultSize(width: 420, height: 580)
        .handlesExternalEvents(matching: ["open"])

        MenuBarExtra("TaskCanvas", systemImage: "checklist.checked") {
            MenuBarTasksView()
                .environmentObject(repository)
                .frame(width: 208, height: 360)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(repository)
                .frame(width: 620, height: 480)
        }
    }
}
