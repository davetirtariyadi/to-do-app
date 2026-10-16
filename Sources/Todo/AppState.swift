import Foundation

enum Screen: Equatable {
    case home, add, view, list, catchUp, groups
}

enum ListTab: String, CaseIterable {
    case today, all, board

    var label: String {
        switch self {
        case .today: return "Today"
        case .all: return "All"
        case .board: return "Board"
        }
    }

    var key: String {
        switch self {
        case .today: return "1"
        case .all: return "2"
        case .board: return "3"
        }
    }
}

/// Navigation and transient UI state shared by every screen in the window.
final class AppState: ObservableObject {
    @Published private(set) var screen: Screen = .home
    @Published var listTab: ListTab = .today
    /// Which Home option is highlighted (0 Add, 1 Catch up, 2 View).
    @Published var homeIndex = 0
    @Published private(set) var toast: String?
    /// Bumped whenever the window is shown, so the visible screen re-grabs keyboard focus.
    @Published private(set) var focusTick = 0
    /// Bumped when Esc reaches the window without a view handling it (e.g. from inside a text field).
    @Published private(set) var escapeTick = 0

    private var toastClear: DispatchWorkItem?

    func go(_ s: Screen) {
        screen = s
    }

    func goHome(highlight index: Int? = nil) {
        if let index { homeIndex = index }
        screen = .home
    }

    func openList(_ tab: ListTab) {
        listTab = tab
        screen = .list
    }

    func showToast(_ message: String) {
        toast = message
        toastClear?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastClear = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: work)
    }

    func requestFocus() { focusTick += 1 }
    func escapePressed() { escapeTick += 1 }
}
