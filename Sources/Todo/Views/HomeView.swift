import SwiftUI
import TodoCore

/// A large option row used on Home and the View picker.
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
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(highlighted ? Theme.accent : Theme.border, lineWidth: highlighted ? 2 : 1)
        )
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

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store
    @EnvironmentObject var controller: AppController

    var body: some View {
        let deck = store.catchUpDeck.count
        VStack(spacing: 0) {
            HeaderBar(onBack: nil) {
                RoundedRectangle(cornerRadius: 3).fill(Theme.accent).frame(width: 10, height: 10)
                Text("Todo").font(.system(size: 14, weight: .semibold))
            } trailing: {
                HintText(text: "↑↓ move · ⏎ open")
                PinButton()
            }

            VStack(spacing: 8) {
                OptionRow(icon: "plus", title: "Add to-do", subtitle: "What, group, date", key: "A",
                          highlighted: state.homeIndex == 0)
                    .onTapGesture { activate(0) }
                OptionRow(icon: "checkmark.rectangle.stack", title: "Catch up",
                          subtitle: deck > 0 ? "\(deck) to review" : "All clear", key: "C",
                          highlighted: state.homeIndex == 1)
                    .onTapGesture { activate(1) }
                OptionRow(icon: "rectangle.split.3x1", title: "View", subtitle: "Today · All · Board · Groups", key: "V",
                          highlighted: state.homeIndex == 2)
                    .onTapGesture { activate(2) }
            }
            .padding(12)

            Spacer(minLength: 0)
            footer
        }
        .grabsFocus()
        .onKeyPress(phases: .down) { handle($0) }
    }

    @ViewBuilder private var footer: some View {
        if let toast = state.toast {
            HStack(spacing: 6) {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accent)
                Text(toast).font(.system(size: 12.5)).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        } else {
            TodayPill(done: store.todayDone.count, total: store.todayOpen.count + store.todayDone.count)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
    }

    private func activate(_ i: Int) {
        state.homeIndex = i
        switch i {
        case 0: state.go(.add)
        case 1: state.go(.catchUp)
        default: state.go(.view)
        }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        switch press.key {
        case .upArrow: state.homeIndex = (state.homeIndex + 2) % 3; return .handled
        case .downArrow: state.homeIndex = (state.homeIndex + 1) % 3; return .handled
        case .return, .space: activate(state.homeIndex); return .handled
        case .escape: controller.hide(); return .handled
        default: break
        }
        switch press.characters.lowercased() {
        case "a": activate(0)
        case "c": activate(1)
        case "v": activate(2)
        default: return .ignored
        }
        return .handled
    }
}

/// Today's progress as a pill that fills from the left, with the count on top.
/// A thin accent edge marks where the fill ends while the day is in progress.
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
