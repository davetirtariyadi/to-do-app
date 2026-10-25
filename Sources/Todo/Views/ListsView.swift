import SwiftUI
import TodoCore

/// Today / All / Board. A highlighted cursor row moves with ↑↓; Space marks
/// done, T toggles Today, R renames and ⌫ deletes, so you never need to Tab
/// through rows.
struct ListsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store
    @Local private var cursor: UUID? = nil
    /// On the Board, the empty column ←→ landed on. Set, it stands in for the cursor.
    @Local private var emptyColumn: String? = nil
    /// The "Move to group" card opened with G.
    @Local private var chooserOpen = false
    @Local private var chooserActive = 0
    @Local private var renaming: UUID? = nil
    @Local private var draft = ""
    @Local private var error = ""
    @Local private var deleting: UUID? = nil
    @FocusState private var fieldFocused: Bool

    private var editing: Bool { renaming != nil }

    private struct Section: Identifiable {
        let id: String
        let title: String
        let items: [TodoItem]
    }

    private struct Column: Identifiable {
        let id: String
        let name: String
        let hex: String
        let items: [TodoItem]
    }

    private var sections: [Section] {
        switch state.listTab {
        case .today:
            let mine = store.todayOpen + store.todayDone
            var out = [Section(id: "today", title: "Today · \(store.todayDone.count) of \(mine.count) done", items: mine)]
            let due = store.dueNotOnToday
            if !due.isEmpty { out.append(Section(id: "due", title: "Due now · not on Today", items: due)) }
            return out
        case .all:
            var out = [Section(id: "open", title: "Open · \(store.open.count)", items: store.open)]
            if !store.done.isEmpty { out.append(Section(id: "done", title: "Done · \(store.done.count)", items: store.done)) }
            return out
        case .board:
            return []
        }
    }

    private var columns: [Column] {
        let open = store.open
        var cols = store.groups.map { g in
            Column(id: g.name, name: g.name, hex: g.colorHex, items: open.filter { $0.group == g.name })
        }
        cols.append(Column(id: "", name: "No group", hex: Theme.ungroupedHex, items: open.filter { $0.group == nil }))
        return cols
    }

    /// Every item in on-screen order, which is what ↑↓ walks through.
    private var flat: [TodoItem] {
        state.listTab == .board ? columns.flatMap(\.items) : sections.flatMap(\.items)
    }

    private var cursorIndex: Int {
        flat.firstIndex { $0.id == cursor } ?? 0
    }

    private var currentId: UUID? {
        if state.listTab == .board && emptyColumn != nil { return nil }
        let f = flat
        return f.isEmpty ? nil : f[min(cursorIndex, f.count - 1)].id
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                Group {
                    if state.listTab == .board { board } else { rows }
                }
                .onChange(of: cursor) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id) } }
                }
                // Landing on an empty Board column scrolls it into view. Leaving one
                // scrolls back to the cursor card, which may not have changed.
                .onChange(of: emptyColumn) { _, col in
                    let target = col.map(AnyHashable.init) ?? cursor.map(AnyHashable.init)
                    if let target { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(target) } }
                }
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
                         : "↑↓ move · Space done · T today · G group · R rename · ⌫ delete · Esc")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(Theme.surface)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .overlay {
            if let id = deleting, let item = store.item(id) {
                ZStack {
                    Theme.scrim
                    deleteCard(item)
                }
            } else if chooserOpen, let id = currentId, let item = store.item(id) {
                ZStack {
                    Theme.scrim.onTapGesture { chooserOpen = false }
                    GroupChoiceCard(
                        title: "Move to group",
                        subtitle: item.title,
                        choices: groupChoices(for: item),
                        active: chooserActive,
                        hint: "↑↓ or letter · ⏎ move · Esc cancel",
                        onPick: { applyGroup($0) }
                    )
                }
            }
        }
        .grabsFocus()
        .onKeyPress(phases: .down) { handle($0) }
        .onChange(of: state.escapeTick) { escape() }
        .onChange(of: fieldFocused) { _, focused in
            // Clicking away from the title field saves it, like pressing Enter.
            if !focused && editing { commitEdit() }
        }
    }

    // MARK: Header

    private var header: some View {
        HeaderBar(onBack: { state.goHome(highlight: 3) }) {
            HStack(spacing: 2) {
                ForEach(ListTab.allCases, id: \.self) { tab in
                    let on = tab == state.listTab
                    Button { switchTab(tab) } label: {
                        HStack(spacing: 5) {
                            Text(tab.label).font(.system(size: 12.5, weight: .medium))
                            Text(tab.key).font(Theme.mono(10.5)).foregroundStyle(Theme.muted)
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
            Text(state.listTab == .today ? "\(store.todayOpen.count) left" : "\(store.open.count) open")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.muted)
                .padding(.trailing, 6)
        }
    }

    // MARK: Rows (Today, All)

    private var rows: some View {
        let current = currentId
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    Text(section.title.uppercased())
                        .font(.system(size: 10.5, weight: .semibold))
                        .kerning(0.6)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 6)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    ForEach(section.items) { item in
                        row(item, isCursor: item.id == current).id(item.id)
                    }
                }
                if flat.isEmpty {
                    Text(state.listTab == .today
                         ? "Nothing on Today yet. Press T on any to-do in All or Board to add it."
                         : "Nothing here yet. Press Esc, then A to add a to-do.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.muted)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private func row(_ item: TodoItem, isCursor: Bool) -> some View {
        let kind = DayKey.kind(item.date, today: store.today)
        // Only the row you're on grows. Rename stays a single field.
        let expands = isCursor && renaming != item.id
        return HStack(alignment: .top, spacing: 2) {
            Button { select(item.id); store.toggleDone(item.id) } label: {
                CheckCircle(done: item.done).frame(width: 30, height: 30).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.done ? "Mark not done" : "Mark done")
            .frame(height: 36)

            GroupMark(hex: store.color(forGroup: item.group), emoji: store.emoji(forGroup: item.group))
                .frame(minWidth: 14)
                .frame(height: 36)
                .contentShape(Rectangle())
                .padding(.trailing, 2)
                .onTapGesture { select(item.id); openChooser() }
                .help("\(item.group ?? "No group") — click or press G to change")
            if renaming == item.id {
                titleField(size: 13.5)
                    .frame(height: 36)
            } else {
                Text(item.title)
                    .font(.system(size: 13.5))
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? Theme.doneInk : Theme.ink)
                    .lineLimit(expands ? nil : 1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: expands)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            }
            Text(DayKey.shortLabel(item.date, today: store.today))
                .font(Theme.mono(11, kind == .overdue || kind == .today ? .medium : .regular))
                .foregroundStyle(Theme.dateColor(kind))
                .frame(height: 36)
            sunButton(item, size: 28)
                .frame(height: 36)
            iconButton("pencil", help: "Rename (R)") { select(item.id); startRename() }
                .frame(height: 36)
            iconButton("trash", help: "Delete (⌫)") { select(item.id); startDelete() }
                .frame(height: 36)
        }
        .padding(.trailing, 2)
        .frame(height: expands ? nil : 36)
        .background(RoundedRectangle(cornerRadius: 7).fill(isCursor ? Theme.cursor : .clear))
        .contentShape(Rectangle())
        .onTapGesture { select(item.id) }
        .animation(.easeOut(duration: 0.12), value: expands)
    }

    private func titleField(size: CGFloat) -> some View {
        TextField("To-do", text: $draft)
            .textFieldStyle(.plain)
            .font(.system(size: size))
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent, lineWidth: 1.5))
            .focused($fieldFocused)
            .onSubmit(commitEdit)
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

    private func sunButton(_ item: TodoItem, size: CGFloat) -> some View {
        Button { select(item.id); store.toggleToday(item.id) } label: {
            Image(systemName: "sun.max")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(item.onToday ? Theme.sun : Theme.hollow)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: 6).fill(item.onToday ? Theme.sunSoft : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.onToday ? "Remove from Today" : "Add to Today")
    }

    // MARK: Board

    private var board: some View {
        let current = currentId
        return ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(columns) { col in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            GroupMark(
                                hex: col.hex,
                                emoji: store.emoji(forGroup: col.id.isEmpty ? nil : col.name)
                            )
                            Text(col.name).font(.system(size: 12.5, weight: .semibold))
                            Spacer()
                            Text("\(col.items.count)").font(Theme.mono(11)).foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        ForEach(col.items) { item in
                            card(item, isCursor: item.id == current).id(item.id)
                        }
                        if col.items.isEmpty {
                            Text("Nothing open")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(6)
                    .frame(width: 164)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.column))
                    .overlay {
                        if emptyColumn == col.id {
                            RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 2)
                        }
                    }
                    .id(col.id)
                }
            }
            .padding(10)
        }
    }

    private func card(_ item: TodoItem, isCursor: Bool) -> some View {
        let kind = DayKey.kind(item.date, today: store.today)
        return HStack(alignment: .top, spacing: 0) {
            Button { select(item.id); store.toggleDone(item.id) } label: {
                CheckCircle(done: item.done, size: 14).frame(width: 26, height: 26).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                if renaming == item.id {
                    titleField(size: 12.5)
                } else {
                    Text(item.title)
                        .font(.system(size: 12.5))
                        .lineLimit(isCursor ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 0) {
                    Text(DayKey.shortLabel(item.date, today: store.today))
                        .font(Theme.mono(10.5, kind == .overdue ? .medium : .regular))
                        .foregroundStyle(Theme.dateColor(kind))
                    Spacer(minLength: 0)
                    if isCursor {
                        iconButton("pencil", help: "Rename (R)") { select(item.id); startRename() }
                        iconButton("trash", help: "Delete (⌫)") { select(item.id); startDelete() }
                    }
                    sunButton(item, size: 24)
                }
            }
            .padding(.top, 5)
        }
        .padding(.leading, 2)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isCursor ? Theme.accent : Theme.line, lineWidth: isCursor ? 2 : 1))
        .contentShape(Rectangle())
        .onTapGesture { select(item.id) }
    }

    // MARK: Keys

    private func select(_ id: UUID) {
        cursor = id
        emptyColumn = nil
    }

    private func switchTab(_ tab: ListTab) {
        if editing {
            commitEdit()
            if editing { return }
        }
        deleting = nil
        chooserOpen = false
        state.listTab = tab
        cursor = nil
        emptyColumn = nil
    }

    private func move(_ delta: Int) {
        if state.listTab == .board && emptyColumn != nil { return }
        let f = flat
        guard !f.isEmpty else { return }
        let i = max(0, min(f.count - 1, cursorIndex + delta))
        cursor = f[i].id
    }

    /// Steps one column left or right, stopping on empty columns too so the
    /// Board can scroll all the way across from the keyboard.
    private func jumpColumn(_ delta: Int) {
        let cols = columns
        let id = currentId
        let col = cols.firstIndex { $0.id == emptyColumn }
            ?? cols.firstIndex { c in c.items.contains { $0.id == id } }
            ?? (delta > 0 ? -1 : cols.count)
        let c = col + delta
        guard cols.indices.contains(c) else { return }
        if let first = cols[c].items.first {
            select(first.id)
        } else {
            emptyColumn = cols[c].id
        }
    }

    /// On the Board a finished card disappears, so the cursor moves to its neighbour first.
    private func toggleDoneAtCursor() {
        guard let id = currentId else { return }
        if state.listTab == .board {
            let f = flat
            let i = cursorIndex
            cursor = f.indices.contains(i + 1) ? f[i + 1].id : (i > 0 ? f[i - 1].id : nil)
        } else {
            cursor = id
        }
        store.toggleDone(id)
    }

    // MARK: Move to group

    private func groupChoices(for item: TodoItem) -> [GroupChoice] {
        [GroupChoice(label: "No group", value: nil, hex: Theme.ungroupedHex, isCurrent: item.group == nil)]
            + store.groups.map {
                GroupChoice(label: $0.name, value: $0.name, hex: $0.colorHex, isCurrent: item.group == $0.name, emoji: $0.emoji)
            }
    }

    private func openChooser() {
        guard !editing, let id = currentId, let item = store.item(id) else { return }
        chooserActive = groupChoices(for: item).firstIndex { $0.isCurrent } ?? 0
        chooserOpen = true
    }

    private func applyGroup(_ index: Int) {
        defer { chooserOpen = false }
        guard let id = currentId, let item = store.item(id) else { return }
        let choices = groupChoices(for: item)
        guard choices.indices.contains(index) else { return }
        cursor = id
        store.setGroup(id, choices[index].value)
    }

    // MARK: Rename / delete

    @ViewBuilder private func deleteCard(_ item: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Delete “\(item.title)”?")
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

    private func startRename() {
        guard !editing, let id = currentId, let item = store.item(id) else { return }
        chooserOpen = false
        deleting = nil
        draft = item.title
        error = ""
        renaming = id
        DispatchQueue.main.async { fieldFocused = true }
    }

    private func startDelete() {
        guard !editing, let id = currentId else { return }
        chooserOpen = false
        error = ""
        deleting = id
    }

    /// The deleted row disappears, so the cursor moves to its neighbour first,
    /// the same way marking done does on the Board.
    private func confirmDelete() {
        guard let id = deleting else { return }
        let f = flat
        let i = f.firstIndex { $0.id == id } ?? cursorIndex
        cursor = f.indices.contains(i + 1) ? f[i + 1].id : (i > 0 ? f[i - 1].id : nil)
        emptyColumn = nil
        store.delete(id)
        deleting = nil
    }

    private func commitEdit() {
        guard let id = renaming else { return }
        if store.rename(id, to: draft) {
            endEdit()
            return
        }
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = "A to-do needs a title."
            DispatchQueue.main.async { fieldFocused = true }
            return
        }
        endEdit()
    }

    private func endEdit() {
        renaming = nil
        error = ""
        state.requestFocus()
    }

    private func escape() {
        if editing { endEdit() }
        else if deleting != nil { deleting = nil }
        else if chooserOpen { chooserOpen = false }
        else { state.goHome(highlight: 3) }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        // While a title field is open, let it have every key except Esc.
        if editing {
            if press.key == .escape { escape(); return .handled }
            return .ignored
        }
        if press.modifiers.contains(.command) { return .ignored }
        if deleting != nil {
            switch press.key {
            case .return, .space: confirmDelete()
            case .escape: escape()
            default: break
            }
            return .handled
        }
        if chooserOpen {
            if let id = currentId, let item = store.item(id) {
                var active = chooserActive
                if moveChoice(press, choices: groupChoices(for: item), active: &active) {
                    chooserActive = active
                    return .handled
                }
            }
            switch press.key {
            case .return, .space: applyGroup(chooserActive)
            case .escape: escape()
            default: break
            }
            return .handled
        }
        if press.isBackspace { startDelete(); return .handled }
        switch press.key {
        case .escape: escape(); return .handled
        case .upArrow: move(-1); return .handled
        case .downArrow: move(1); return .handled
        case .leftArrow where state.listTab == .board: jumpColumn(-1); return .handled
        case .rightArrow where state.listTab == .board: jumpColumn(1); return .handled
        case .space, .return:
            toggleDoneAtCursor()
            return .handled
        default: break
        }
        switch press.characters.lowercased() {
        case "1": switchTab(.today)
        case "2": switchTab(.all)
        case "3": switchTab(.board)
        case "j": move(1)
        case "k": move(-1)
        case "x": toggleDoneAtCursor()
        case "t": if let id = currentId { cursor = id; store.toggleToday(id) }
        case "g": openChooser()
        case "r": startRename()
        default: return .ignored
        }
        return .handled
    }
}
