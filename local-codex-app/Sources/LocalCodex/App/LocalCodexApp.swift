import AppKit
import SwiftUI

@main
struct LocalCodexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 1180, minHeight: 740)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Project") {
                Button("Open Project...") {
                    NotificationCenter.default.post(name: .openProjectRequested, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(store: store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
