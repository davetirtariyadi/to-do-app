import AppKit
import Carbon
import ServiceManagement
import SwiftUI
import TodoCore

/// Owns the store, the window and the global shortcuts.
final class AppController: ObservableObject {
    static let windowSize = NSSize(width: 400, height: 308)

    let store: Store
    let state = AppState()
    private var panel: FloatingPanel?

    @Published var pinned: Bool {
        didSet {
            UserDefaults.standard.set(pinned, forKey: "pinned")
            panel?.setPinned(pinned)
        }
    }

    @Published private(set) var launchAtLogin: Bool

    init() {
        // TODO_DATA_FILE lets the dev harness run against scratch data.
        let override = ProcessInfo.processInfo.environment["TODO_DATA_FILE"]
        store = Store(url: override.map { URL(fileURLWithPath: $0) } ?? Store.defaultURL())
        pinned = UserDefaults.standard.object(forKey: "pinned") as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setUp() {
        let panel = FloatingPanel(size: Self.windowSize)
        let root = RootView()
            .environmentObject(self)
            .environmentObject(store)
            .environmentObject(state)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: Self.windowSize)
        host.wantsLayer = true
        host.layer?.cornerRadius = 12
        host.layer?.masksToBounds = true
        panel.contentView = host
        panel.setPinned(pinned)
        panel.onEscape = { [weak self] in self?.handleEscape() }
        if !panel.setFrameUsingName("TodoPanel") { panel.placeDefault() }
        panel.setFrameAutosaveName("TodoPanel")
        self.panel = panel

        // ⌃⌥Space shows/hides, ⌃⌥N jumps straight to Add.
        HotKeyCenter.shared.register(keyCode: kVK_Space, modifiers: controlKey | optionKey) { [weak self] in
            self?.toggle()
        }
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_N, modifiers: controlKey | optionKey) { [weak self] in
            self?.show(.add)
        }

        show()
        DevHarness.runIfRequested(controller: self, window: panel)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(_ screen: Screen? = nil) {
        guard let panel else { return }
        if let screen { state.go(screen) }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        state.requestFocus()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        guard let panel else { return }
        if panel.isVisible && panel.isKeyWindow { hide() } else { show() }
    }

    /// Esc that no view consumed: the Add screen decides for itself (it may
    /// just close a picker); elsewhere go home, and on Home hide the window.
    func handleEscape() {
        switch state.screen {
        case .add: state.escapePressed()
        case .home: hide()
        case .view: state.goHome(highlight: 2)
        case .list: state.goHome(highlight: 2)
        case .catchUp: state.goHome(highlight: 1)
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Todo: launch at login change failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// Switches between the screens inside the fixed-size window.
struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            switch state.screen {
            case .home: HomeView()
            case .add: AddView()
            case .view: ViewPickerView()
            case .list: ListsView()
            case .catchUp: CatchUpView()
            }
        }
        .frame(width: AppController.windowSize.width, height: AppController.windowSize.height)
        .background(Theme.ground)
        .foregroundStyle(Theme.ink)
        .environment(\.colorScheme, .light)
    }
}
