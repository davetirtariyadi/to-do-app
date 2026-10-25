import AppKit
import SwiftUI
import TodoCore

private enum DumpField: Hashable {
    case text, dump
}

/// One line, then Return. Same shell as Add, without group, date or Today.
struct DumpView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store

    @FocusState private var focus: DumpField?
    @Local private var text = ""
    @Local private var note = ""

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(onBack: { state.goHome(highlight: 1) }) {
                Text("Brain dump").font(.system(size: 14, weight: .semibold))
            } trailing: {
                HintText(text: "Esc back")
            }

            VStack(alignment: .leading, spacing: 10) {
                textField
                if !note.isEmpty {
                    Text(note).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                dumpButton
                HintText(text: "Tab next · ⏎ dump · ⇧⏎ dump another")
                    .frame(maxWidth: .infinity)
            }
            .padding(12)
        }
        .onKeyPress(phases: .down) { handleContainer($0) }
        .onAppear { DispatchQueue.main.async { focus = .text } }
        .onChange(of: state.focusTick) { focus = .text }
        .onChange(of: state.escapeTick) { leave() }
    }

    private var textField: some View {
        TextField("What's on your mind?", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(focus == .text ? Theme.accent : Theme.dim, lineWidth: focus == .text ? 2 : 1)
            )
            .focused($focus, equals: .text)
            .onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.command) { return .ignored }
                submit(stay: press.modifiers.contains(.shift))
                return .handled
            }
            .onSubmit { submit(stay: false) }
            .onChange(of: text) { _, new in if !new.isEmpty { note = "" } }
    }

    private var dumpButton: some View {
        let ready = !text.trimmingCharacters(in: .whitespaces).isEmpty
        return Text("Dump")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 9).fill(ready ? Theme.accent : Theme.accentDisabled))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(focus == .dump ? Theme.accent : .clear, lineWidth: 2)
                    .padding(-3)
            )
            .contentShape(Rectangle())
            .focusable()
            .focused($focus, equals: .dump)
            .focusEffectDisabled()
            .onTapGesture { submit(stay: false) }
            .onKeyPress(phases: .down) { press in
                guard press.key == .return || press.key == .space, !press.modifiers.contains(.command) else { return .ignored }
                submit(stay: press.modifiers.contains(.shift))
                return .handled
            }
    }

    private func handleContainer(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .return && press.modifiers.contains(.command) {
            submit(stay: press.modifiers.contains(.shift))
            return .handled
        }
        if press.key == .tab {
            focus = focus == .dump ? .text : .dump
            return .handled
        }
        if press.key == .escape {
            leave()
            return .handled
        }
        return .ignored
    }

    private func leave() {
        state.goHome(highlight: 1)
    }

    private func submit(stay: Bool) {
        guard let item = store.addNote(text: text) else {
            NSSound.beep()
            focus = .text
            return
        }
        let message = "Noted “\(item.text)”"
        if stay {
            text = ""
            note = message
            focus = .text
        } else {
            state.showToast(message)
            state.goHome(highlight: 1)
        }
    }
}
