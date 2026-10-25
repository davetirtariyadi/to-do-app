import Foundation
import TodoCore

enum Screen: Equatable {
    case home, add, view, list, catchUp, groups, dump, notes
}

/// A note opened in Add. It is deleted only after the to-do is saved.
struct AddDraft: Equatable {
    var title: String
    var noteID: UUID
    var returnTo: Screen
}

/// One answer on the notes pass of Catch up. A promotion is not undoable.
enum NoteReviewStep {
    case keep
    case delete(Note)
    case promote
}

/// The notes deck, held while Add is open so Catch up can resume on the way back.
struct NoteReview {
    var deck: [UUID]
    var index: Int
    var keptCount: Int
    var promotedCount: Int
    var promotingID: UUID
    var steps: [NoteReviewStep]
    var snapshots: [UUID: Note]
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
    /// Which Home option is highlighted (0 Add, 1 Brain dump, 2 Catch up, 3 View).
    @Published var homeIndex = 0
    @Published private(set) var toast: String?
    /// Set only when Add was opened from a note. A normal add leaves this nil.
    private(set) var addDraft: AddDraft?
    /// Set only while a notes card is open in Add. Catch up reads it on the way back.
    private(set) var noteReview: NoteReview?
    /// Bumped whenever the window is shown, so the visible screen re-grabs keyboard focus.
    @Published private(set) var focusTick = 0
    /// Bumped when Esc reaches the window without a view handling it (e.g. from inside a text field).
    @Published private(set) var escapeTick = 0

    private var toastClear: DispatchWorkItem?

    func go(_ s: Screen) {
        if s != .catchUp { noteReview = nil }
        screen = s
    }

    /// Opens Add. Pass a draft to turn a note into a to-do; otherwise this is a normal add.
    /// A review stashed for Catch up survives only when Add will return there.
    func openAdd(draft: AddDraft? = nil) {
        if draft?.returnTo != .catchUp { noteReview = nil }
        addDraft = draft
        screen = .add
    }

    func stashNoteReview(_ review: NoteReview) {
        noteReview = review
    }

    func takeNoteReview() -> NoteReview? {
        defer { noteReview = nil }
        return noteReview
    }

    func consumeAddDraft() -> AddDraft? {
        defer { addDraft = nil }
        return addDraft
    }

    func goHome(highlight index: Int? = nil) {
        noteReview = nil
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
