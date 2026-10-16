import SwiftUI
import TodoCore

struct ViewPickerView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store
    @Local private var index = 0

    private var rows: [(tab: ListTab, icon: String, title: String, subtitle: String, key: String)] {
        [
            (.today, "sun.max", "Today", "\(store.todayOpen.count) left on your list", "T"),
            (.all, "list.bullet", "All to-dos", "\(store.open.count) open, by date", "A"),
            (.board, "rectangle.split.3x1", "Board", "\(store.groups.count) groups as columns", "B"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(onBack: { state.goHome(highlight: 2) }) {
                Text("View").font(.system(size: 14, weight: .semibold))
            } trailing: {
                HintText(text: "↑↓ move · ⏎ open · Esc back")
            }
            VStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    OptionRow(icon: row.icon, title: row.title, subtitle: row.subtitle, key: row.key,
                              highlighted: index == i)
                        .onTapGesture { state.openList(row.tab) }
                }
            }
            .padding(12)
            Spacer(minLength: 0)
        }
        .grabsFocus()
        .onKeyPress(phases: .down) { press in
            switch press.key {
            case .upArrow: index = (index + 2) % 3; return .handled
            case .downArrow: index = (index + 1) % 3; return .handled
            case .return, .space: state.openList(rows[index].tab); return .handled
            case .escape: state.goHome(highlight: 2); return .handled
            default: break
            }
            switch press.characters.lowercased() {
            case "t": state.openList(.today)
            case "a": state.openList(.all)
            case "b": state.openList(.board)
            default: return .ignored
            }
            return .handled
        }
    }
}
