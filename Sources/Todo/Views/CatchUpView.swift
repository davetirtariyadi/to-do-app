import SwiftUI
import TodoCore

/// A stack of cards: → or swipe right is done, ← or swipe left is not done,
/// Z undo. The deck is fixed when the screen opens so marking items done
/// doesn't reshuffle it.
///
/// Answered cards stay in the view, parked off to the side they were sent,
/// so answering and undoing are both just a change of `index` that SwiftUI
/// animates: the card flies out, or flies back in from where it left.
struct CatchUpView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store

    @Local private var deck: [UUID] = []
    @Local private var index = 0
    @Local private var doneCount = 0
    @Local private var keptCount = 0
    @Local private var history: [(id: UUID, wasDone: Bool, markedDone: Bool)] = []
    @Local private var started = false
    @Local private var dragX: CGFloat = 0

    private static let fling = Animation.spring(response: 0.36, dampingFraction: 0.82)
    /// How far a drag has to travel before letting go answers the card.
    private static let swipeThreshold: CGFloat = 100
    /// Resting tilt of the top card and the two peeking behind it.
    private static let tilts: [Double] = [0, -2.2, 1.8]

    private var active: Bool { index < deck.count }
    private var finished: Bool { !deck.isEmpty && index >= deck.count }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(onBack: { state.goHome(highlight: 1) }) {
                Text("Catch up").font(.system(size: 14, weight: .semibold))
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
        .onAppear(perform: restart)
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
                answerButton("Not done", key: "←", filled: false) { answer(done: false) }
                answerButton("Done", key: "→", filled: true) { answer(done: true) }
            }

            HStack {
                Button(action: undo) {
                    Text("Z undo").font(Theme.mono(11))
                        .foregroundStyle(history.isEmpty ? Theme.disabled : Theme.ink2)
                }
                .buttonStyle(.plain)
                .disabled(history.isEmpty)
                Spacer()
                Text("\(doneCount) done · \(keptCount) open · Esc home")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.muted)
            }
            .frame(height: 18)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// The last two answered cards (parked off screen, so undo can fly them
    /// back), the current card, and three behind it. Only two of those peek out.
    private var cardStack: some View {
        let range = max(0, index - 2)..<min(deck.count, index + 4)
        return ZStack {
            ForEach(range, id: \.self) { pos in
                if let item = store.item(deck[pos]) {
                    stackCard(item, at: pos)
                }
            }
        }
    }

    private func stackCard(_ item: TodoItem, at pos: Int) -> some View {
        let depth = pos - index
        var x: CGFloat = 0, y: CGFloat = 0, angle = 0.0, scale: CGFloat = 1, opacity = 1.0
        // -1…1: how far toward "Not done" or "Done" the card has been pushed.
        var lean: CGFloat = 0
        if depth < 0 {
            let dir: CGFloat = pos < history.count && history[pos].markedDone ? 1 : -1
            x = dir * 460; y = -20; angle = Double(dir) * 24; opacity = 0; lean = dir
        } else if depth == 0 {
            x = dragX; angle = Double(dragX / 200 * 12)
            lean = max(-1, min(1, dragX / 90))
        } else {
            let d = min(depth, 2)
            y = CGFloat(d) * 11; scale = 1 - CGFloat(d) * 0.04; angle = Self.tilts[d]
            opacity = depth > 2 ? 0 : 1
        }
        return cardFace(item)
            .overlay(alignment: .bottomLeading) {
                stamp("Done", color: Theme.accent, angle: -8).opacity(max(0, lean)).padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                stamp("Not done", color: Theme.ink2, angle: 8).opacity(max(0, -lean)).padding(12)
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
                    if abs(dx) > Self.swipeThreshold || flung { answer(done: dx > 0) }
                    dragX = 0
                }
            }
    }

    private func cardFace(_ item: TodoItem) -> some View {
        let kind = DayKey.kind(item.date, today: store.today)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let g = item.group {
                    HStack(spacing: 5) {
                        Dot(hex: store.color(forGroup: g), size: 6)
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
            ScrollView {
                Text(item.title)
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            Text("\(doneCount) marked done · \(keptCount) still open")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                pill("Home ⏎", filled: true) { state.goHome(highlight: 1) }
                pill("Run again R", filled: false, action: restart)
            }
            .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyScreen: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Nothing to catch up on").font(.system(size: 15, weight: .semibold))
            Text("Catch up walks through today’s list and anything due.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
            pill("Home ⏎", filled: true) { state.goHome(highlight: 1) }
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

    // MARK: Actions

    private func restart() {
        deck = store.catchUpDeck.map(\.id)
        index = 0
        doneCount = 0
        keptCount = 0
        history = []
        dragX = 0
        started = true
    }

    private func answer(done: Bool) {
        guard active else { return }
        let id = deck[index]
        let wasDone = store.item(id)?.done ?? false
        if done { store.setDone(id, true) }
        withAnimation(Self.fling) {
            history.append((id, wasDone, done))
            if done { doneCount += 1 } else { keptCount += 1 }
            index += 1
        }
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        store.setDone(last.id, last.wasDone)
        withAnimation(Self.fling) {
            if last.markedDone { doneCount -= 1 } else { keptCount -= 1 }
            index -= 1
        }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        switch press.key {
        case .escape: state.goHome(highlight: 1); return .handled
        case .rightArrow where active: answer(done: true); return .handled
        case .leftArrow where active: answer(done: false); return .handled
        case .return where !active: state.goHome(highlight: 1); return .handled
        default: break
        }
        switch press.characters.lowercased() {
        case "d" where active: answer(done: true)
        case "n" where active: answer(done: false)
        case "z", "u": undo()
        case "r" where finished: restart()
        default: return .ignored
        }
        return .handled
    }
}
