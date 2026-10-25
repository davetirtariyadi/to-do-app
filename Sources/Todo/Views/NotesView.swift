import SwiftUI
import TodoCore

/// Notes, newest first. Return or A opens Add with the text filled in; the
/// note itself stays until that to-do is actually saved.
struct NotesView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store

    @Local private var index = 0
    @Local private var deleting: UUID? = nil

    private var currentIndex: Int {
        guard !store.notes.isEmpty else { return 0 }
        return min(index, store.notes.count - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(onBack: { state.go(.view) }) {
                Text("Notes").font(.system(size: 14, weight: .semibold))
            } trailing: {
                Text("\(store.notes.count)")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.muted)
                    .padding(.trailing, 6)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if store.notes.isEmpty {
                            Text("No notes yet. Press B on Home to dump a thought.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.muted)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                                .padding(.top, 8)
                        } else {
                            ForEach(Array(store.notes.enumerated()), id: \.element.id) { i, note in
                                row(note, isCursor: i == currentIndex).id(note.id)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .onChange(of: index) { _, _ in
                    guard store.notes.indices.contains(currentIndex) else { return }
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(store.notes[currentIndex].id) }
                }
            }

            HStack {
                HintText(text: "↑↓ move · ⏎ or A make a to-do · ⌫ delete · Esc")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(Theme.surface)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .overlay {
            if let id = deleting, let note = store.notes.first(where: { $0.id == id }) {
                ZStack {
                    Theme.scrim
                    deleteCard(note)
                }
            }
        }
        .grabsFocus()
        .onKeyPress(phases: .down) { handle($0) }
        .onChange(of: state.escapeTick) { escape() }
    }

    private func row(_ note: Note, isCursor: Bool) -> some View {
        HStack(spacing: 8) {
            Text(note.text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(shortTime(note.createdAt))
                .font(Theme.mono(11))
                .foregroundStyle(Theme.muted)
            iconButton("trash", help: "Delete (⌫)") { select(note.id); startDelete() }
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 7).fill(isCursor ? Theme.cursor : .clear))
        .contentShape(Rectangle())
        .onTapGesture { select(note.id) }
    }

    private func iconButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.faint)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder private func deleteCard(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Delete “\(note.text)”?")
                .font(.system(size: 13.5, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            HintText(text: "⏎ delete · Esc cancel")
        }
        .padding(14)
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Theme.surface)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke))
        .onTapGesture { confirmDelete() }
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

    private func select(_ id: UUID) {
        if let i = store.notes.firstIndex(where: { $0.id == id }) { index = i }
    }

    private func startDelete() {
        guard store.notes.indices.contains(currentIndex) else { return }
        deleting = store.notes[currentIndex].id
    }

    /// The deleted row disappears, so the cursor stays on what slides into its place.
    private func confirmDelete() {
        guard let id = deleting else { return }
        let i = store.notes.firstIndex { $0.id == id } ?? currentIndex
        store.deleteNote(id)
        if store.notes.isEmpty {
            index = 0
        } else {
            index = min(i, store.notes.count - 1)
        }
        deleting = nil
    }

    private func promote() {
        guard store.notes.indices.contains(currentIndex) else { return }
        let note = store.notes[currentIndex]
        state.openAdd(draft: AddDraft(title: note.text, noteID: note.id, returnTo: .notes))
    }

    private func escape() {
        if deleting != nil { deleting = nil }
        else { state.go(.view) }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        if deleting != nil {
            switch press.key {
            case .return, .space: confirmDelete()
            case .escape: escape()
            default: break
            }
            return .handled
        }
        if press.isBackspace { startDelete(); return .handled }
        switch press.key {
        case .escape: escape(); return .handled
        case .upArrow:
            guard !store.notes.isEmpty else { return .handled }
            index = max(0, currentIndex - 1)
            return .handled
        case .downArrow:
            guard !store.notes.isEmpty else { return .handled }
            index = min(store.notes.count - 1, currentIndex + 1)
            return .handled
        case .return: promote(); return .handled
        default: break
        }
        if press.characters.lowercased() == "a" { promote(); return .handled }
        return .ignored
    }
}
