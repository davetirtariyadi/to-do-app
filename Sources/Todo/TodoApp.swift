import AppKit
import SwiftUI
import TodoCore

@main
struct TodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(appDelegate.controller)
                .environmentObject(appDelegate.controller.store)
        } label: {
            MenuLabel()
                .environmentObject(appDelegate.controller.store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller.setUp()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.store.saveNow()
    }
}

/// Menu bar icon with the number of open items on Today.
struct MenuLabel: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let count = store.todayOpen.count
        HStack(spacing: 3) {
            Image(systemName: "checklist")
            if count > 0 { Text("\(count)") }
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject var controller: AppController
    @EnvironmentObject var store: Store

    var body: some View {
        Button("Show Todo   ⌃⌥Space") { controller.show() }
        Button("Add to-do…   ⌃⌥N") { controller.show(.add) }
        Button("Catch up (\(store.catchUpDeck.count))") { controller.show(.catchUp) }
        Divider()
        Toggle("Keep on top", isOn: $controller.pinned)
        Toggle("Launch at login", isOn: Binding(
            get: { controller.launchAtLogin },
            set: { controller.setLaunchAtLogin($0) }
        ))
        Divider()
        Button("Quit Todo") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
