import SwiftUI
import TodoCore

/// Rename, recolour, reorder, add and delete groups — all from the keyboard.
struct GroupsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store

    @Local private var cursor = 0
    @Local private var renaming: String? = nil
    @Local private var creating = false
    @Local private var draft = ""
    @Local private var error = ""
    @Local private var deleting: String? = nil
    @Local private var deleteTarget = 0
    @FocusState private var fieldFocused: Bool

    private var editing: Bool { renaming != nil || creating }

    private var current: TodoGroup? {
        store.groups.indices.contains(cursor) ? store.groups[cursor] : nil
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderBar(onBack: { state.goHome(highlight: 2) }) {
                    Text("Groups").font(.system(size: 14, weight: .semibold))
                } trailing: {
                    Text("\(store.groups.count) groups")
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.muted)
                        .padding(.trailing, 6)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(store.groups.enumerated()), id: \.element.name) { i, g in
                                row(i, g).id(i)
                            }
                            if creating { newRow } else { addRow }
                        }
                        .padding(8)
                    }
                    .onChange(of: cursor) { _, i in proxy.scrollTo(i) }
                }

                if !error.isEmpty {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.overdue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 4)
                }

                HStack {
                    HintText(text: editing
                             ? "⏎ save · Esc cancel"
                             : "⏎ rename · C colour · ⌥↑↓ order · ⌫ delete · N new")
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Theme.surface)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            }

            if let name = deleting {
                Theme.scrim
                deleteCard(name)
            }
        }
        .grabsFocus()
        .onKeyPress(phases: .down) { handle($0) }
        .onChange(of: state.escapeTick) { escape() }
        .onChange(of: fieldFocused) { _, focused in
            // Clicking away from the name field saves it, like pressing Enter.
            if !focused && editing { commitEdit() }
        }
    }

    // MARK: Rows

    private func row(_ i: Int, _ g: TodoGroup) -> some View {
        HStack(spacing: 8) {
            Button { cursor = i; store.cycleGroupColor(g.name) } label: {
                Circle().fill(Color(hex: g.colorHex)).frame(width: 12, height: 12)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Change colour (C)")

            if renaming == g.name {
                nameField
            } else {
                Text(g.name).font(.system(size: 13.5)).lineLimit(1)
            }
            Spacer(minLength: 6)
            Text("\(store.openCount(inGroup: g.name)) open")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.muted)
            iconButton("pencil", help: "Rename (⏎)") { cursor = i; startRename() }
            iconButton("trash", help: "Delete (⌫)") { cursor = i; startDelete() }
        }
        .padding(.leading, 2)
        .padding(.trailing, 4)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 7).fill(i == cursor && !creating ? Theme.cursor : .clear))
        .contentShape(Rectangle())
        .onTapGesture { cursor = i }
    }

    private var nameField: some View {
        TextField(creating ? "New group name" : "Group name", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: 13.5))
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent, lineWidth: 1.5))
            .focused($fieldFocused)
            .onSubmit(commitEdit)
    }

    private var newRow: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: TodoGroup.palette[store.groups.count % TodoGroup.palette.count]))
                .frame(width: 12, height: 12)
                .frame(width: 26, height: 26)
            nameField
        }
        .padding(.leading, 2)
        .padding(.trailing, 4)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.cursor))
    }

    private var addRow: some View {
        Button(action: startCreate) {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold)).frame(width: 26, height: 26)
                Text("New group").font(.system(size: 13))
                Spacer()
                KeyCap(text: "N")
            }
            .foregroundStyle(Theme.ink2)
            .padding(.leading, 2)
            .padding(.trailing, 4)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    // MARK: Delete

    private func deleteChoices(for name: String) -> [GroupChoice] {
        [GroupChoice(label: "No group", value: nil, hex: "#B9BFC9", isCurrent: false)]
            + store.groups.filter { $0.name != name }
                .map { GroupChoice(label: $0.name, value: $0.name, hex: $0.colorHex, isCurrent: false) }
    }

    private func itemCount(_ name: String) -> Int {
        store.items.filter { $0.group == name }.count
    }

    @ViewBuilder private func deleteCard(_ name: String) -> some View {
        let n = itemCount(name)
        if n == 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Delete “\(name)”?").font(.system(size: 13.5, weight: .semibold))
                Text("It has no to-dos.").font(.system(size: 12)).foregroundStyle(Theme.muted)
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
        } else {
            GroupChoiceCard(
                title: "Delete “\(name)”?",
                subtitle: "Move its \(n) to-do\(n == 1 ? "" : "s") to:",
                choices: deleteChoices(for: name),
                active: deleteTarget,
                hint: "↑↓ choose · ⏎ delete · Esc cancel",
                onPick: { deleteTarget = $0; confirmDelete() }
            )
        }
    }

    private func startDelete() {
        guard let g = current else { return }
        deleteTarget = 0
        error = ""
        deleting = g.name
    }

    private func confirmDelete() {
        guard let name = deleting else { return }
        let choices = deleteChoices(for: name)
        let target = choices.indices.contains(deleteTarget) ? choices[deleteTarget].value : nil
        store.deleteGroup(name, moveItemsTo: target)
        deleting = nil
        cursor = max(0, min(cursor, store.groups.count - 1))
    }

    // MARK: Rename / create

    private func startRename() {
        guard let g = current else { return }
        creating = false
        draft = g.name
        error = ""
        renaming = g.name
        DispatchQueue.main.async { fieldFocused = true }
    }

    private func startCreate() {
        renaming = nil
        draft = ""
        error = ""
        creating = true
        DispatchQueue.main.async { fieldFocused = true }
    }

    private func commitEdit() {
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let old = renaming {
            guard store.renameGroup(old, to: name) else {
                error = name.isEmpty ? "A group needs a name." : "“\(name)” already exists."
                DispatchQueue.main.async { fieldFocused = true }
                return
            }
        } else if creating {
            if !name.isEmpty {
                if store.groups.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                    error = "“\(name)” already exists."
                    DispatchQueue.main.async { fieldFocused = true }
                    return
                }
                store.addGroup(named: name)
                cursor = store.groups.count - 1
            }
        }
        endEdit()
    }

    private func endEdit() {
        renaming = nil
        creating = false
        error = ""
        state.requestFocus()
    }

    // MARK: Keys

    private func escape() {
        if editing { endEdit() }
        else if deleting != nil { deleting = nil }
        else { state.goHome(highlight: 2) }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        // While a name field is open, let it have every key except Esc.
        if editing {
            if press.key == .escape { endEdit(); return .handled }
            return .ignored
        }
        if press.modifiers.contains(.command) { return .ignored }

        if let name = deleting {
            var target = deleteTarget
            if itemCount(name) > 0, moveChoice(press, choices: deleteChoices(for: name), active: &target) {
                deleteTarget = target
                return .handled
            }
            switch press.key {
            case .return, .space: confirmDelete()
            case .escape: deleting = nil
            default: break
            }
            return .handled
        }

        let count = store.groups.count
        let option = press.modifiers.contains(.option)
        if press.isBackspace { startDelete(); return .handled }
        switch press.key {
        case .upArrow where option:
            if let g = current, cursor > 0 { store.moveGroup(g.name, by: -1); cursor -= 1 }
            return .handled
        case .downArrow where option:
            if let g = current, cursor < count - 1 { store.moveGroup(g.name, by: 1); cursor += 1 }
            return .handled
        case .upArrow: cursor = max(0, cursor - 1); return .handled
        case .downArrow: cursor = min(max(count - 1, 0), cursor + 1); return .handled
        case .return: startRename(); return .handled
        case .escape: state.goHome(highlight: 2); return .handled
        default: break
        }
        switch press.characters.lowercased() {
        case "r": startRename()
        case "n": startCreate()
        case "c": if let g = current { store.cycleGroupColor(g.name, by: press.modifiers.contains(.shift) ? -1 : 1) }
        default: return .ignored
        }
        return .handled
    }
}
