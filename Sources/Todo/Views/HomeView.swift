import SwiftUI
import TodoCore

/// A large option row used by the View picker.
struct OptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let key: String
    let highlighted: Bool
    var height: CGFloat = 60

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.accentSoft))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(subtitle).font(.system(size: 12.5)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 4)
            KeyCap(text: key)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 12).fill(highlighted ? Theme.cursor : .clear))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(highlighted ? Theme.border : .clear))
        .contentShape(Rectangle())
    }
}

/// Makes a screen's root view take keyboard focus when it appears and
/// whenever the window is re-shown.
struct GrabsFocus: ViewModifier {
    @EnvironmentObject var state: AppState
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onAppear { DispatchQueue.main.async { focused = true } }
            .onChange(of: state.focusTick) { focused = true }
    }
}

extension View {
    func grabsFocus() -> some View { modifier(GrabsFocus()) }
}

// MARK: - Home (Enso)

private enum Enso {
    static let rowHeight: CGFloat = 68
    static let breath: Double = 7
    static let slide = Animation.spring(response: 0.55, dampingFraction: 0.72)
    static let ease = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.9)
}

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store
    @EnvironmentObject var controller: AppController
    @Local private var appeared = false

    private struct Option { let title, subtitle, key: String }

    var body: some View {
        let done = store.todayDone.count
        let total = store.todayOpen.count + done
        let options = [
            Option(title: "Add to-do", subtitle: "What, group, date", key: "A"),
            Option(title: "Brain dump", subtitle: dumpSubtitle, key: "B"),
            Option(title: "Catch up", subtitle: catchUpSubtitle, key: "C"),
            Option(title: "View", subtitle: "Today · All · Board · Groups", key: "V"),
        ]

        VStack(spacing: 0) {
            HeaderBar(onBack: nil) {
                Circle().stroke(Theme.accent, lineWidth: 1.5).frame(width: 10, height: 10)
                Text("Todo").font(.system(size: 14, weight: .semibold))
            } trailing: {
                HintText(text: "↑↓ move · ⏎ open")
                PinButton()
            }

            HStack(spacing: 22) {
                EnsoRing(done: done, total: total, appeared: appeared)
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY").font(Theme.mono(11)).tracking(0.8).foregroundStyle(Theme.faint)
                    Text(title(done: done, total: total))
                        .font(.system(size: 22, weight: .light))
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: done)
                    if total > 0 && total <= 12 {
                        HStack(spacing: 7) {
                            ForEach(0..<total, id: \.self) { i in
                                Circle()
                                    .fill(i < done ? Theme.accent : .clear)
                                    .overlay(Circle().stroke(Theme.hollow, lineWidth: 1))
                                    .frame(width: 9, height: 9)
                                    .animation(.easeInOut(duration: 0.4).delay(Double(i) * 0.05), value: done)
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(Enso.ease.delay(0.3), value: appeared)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)

            Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 24)

            ZStack(alignment: .topLeading) {
                highlight
                VStack(spacing: 0) {
                    ForEach(options.indices, id: \.self) { i in
                        row(options[i], index: i)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(Enso.ease.delay(0.5 + Double(i) * 0.12), value: appeared)
                    }
                }
            }
            .padding(12)

            Spacer(minLength: 0)
            footer
        }
        .grabsFocus()
        .onKeyPress(phases: .down) { handle($0) }
        .onAppear { appeared = true }
        .onChange(of: state.focusTick) {
            appeared = false
            DispatchQueue.main.async { appeared = true }
        }
    }

    private func title(done: Int, total: Int) -> String {
        if total == 0 { return "Nothing planned." }
        return done == total ? "Complete." : "\(total - done) left."
    }

    /// The pill that glides between rows and carries the row's glyph.
    private var highlight: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Theme.cursor)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .overlay(alignment: .trailing) {
                ActionGlyph(index: state.homeIndex)
                    .frame(width: 56, height: 44)
                    .padding(.trailing, 44)
            }
            .frame(height: Enso.rowHeight)
            .offset(y: CGFloat(state.homeIndex) * Enso.rowHeight)
            .animation(Enso.slide, value: state.homeIndex)
    }

    private func row(_ o: Option, index i: Int) -> some View {
        let on = state.homeIndex == i
        return HStack(spacing: 14) {
            Circle().fill(Theme.accent)
                .frame(width: 6, height: 6)
                .scaleEffect(on ? 1 : 0.2)
                .opacity(on ? 1 : 0)
            VStack(alignment: .leading, spacing: 3) {
                Text(o.title).font(.system(size: 15)).foregroundStyle(on ? Theme.ink : Theme.muted)
                Text(o.subtitle).font(.system(size: 12)).foregroundStyle(Theme.faint)
            }
            Spacer(minLength: 4)
            KeyCap(text: o.key)
        }
        .padding(.horizontal, 16)
        .frame(height: Enso.rowHeight)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.4), value: on)
        .onHover { if $0 { state.homeIndex = i } }
        .onTapGesture { activate(i) }
    }

    @ViewBuilder private var footer: some View {
        if let toast = state.toast {
            HStack(spacing: 6) {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accent)
                Text(toast).font(.system(size: 12.5)).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)
            .transition(.opacity.combined(with: .offset(y: 6)))
        }
    }

    private var catchUpSubtitle: String {
        let todos = store.catchUpDeck.count
        let notes = store.notes.count
        if notes == 0 { return todos > 0 ? "\(todos) to review" : "All clear" }
        let noteLabel = notes == 1 ? "1 note" : "\(notes) notes"
        if todos == 0 { return noteLabel }
        let todoLabel = todos == 1 ? "1 to-do" : "\(todos) to-dos"
        return "\(todoLabel) · \(noteLabel)"
    }

    private var dumpSubtitle: String {
        switch store.notes.count {
        case 0: return "A quick thought"
        case 1: return "1 note"
        default: return "\(store.notes.count) notes"
        }
    }

    private func activate(_ i: Int) {
        state.homeIndex = i
        switch i {
        case 0: state.openAdd()
        case 1: state.go(.dump)
        case 2: state.go(.catchUp)
        default: state.go(.view)
        }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        switch press.key {
        case .upArrow: state.homeIndex = (state.homeIndex + 3) % 4; return .handled
        case .downArrow: state.homeIndex = (state.homeIndex + 1) % 4; return .handled
        case .return, .space: activate(state.homeIndex); return .handled
        case .escape: controller.hide(); return .handled
        default: break
        }
        switch press.characters.lowercased() {
        case "a": activate(0)
        case "b": activate(1)
        case "c": activate(2)
        case "v": activate(3)
        default: return .ignored
        }
        return .handled
    }
}

// MARK: - Breathing ring

/// Today's progress as a ring that fills per completed item and breathes slowly.
struct EnsoRing: View {
    let done: Int
    let total: Int
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let fraction = total == 0 ? 0 : Double(done) / Double(total)
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let b = reduceMotion ? 0.5 : 0.5 - 0.5 * cos(2 * .pi * t / Enso.breath)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.glow, .clear], center: .center, startRadius: 0, endRadius: 52))
                    .frame(width: 104, height: 104)
                    .scaleEffect(0.9 + 0.25 * b)
                    .opacity(0.3 + 0.7 * b)
                ZStack {
                    Circle().stroke(Theme.line, lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: appeared ? fraction : 0)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.timingCurve(0.6, 0, 0.2, 1, duration: 1.2), value: fraction)
                        .animation(.timingCurve(0.6, 0, 0.2, 1, duration: 2.0).delay(0.2), value: appeared)
                    Text("\(done) / \(total)")
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.4), value: done)
                }
                .frame(width: 76, height: 76)
                .scaleEffect(0.96 + 0.08 * b)
            }
            .frame(width: 76, height: 76)
        }
    }
}

// MARK: - Action glyphs

/// Small looping line drawings that ride inside the highlight.
struct ActionGlyph: View {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 1.0 : ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                layer(0) { AddGlyph(t: t) }
                layer(1) { DumpGlyph(t: t) }
                layer(2) { CatchUpGlyph(t: t) }
                layer(3) { ViewGlyph(t: t) }
            }
        }
        .animation(.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.5), value: index)
    }

    private func layer<V: View>(_ i: Int, @ViewBuilder _ v: () -> V) -> some View {
        let on = i == index
        return v()
            .opacity(on ? 1 : 0)
            .scaleEffect(on ? 1 : 0.7)
            .offset(y: on ? 0 : 6)
    }
}

private func phase(_ t: Double, _ period: Double) -> Double {
    (t.truncatingRemainder(dividingBy: period)) / period
}

private func lerp(_ a: Double, _ b: Double, _ p: Double) -> Double { a + (b - a) * min(1, max(0, p)) }

/// A drop falls into a circle and ripples out.
struct AddGlyph: View {
    let t: Double
    var body: some View {
        let p = phase(t, 2.6)
        let y = p < 0.35 ? lerp(-14, 0, p / 0.35) : 0
        let fadeIn = p < 0.35 ? p / 0.35 : 1
        let spread = p > 0.65 ? (p - 0.65) / 0.35 : 0
        ZStack {
            Circle().stroke(Theme.accent.opacity(0.7), lineWidth: 1.2).frame(width: 26, height: 26)
            Circle().fill(Theme.accent)
                .frame(width: 6, height: 6)
                .scaleEffect(1 + 3.5 * spread)
                .opacity(fadeIn * (1 - spread))
                .offset(y: y)
        }
    }
}

/// A short line writes itself, then fades.
struct DumpGlyph: View {
    let t: Double
    var body: some View {
        let p = phase(t, 2.8)
        let draw = p < 0.55 ? p / 0.55 : 1
        let fade = p > 0.75 ? 1 - (p - 0.75) / 0.25 : 1
        Capsule()
            .fill(Theme.accent)
            .frame(width: 28 * draw, height: 2)
            .opacity(fade)
            .frame(width: 28, alignment: .leading)
    }
}

/// A card slides onto a stack, then lifts away.
struct CatchUpGlyph: View {
    let t: Double
    var body: some View {
        let p = phase(t, 3)
        let x = p < 0.3 ? lerp(18, 0, p / 0.3) : 0
        let y = p > 0.8 ? lerp(0, -4, (p - 0.8) / 0.2) : 0
        let o = p < 0.3 ? p / 0.3 : (p > 0.8 ? 1 - (p - 0.8) / 0.2 : 1)
        VStack(spacing: 3) {
            card(1).offset(x: x, y: y).opacity(o)
            card(0.5)
            card(0.25)
        }
    }
    private func card(_ a: Double) -> some View {
        RoundedRectangle(cornerRadius: 3).stroke(Theme.accent.opacity(a), lineWidth: 1.2).frame(width: 32, height: 6)
    }
}

/// Three board columns gently rise and fall.
struct ViewGlyph: View {
    let t: Double
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            bar(20, 0)
            bar(28, -1)
            bar(16, -2)
        }
        .frame(height: 30, alignment: .bottom)
    }
    private func bar(_ h: CGFloat, _ offset: Double) -> some View {
        let s = 0.55 + 0.45 * (0.5 - 0.5 * cos(2 * .pi * (t + offset) / 3.2))
        return RoundedRectangle(cornerRadius: 2)
            .stroke(Theme.accent, lineWidth: 1.2)
            .frame(width: 7, height: h)
            .scaleEffect(x: 1, y: s, anchor: .bottom)
    }
}

// MARK: - Shared

/// Today's progress as a pill that fills from the left, with the count on top.
struct TodayPill: View {
    let done: Int
    let total: Int

    var body: some View {
        let fraction = total == 0 ? 0 : Double(done) / Double(total)
        HStack {
            Text("Today")
            Spacer()
            Text("\(done) of \(total) done")
        }
        .font(Theme.mono(11.5))
        .foregroundStyle(Theme.ink2)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background {
            GeometryReader { geo in
                let width = geo.size.width * fraction
                ZStack(alignment: .leading) {
                    Theme.surface
                    Theme.accentSoft.frame(width: width)
                    Theme.accent
                        .frame(width: 2)
                        .offset(x: max(0, width - 2))
                        .opacity(fraction > 0 && fraction < 1 ? 1 : 0)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
        .animation(.spring(response: 0.5, dampingFraction: 1), value: fraction)
    }
}

struct ProgressBar: View {
    let fraction: Double
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(Theme.accent).frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: height)
    }
}
