import SwiftUI
import TodoCore

/// Today / All / Board. A highlighted cursor row moves with ↑↓; Space marks
/// done and T toggles Today, so you never need to Tab through rows.
struct ListsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store
    @Local private var cursor: UUID? = nil

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
        cols.append(Column(id: "", name: "No group", hex: "#B9BFC9", items: open.filter { $0.group == nil }))
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
            }
            HStack {
                HintText(text: state.listTab == .board
                         ? "↑↓ card · ←→ column · Space done · T today · Esc home"
                         : "↑↓ move · Space done · T today · 1–3 view · Esc home")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(Theme.surface)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .grabsFocus()
        .onKeyPress(phases: .down) { handle($0) }
    }

    // MARK: Header

    private var header: some View {
        HeaderBar(onBack: { state.goHome(highlight: 2) }) {
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
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#EEF0F3")))
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
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#C9CED6"), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private func row(_ item: TodoItem, isCursor: Bool) -> some View {
        let kind = DayKey.kind(item.date, today: store.today)
        return HStack(spacing: 2) {
            Button { select(item.id); store.toggleDone(item.id) } label: {
                CheckCircle(done: item.done).frame(width: 30, height: 30).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.done ? "Mark not done" : "Mark done")

            Dot(hex: store.color(forGroup: item.group))
                .padding(.trailing, 6)
                .help(item.group ?? "No group")
            Text(item.title)
                .font(.system(size: 13.5))
                .strikethrough(item.done)
                .foregroundStyle(item.done ? Color(hex: "#6B717D") : Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Text(DayKey.shortLabel(item.date, today: store.today))
                .font(Theme.mono(11, kind == .overdue || kind == .today ? .medium : .regular))
                .foregroundStyle(Theme.dateColor(kind))
            sunButton(item, size: 28)
        }
        .padding(.trailing, 2)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 7).fill(isCursor ? Theme.cursor : .clear))
        .contentShape(Rectangle())
        .onTapGesture { select(item.id) }
    }

    private func sunButton(_ item: TodoItem, size: CGFloat) -> some View {
        Button { select(item.id); store.toggleToday(item.id) } label: {
            Image(systemName: "sun.max")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(item.onToday ? Theme.sun : Color(hex: "#9AA0AA"))
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
                            Dot(hex: col.hex)
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
                Text(item.title).font(.system(size: 12.5)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(DayKey.shortLabel(item.date, today: store.today))
                        .font(Theme.mono(10.5, kind == .overdue ? .medium : .regular))
                        .foregroundStyle(Theme.dateColor(kind))
                    Spacer(minLength: 0)
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

    private func select(_ id: UUID) { cursor = id }

    private func switchTab(_ tab: ListTab) {
        state.listTab = tab
        cursor = nil
    }

    private func move(_ delta: Int) {
        let f = flat
        guard !f.isEmpty else { return }
        let i = max(0, min(f.count - 1, cursorIndex + delta))
        cursor = f[i].id
    }

    private func jumpColumn(_ delta: Int) {
        let cols = columns
        let id = currentId
        let col = cols.firstIndex { c in c.items.contains { $0.id == id } } ?? 0
        var c = col + delta
        while cols.indices.contains(c) {
            if let first = cols[c].items.first { cursor = first.id; return }
            c += delta
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

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        switch press.key {
        case .escape: state.goHome(highlight: 2); return .handled
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
        default: return .ignored
        }
        return .handled
    }
}
