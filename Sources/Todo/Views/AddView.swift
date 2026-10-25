import AppKit
import SwiftUI
import TodoCore

private enum AddField: Hashable {
    case title, group, newGroup, date, today, add
}

private struct GroupOption: Identifiable {
    let id: Int
    let label: String
    let hex: String
    let value: String?
    let isNew: Bool
}

/// Type → Tab → Group → Date → Today → Add. The pickers keep focus on their
/// button and handle the arrow keys themselves, like the prototype.
struct AddView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store

    @FocusState private var focus: AddField?
    @Local private var title = ""
    @Local private var group: String? = nil
    @Local private var date: String? = nil
    @Local private var onToday = false
    @Local private var note = ""
    /// Set when this Add was opened from a note. Cleared once that note is deleted.
    @Local private var promotingNote: UUID? = nil
    /// Where to go back when this Add came from a note. Nil means Home.
    @Local private var backTo: Screen? = nil

    @Local private var groupOpen = false
    @Local private var groupActive = 0
    @Local private var newGroupMode = false
    @Local private var newGroupName = ""

    @Local private var calOpen = false
    @Local private var calCursor = ""

    private var today: String { store.today }

    private var groupOptions: [GroupOption] {
        var opts = [GroupOption(id: 0, label: "No group", hex: "#B9BFC9", value: nil, isNew: false)]
        for (i, g) in store.groups.enumerated() {
            opts.append(GroupOption(id: i + 1, label: g.name, hex: g.colorHex, value: g.name, isNew: false))
        }
        opts.append(GroupOption(id: opts.count, label: "New group…", hex: "#00000000", value: nil, isNew: true))
        return opts
    }

    private var focusOrder: [AddField] {
        [.title, newGroupMode ? .newGroup : .group, .date, .today, .add]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                HeaderBar(onBack: { leave() }) {
                    Text("Add to-do").font(.system(size: 14, weight: .semibold))
                } trailing: {
                    HintText(text: "Esc back")
                }

                VStack(alignment: .leading, spacing: 10) {
                    titleField
                    HStack(spacing: 6) {
                        if newGroupMode { newGroupField } else { groupButton }
                        dateButton
                        todayButton
                    }
                    .zIndex(2)

                    if !note.isEmpty {
                        Text(note).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    addButton
                    HintText(text: "Tab next · ⏎ add · ⇧⏎ add another")
                        .frame(maxWidth: .infinity)
                }
                .padding(12)
            }

            if calOpen {
                CalendarPanel(
                    cursor: calCursor,
                    selected: date,
                    today: today,
                    pick: { pickDate($0) },
                    shiftMonth: { calCursor = DayKey.addMonths(calCursor, $0) }
                )
                .padding(.top, 48)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .zIndex(10)
            }
        }
        .onKeyPress(phases: .down) { handleContainer($0) }
        .onAppear {
            if let draft = state.consumeAddDraft() {
                title = draft.title
                promotingNote = draft.noteID
                backTo = draft.returnTo
            }
            DispatchQueue.main.async { focus = .title }
        }
        .onChange(of: state.focusTick) { focus = .title }
        .onChange(of: state.escapeTick) { handleEscape() }
        .onChange(of: focus) { old, new in
            if new != .group { groupOpen = false }
            if new != .date { calOpen = false }
            if old == .newGroup, new != .newGroup, newGroupMode { commitNewGroup(refocus: false) }
        }
    }

    // MARK: Fields

    private var titleField: some View {
        TextField("What needs doing?", text: $title)
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
            .overlay(fieldRing(.title, idle: Theme.dim, radius: 9))
            .focused($focus, equals: .title)
            .onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.command) { return .ignored }
                submit(stay: press.modifiers.contains(.shift))
                return .handled
            }
            .onSubmit { submit(stay: false) }
            .onChange(of: title) { _, new in if !new.isEmpty { note = "" } }
    }

    private var groupButton: some View {
        let hex = store.groups.first { $0.name == group }?.colorHex ?? "#B9BFC9"
        return pickerFace(width: 128, field: .group, isSet: group != nil) {
            Dot(hex: hex)
            Text(group ?? "No group").lineLimit(1)
        }
        .onTapGesture { focus = .group; groupOpen ? (groupOpen = false) : openGroup() }
        .onKeyPress(phases: .down) { groupKey($0) }
        .overlay(alignment: .topLeading) {
            if groupOpen { groupList.offset(y: 38) }
        }
    }

    private var groupList: some View {
        let opts = groupOptions
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(opts) { opt in
                    HStack(spacing: 8) {
                        Circle().fill(opt.isNew ? .clear : Color(hex: opt.hex)).frame(width: 7, height: 7)
                        Text(opt.label).font(.system(size: 13))
                        Spacer(minLength: 0)
                        if !opt.isNew && opt.value == group {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: 6).fill(opt.id == groupActive ? Theme.accentSoft : .clear))
                    .contentShape(Rectangle())
                    .onTapGesture { chooseGroup(opt.id) }
                }
            }
            .padding(4)
        }
        .frame(width: 168, height: min(CGFloat(opts.count) * 28 + 8, 152))
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.14), radius: 10, y: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.stroke))
    }

    private var newGroupField: some View {
        TextField("Group name", text: $newGroupName)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(width: 128, height: 34)
            .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.accent, lineWidth: 1.5))
            .focused($focus, equals: .newGroup)
            .onSubmit { commitNewGroup(refocus: true) }
            .onKeyPress(.escape) {
                newGroupMode = false
                focus = .group
                return .handled
            }
    }

    private var dateButton: some View {
        pickerFace(width: 130, field: .date, isSet: date != nil) {
            Image(systemName: "calendar").font(.system(size: 11))
            Text(DayKey.pickerLabel(date, today: today)).lineLimit(1)
        }
        .onTapGesture { focus = .date; calOpen ? (calOpen = false) : openCalendar() }
        .onKeyPress(phases: .down) { dateKey($0) }
    }

    private var todayButton: some View {
        HStack(spacing: 5) {
            Image(systemName: "sun.max").font(.system(size: 12, weight: .semibold))
            Text("Today").font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(onToday ? Theme.sunInk : Theme.muted)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 7).fill(onToday ? Theme.sunSoft : Theme.surface))
        .overlay(fieldRing(.today, idle: onToday ? Theme.sunLine : Theme.stroke, radius: 7))
        .contentShape(Rectangle())
        .focusable()
        .focused($focus, equals: .today)
        .focusEffectDisabled()
        .onTapGesture { focus = .today; onToday.toggle() }
        .onKeyPress(phases: .down) { press in
            guard press.key == .return || press.key == .space, !press.modifiers.contains(.command) else { return .ignored }
            onToday.toggle()
            return .handled
        }
        .accessibilityLabel("Add to Today")
        .accessibilityAddTraits(onToday ? .isSelected : [])
    }

    private var addButton: some View {
        let ready = !title.trimmingCharacters(in: .whitespaces).isEmpty
        return Text("Add")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 9).fill(ready ? Theme.accent : Theme.accentDisabled))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(focus == .add ? Theme.accent : .clear, lineWidth: 2)
                    .padding(-3)
            )
            .contentShape(Rectangle())
            .focusable()
            .focused($focus, equals: .add)
            .focusEffectDisabled()
            .onTapGesture { submit(stay: false) }
            .onKeyPress(phases: .down) { press in
                guard press.key == .return || press.key == .space, !press.modifiers.contains(.command) else { return .ignored }
                submit(stay: press.modifiers.contains(.shift))
                return .handled
            }
    }

    private func pickerFace<Content: View>(width: CGFloat, field: AddField, isSet: Bool,
                                           @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            content()
            Spacer(minLength: 0)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
        }
        .font(.system(size: 13))
        .foregroundStyle(isSet ? Theme.ink : Theme.muted)
        .padding(.horizontal, 10)
        .frame(width: width, height: 34)
        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface))
        .overlay(fieldRing(field, idle: isSet ? Theme.faint : Theme.stroke, radius: 7))
        .contentShape(Rectangle())
        .focusable()
        .focused($focus, equals: field)
        .focusEffectDisabled()
    }

    private func fieldRing(_ field: AddField, idle: Color, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .stroke(focus == field ? Theme.accent : idle, lineWidth: focus == field ? 2 : 1)
    }

    // MARK: Group picker

    private func openGroup() {
        groupActive = groupOptions.firstIndex { !$0.isNew && $0.value == group } ?? 0
        calOpen = false
        groupOpen = true
    }

    private func chooseGroup(_ index: Int) {
        let opts = groupOptions
        guard opts.indices.contains(index) else { return }
        groupOpen = false
        if opts[index].isNew {
            newGroupName = ""
            newGroupMode = true
            DispatchQueue.main.async { focus = .newGroup }
        } else {
            group = opts[index].value
            focus = .group
        }
    }

    private func commitNewGroup(refocus: Bool) {
        if let g = store.addGroup(named: newGroupName) { group = g.name }
        newGroupMode = false
        if refocus { DispatchQueue.main.async { focus = .group } }
    }

    private func groupKey(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        let count = groupOptions.count
        if !groupOpen {
            switch press.key {
            case .return, .space, .downArrow, .upArrow: openGroup(); return .handled
            default: return .ignored
            }
        }
        switch press.key {
        case .downArrow: groupActive = (groupActive + 1) % count; return .handled
        case .upArrow: groupActive = (groupActive - 1 + count) % count; return .handled
        case .return, .space: chooseGroup(groupActive); return .handled
        case .escape: groupOpen = false; return .handled
        case .tab: groupOpen = false; return .ignored
        default:
            guard let ch = press.characters.lowercased().first, ch.isLetter,
                  let i = groupOptions.firstIndex(where: { $0.label.lowercased().hasPrefix(String(ch)) })
            else { return .ignored }
            groupActive = i
            return .handled
        }
    }

    // MARK: Calendar

    private func openCalendar() {
        calCursor = date ?? today
        groupOpen = false
        calOpen = true
    }

    private func pickDate(_ value: String?) {
        date = value
        calOpen = false
        focus = .date
    }

    private func dateKey(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        if press.isBackspace {
            if calOpen { pickDate(nil) } else { date = nil }
            return .handled
        }
        if !calOpen {
            switch press.key {
            case .return, .space, .downArrow, .upArrow: openCalendar(); return .handled
            default: return .ignored
            }
        }
        switch press.key {
        case .leftArrow: calCursor = DayKey.addDays(calCursor, -1)
        case .rightArrow: calCursor = DayKey.addDays(calCursor, 1)
        case .upArrow: calCursor = DayKey.addDays(calCursor, -7)
        case .downArrow: calCursor = DayKey.addDays(calCursor, 7)
        case .pageUp: calCursor = DayKey.addMonths(calCursor, -1)
        case .pageDown: calCursor = DayKey.addMonths(calCursor, 1)
        case .return, .space: pickDate(calCursor)
        case .escape: calOpen = false
        case .tab: calOpen = false; return .ignored
        default:
            if press.characters.lowercased() == "t" { calCursor = today } else { return .ignored }
        }
        return .handled
    }

    // MARK: Container keys, submit, escape

    private func handleContainer(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .return && press.modifiers.contains(.command) {
            submit(stay: press.modifiers.contains(.shift))
            return .handled
        }
        if press.key == .tab {
            let order = focusOrder
            let i = focus.flatMap { order.firstIndex(of: $0) } ?? 0
            let step = press.modifiers.contains(.shift) ? -1 : 1
            focus = order[(i + step + order.count) % order.count]
            return .handled
        }
        if press.key == .escape {
            handleEscape()
            return .handled
        }
        return .ignored
    }

    private func handleEscape() {
        if calOpen { calOpen = false; focus = .date }
        else if groupOpen { groupOpen = false }
        else if newGroupMode { newGroupMode = false; focus = .group }
        else { leave() }
    }

    /// A note's Add returns to the list it came from. A normal Add returns home.
    private func leave() {
        if let backTo {
            state.go(backTo)
        } else {
            state.goHome(highlight: 0)
        }
    }

    private func submit(stay: Bool) {
        if newGroupMode { commitNewGroup(refocus: false) }
        guard let item = store.add(title: title, group: group, date: date, onToday: onToday) else {
            NSSound.beep()
            focus = .title
            return
        }
        if let id = promotingNote {
            store.deleteNote(id)
            promotingNote = nil
        }
        var bits: [String] = []
        if let g = item.group { bits.append(g) }
        if item.date != nil { bits.append(DayKey.pickerLabel(item.date, today: today)) }
        if item.onToday { bits.append("on Today") }
        let message = "Added “\(item.title)”" + (bits.isEmpty ? "" : " · " + bits.joined(separator: " · "))

        if stay {
            title = ""
            group = nil
            date = nil
            onToday = false
            groupOpen = false
            calOpen = false
            note = message
            focus = .title
        } else {
            state.showToast(message)
            leave()
        }
    }
}
