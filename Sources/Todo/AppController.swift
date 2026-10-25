import AppKit
import Carbon
import ServiceManagement
import SwiftUI
import TodoCore

/// Owns the store, the window and the global shortcuts.
final class AppController: ObservableObject {
    static let windowSize = NSSize(width: 400, height: 360)

    let store: Store
    let state = AppState()
    private var panel: FloatingPanel?

    @Published var pinned: Bool {
        didSet {
            UserDefaults.standard.set(pinned, forKey: "pinned")
            panel?.setPinned(pinned)
        }
    }

    @Published var appearance: Appearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appearance")
            NSApp.appearance = appearance.nsAppearance
        }
    }

    @Published private(set) var launchAtLogin: Bool

    init() {
        // TODO_DATA_FILE lets the dev harness run against scratch data.
        let override = ProcessInfo.processInfo.environment["TODO_DATA_FILE"]
        store = Store(url: override.map { URL(fileURLWithPath: $0) } ?? Store.defaultURL())
        pinned = UserDefaults.standard.object(forKey: "pinned") as? Bool ?? true
        appearance = UserDefaults.standard.string(forKey: "appearance").flatMap(Appearance.init) ?? .system
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setUp() {
        NSApp.appearance = appearance.nsAppearance
        let panel = FloatingPanel(size: Self.windowSize)
        let root = RootView()
            .environmentObject(self)
            .environmentObject(store)
            .environmentObject(state)
        let host = NSHostingView(rootView: root)
        host.wantsLayer = true
        host.layer?.cornerRadius = 12
        host.layer?.masksToBounds = true
        panel.contentView = host
        panel.setPinned(pinned)
        panel.onEscape = { [weak self] in self?.handleEscape() }
        if !panel.setFrameUsingName("TodoPanel") { panel.placeDefault() }
        // A frame saved before the panel grew would stay 308pt and clip the new row.
        var frame = panel.frame
        frame.size = Self.windowSize
        panel.setFrame(frame, display: false)
        host.frame = NSRect(origin: .zero, size: Self.windowSize)
        panel.setFrameAutosaveName("TodoPanel")
        self.panel = panel

        // ⌃⌘Space shows/hides, ⌃⌥N jumps straight to Add, ⌃⌥B to Brain dump.
        HotKeyCenter.shared.register(keyCode: kVK_Space, modifiers: controlKey | cmdKey) { [weak self] in
            self?.toggle()
        }
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_N, modifiers: controlKey | optionKey) { [weak self] in
            self?.show(.add)
        }
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_B, modifiers: controlKey | optionKey) { [weak self] in
            self?.show(.dump)
        }

        show()
        DevHarness.runIfRequested(controller: self, window: panel)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(_ screen: Screen? = nil) {
        guard let panel else { return }
        if screen == .add {
            state.openAdd()
        } else if let screen {
            state.go(screen)
        }
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

    /// Esc that no view consumed: Add, Groups, lists and Notes decide for
    /// themselves (they may just close a picker or cancel an edit); elsewhere
    /// go home, and on Home hide the window.
    func handleEscape() {
        switch state.screen {
        case .add, .groups, .list, .notes: state.escapePressed()
        case .home: hide()
        case .view: state.goHome(highlight: 3)
        case .catchUp: state.goHome(highlight: 2)
        case .dump: state.goHome(highlight: 1)
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
            case .groups: GroupsView()
            case .dump: DumpView()
            case .notes: NotesView()
            }
        }
        .frame(width: AppController.windowSize.width, height: AppController.windowSize.height)
        .background(Theme.ground)
        .foregroundStyle(Theme.ink)
    }
}
