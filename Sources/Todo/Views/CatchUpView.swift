import SwiftUI
import TodoCore

/// A stack of cards. The deck is fixed when a pass starts, so answering
/// doesn't reshuffle it.
///
/// To-dos: → or swipe right is done, ← or swipe left is not done.
/// Notes: → opens Add with the text filled in, ← keeps the note, ⌫ deletes it.
/// Z undoes. Answered cards stay in the view, parked off to the side they
/// were sent, so answering and undoing are both just a change of `index`.
struct CatchUpView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store

    private enum Deck: String, CaseIterable, Identifiable {
        case todos, notes

        var id: String { rawValue }

        var label: String { self == .todos ? "To-dos" : "Notes" }
        var key: String { self == .todos ? "1" : "2" }
    }

    @Local private var mode: Deck = .todos
    @Local private var deck: [UUID] = []
    @Local private var index = 0
    @Local private var doneCount = 0
    @Local private var keptCount = 0
    @Local private var history: [(id: UUID, wasDone: Bool, markedDone: Bool)] = []
    @Local private var noteSteps: [NoteReviewStep] = []
    @Local private var noteSnapshots: [UUID: Note] = [:]
    @Local private var started = false
    @Local private var dragX: CGFloat = 0

    private static let fling = Animation.spring(response: 0.36, dampingFraction: 0.82)
    /// How far a drag has to travel before letting go answers the card.
    private static let swipeThreshold: CGFloat = 100
    /// Resting tilt of the top card and the two peeking behind it.
    private static let tilts: [Double] = [0, -2.2, 1.8]

    private var active: Bool { index < deck.count }
    private var finished: Bool { !deck.isEmpty && index >= deck.count }
    private var canUndo: Bool {
        if mode == .notes {
            guard let last = noteSteps.last else { return false }
            if case .promote = last { return false }
            return true
        }
        return !history.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(onBack: leave) {
                HStack(spacing: 2) {
                    ForEach(Deck.allCases) { deck in
                        let on = deck == mode
                        Button { switchMode(deck) } label: {
                            HStack(spacing: 5) {
                                Text(deck.label).font(.system(size: 12.5, weight: .medium))
                                Text(deck.key).font(Theme.mono(10.5)).foregroundStyle(Theme.muted)
                            }
                            .foregroundStyle(on ? Theme.ink : Theme.ink2)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(on ? Theme.surface : .clear)
                                    .shadow(color: .black.opacity(on ? 0.12 : 0), radius: 1, y: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.segment))
            } trailing: {
                if active {
                    Text("\(index + 1) of \(deck.count)")
                        .font(Theme.mono(11.5))
                        .foregroundStyle(Theme.muted)
                        .padding(.trailing, 6)
                }
            }

            if !started {
                Spacer()
            } else if active {
                cardScreen
            } else if finished {
                finishedScreen
            } else {
                emptyScreen
            }
        }
        .grabsFocus()
        .onKeyPress(phases: .down) { handle($0) }
        .onAppear {
            if !started { begin() }
        }
    }

    private var cardScreen: some View {
        VStack(spacing: 9) {
            ProgressBar(fraction: Double(index) / Double(max(deck.count, 1)), height: 3)

            cardStack
                .padding(.horizontal, 6)
                .padding(.top, 2)
                .padding(.bottom, 18)
                .zIndex(1)

            HStack(spacing: 8) {
                if mode == .notes {
                    answerButton("Keep", key: "←", filled: false, action: keepNote)
                    answerButton("To-do", key: "→", filled: true, action: promoteNote)
                } else {
                    answerButton("Not done", key: "←", filled: false) { answer(done: false) }
                    answerButton("Done", key: "→", filled: true) { answer(done: true) }
                }
            }

            HStack {
                Button(action: undo) {
                    Text("Z undo").font(Theme.mono(11))
                        .foregroundStyle(canUndo ? Theme.ink2 : Theme.disabled)
                }
                .buttonStyle(.plain)
                .disabled(!canUndo)
                Spacer()
                Text(progressLine)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.muted)
            }
            .frame(height: 18)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var progressLine: String {
        if mode == .notes {
            return "\(doneCount) to-dos · \(keptCount) kept · Esc home"
        }
        return "\(doneCount) done · \(keptCount) open · Esc home"
    }

    /// The last two answered cards (parked off screen, so undo can fly them
    /// back), the current card, and three behind it. Only two of those peek out.
    private var cardStack: some View {
        let range = max(0, index - 2)..<min(deck.count, index + 4)
        return ZStack {
            ForEach(range, id: \.self) { pos in
                if mode == .notes, let note = noteForCard(deck[pos]) {
                    stackCard(at: pos, wentRight: noteWentRight(pos)) { noteFace(note) }
                } else if mode == .todos, let item = store.item(deck[pos]) {
                    stackCard(at: pos, wentRight: pos < history.count && history[pos].markedDone) {
                        cardFace(item)
                    }
                }
            }
        }
    }

    private func stackCard<Face: View>(at pos: Int, wentRight: Bool, @ViewBuilder face: () -> Face) -> some View {
        let depth = pos - index
        var x: CGFloat = 0, y: CGFloat = 0, angle = 0.0, scale: CGFloat = 1, opacity = 1.0
        // -1…1: how far toward the left or right answer the card has been pushed.
        var lean: CGFloat = 0
        if depth < 0 {
            let dir: CGFloat = wentRight ? 1 : -1
            x = dir * 460; y = -20; angle = Double(dir) * 24; opacity = 0; lean = dir
        } else if depth == 0 {
            x = dragX; angle = Double(dragX / 200 * 12)
            lean = max(-1, min(1, dragX / 90))
        } else {
            let d = min(depth, 2)
            y = CGFloat(d) * 11; scale = 1 - CGFloat(d) * 0.04; angle = Self.tilts[d]
            opacity = depth > 2 ? 0 : 1
        }
        let rightLabel = mode == .notes ? "To-do" : "Done"
        let leftLabel = mode == .notes ? "Keep" : "Not done"
        return face()
            .overlay(alignment: .bottomLeading) {
                stamp(rightLabel, color: Theme.accent, angle: -8).opacity(max(0, lean)).padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                stamp(leftLabel, color: Theme.ink2, angle: 8).opacity(max(0, -lean)).padding(12)
            }
            .brightness(depth > 0 ? -0.025 * Double(min(depth, 2)) : 0)
            .scaleEffect(scale)
            .rotationEffect(.degrees(angle))
            .offset(x: x, y: y)
            .opacity(opacity)
            // Answered cards fly over the stack; the rest stack front to back.
            .zIndex(depth < 0 ? Double(10 + pos) : Double(-depth))
            .allowsHitTesting(depth == 0)
            .gesture(swipe)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { dragX = $0.translation.width }
            .onEnded { value in
                let dx = value.translation.width
                let flung = abs(value.predictedEndTranslation.width) > Self.swipeThreshold * 2.2
                withAnimation(Self.fling) {
                    if abs(dx) > Self.swipeThreshold || flung { choose(right: dx > 0) }
                    dragX = 0
                }
            }
    }

    private func cardFace(_ item: TodoItem) -> some View {
        let kind = DayKey.kind(item.date, today: store.today)
        return cardShell {
            HStack(spacing: 6) {
                if let g = item.group {
                    HStack(spacing: 5) {
                        GroupMark(hex: store.color(forGroup: g), emoji: store.emoji(forGroup: g), dotSize: 6)
                        Text(g)
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink2)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Capsule().fill(Theme.ground))
                }
                if item.onToday {
                    Text("On Today")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.sunInk)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(Theme.sunSoft))
                }
                Spacer(minLength: 0)
                if item.date != nil {
                    Text(DayKey.longLabel(item.date, today: store.today))
                        .font(Theme.mono(11, kind == .overdue || kind == .today ? .medium : .regular))
                        .foregroundStyle(Theme.dateColor(kind))
                }
            }
            .frame(minHeight: 22)
            titleScroll(item.title)
        }
    }

    private func noteFace(_ note: Note) -> some View {
        cardShell {
            HStack {
                Spacer(minLength: 0)
                Text(shortTime(note.createdAt))
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.muted)
            }
            .frame(minHeight: 22)
            titleScroll(note.text)
        }
    }

    private func titleScroll(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: 18, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func cardShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.07), radius: 8, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    private func stamp(_ title: String, color: Color, angle: Double) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color, lineWidth: 1.5))
            .rotationEffect(.degrees(angle))
    }

    private func answerButton(_ title: String, key: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(key)
                    .font(Theme.mono(11, .medium))
                    .padding(.horizontal, 5)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(filled ? Theme.onAccentLine : Theme.stroke))
            }
            .foregroundStyle(filled ? Theme.onAccent : Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 9).fill(filled ? Theme.accent : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(filled ? .clear : Theme.stroke))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var finishedScreen: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.accent))
            Text("You’re all caught up").font(.system(size: 16, weight: .semibold))
            Text(finishedLine)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                pill("Home ⏎", filled: true, action: leave)
                pill("Run again R", filled: false, action: restart)
            }
            .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var finishedLine: String {
        if mode == .notes { return "\(doneCount) made to-dos · \(keptCount) kept" }
        return "\(doneCount) marked done · \(keptCount) still open"
    }

    private var emptyScreen: some View {
        VStack(spacing: 8) {
            Spacer()
            Text(mode == .notes ? "No notes to review" : "Nothing to catch up on")
                .font(.system(size: 15, weight: .semibold))
            Text(mode == .notes
                 ? "Press B on Home to dump a thought."
                 : "Catch up walks through today’s list and anything due.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
            pill("Home ⏎", filled: true, action: leave)
                .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func pill(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: filled ? .semibold : .medium))
                .foregroundStyle(filled ? Theme.onInk : Theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(filled ? Theme.ink : Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(filled ? .clear : Theme.stroke))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "3:12 PM" for a note from today, "Oct 14" otherwise.
    private func shortTime(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            let hour = parts.hour ?? 0
            let minute = parts.minute ?? 0
            let h = hour % 12 == 0 ? 12 : hour % 12
            let suffix = hour < 12 ? "AM" : "PM"
            return "\(h):" + String(format: "%02d", minute) + " \(suffix)"
        }
        let parts = calendar.dateComponents([.month, .day], from: date)
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let month = months[max(0, min(11, (parts.month ?? 1) - 1))]
        return "\(month) \(parts.day ?? 1)"
    }

    // MARK: Actions

    private func begin() {
        if let review = state.takeNoteReview() {
            restore(review)
        } else {
            mode = .todos
            loadTodos()
        }
    }

    private func switchMode(_ next: Deck) {
        guard next != mode else { return }
        mode = next
        if next == .notes { loadNotes() } else { loadTodos() }
    }

    private func restart() {
        if mode == .notes { loadNotes() } else { loadTodos() }
    }

    private func loadTodos() {
        deck = store.catchUpDeck.map(\.id)
        index = 0
        doneCount = 0
        keptCount = 0
        history = []
        noteSteps = []
        noteSnapshots = [:]
        dragX = 0
        started = true
    }

    private func loadNotes() {
        let notes = store.notes
        deck = notes.map(\.id)
        noteSnapshots = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        index = 0
        doneCount = 0
        keptCount = 0
        history = []
        noteSteps = []
        dragX = 0
        started = true
    }

    private func restore(_ review: NoteReview) {
        mode = .notes
        deck = review.deck
        noteSnapshots = review.snapshots
        noteSteps = review.steps
        history = []
        keptCount = review.keptCount
        doneCount = review.promotedCount
        dragX = 0
        if store.notes.contains(where: { $0.id == review.promotingID }) {
            index = review.index
        } else {
            doneCount += 1
            noteSteps.append(.promote)
            index = review.index + 1
        }
        started = true
    }

    private func choose(right: Bool) {
        if mode == .notes {
            if right { promoteNote() } else { keepNote() }
        } else {
            answer(done: right)
        }
    }

    private func answer(done: Bool) {
        guard active, mode == .todos else { return }
        let id = deck[index]
        let wasDone = store.item(id)?.done ?? false
        if done { store.setDone(id, true) }
        withAnimation(Self.fling) {
            history.append((id, wasDone, done))
            if done { doneCount += 1 } else { keptCount += 1 }
            index += 1
        }
    }

    private func keepNote() {
        guard active, mode == .notes else { return }
        withAnimation(Self.fling) {
            noteSteps.append(.keep)
            keptCount += 1
            index += 1
        }
    }

    private func deleteNote() {
        guard active, mode == .notes else { return }
        let id = deck[index]
        guard let note = noteForCard(id) else { return }
        store.deleteNote(id)
        withAnimation(Self.fling) {
            noteSteps.append(.delete(note))
            index += 1
        }
    }

    private func promoteNote() {
        guard active, mode == .notes else { return }
        let id = deck[index]
        guard let note = store.notes.first(where: { $0.id == id }) ?? noteSnapshots[id] else { return }
        state.stashNoteReview(NoteReview(
            deck: deck,
            index: index,
            keptCount: keptCount,
            promotedCount: doneCount,
            promotingID: id,
            steps: noteSteps,
            snapshots: noteSnapshots
        ))
        state.openAdd(draft: AddDraft(title: note.text, noteID: id, returnTo: .catchUp))
    }

    private func undo() {
        if mode == .notes { undoNote() } else { undoTodo() }
    }

    private func undoTodo() {
        guard let last = history.popLast() else { return }
        store.setDone(last.id, last.wasDone)
        withAnimation(Self.fling) {
            if last.markedDone { doneCount -= 1 } else { keptCount -= 1 }
            index -= 1
        }
    }

    private func undoNote() {
        guard let last = noteSteps.last else { return }
        if case .promote = last { return }
        noteSteps.removeLast()
        withAnimation(Self.fling) {
            switch last {
            case .keep:
                keptCount -= 1
                index -= 1
            case .delete(let note):
                store.restoreNote(note)
                noteSnapshots[note.id] = note
                index -= 1
            case .promote:
                break
            }
        }
    }

    private func noteForCard(_ id: UUID) -> Note? {
        noteSnapshots[id] ?? store.notes.first { $0.id == id }
    }

    private func noteWentRight(_ pos: Int) -> Bool {
        guard pos < noteSteps.count else { return false }
        if case .promote = noteSteps[pos] { return true }
        return false
    }

    private func leave() {
        state.goHome(highlight: 2)
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        switch press.key {
        case .escape: leave(); return .handled
        case .rightArrow where active: choose(right: true); return .handled
        case .leftArrow where active: choose(right: false); return .handled
        case .return where !active: leave(); return .handled
        default: break
        }
        if press.isBackspace, mode == .notes, active {
            deleteNote()
            return .handled
        }
        switch press.characters.lowercased() {
        case "1": switchMode(.todos)
        case "2": switchMode(.notes)
        case "d" where active: choose(right: true)
        case "n" where active: choose(right: false)
        case "z", "u": undo()
        case "r" where finished: restart()
        default: return .ignored
        }
        return .handled
    }
}
