import SwiftUI
import TodoCore

struct ViewPickerView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: Store
    @Local private var index = 0

    private struct Row {
        let icon: String
        let title: String
        let subtitle: String
        let key: String
        let open: () -> Void
    }

    private var rows: [Row] {
        [
            Row(icon: "sun.max", title: "Today", subtitle: "\(store.todayOpen.count) left on your list", key: "T") {
                state.openList(.today)
            },
            Row(icon: "list.bullet", title: "All to-dos", subtitle: "\(store.open.count) open, by date", key: "A") {
                state.openList(.all)
            },
            Row(icon: "rectangle.split.3x1", title: "Board", subtitle: "\(store.groups.count) groups as columns", key: "B") {
                state.openList(.board)
            },
            Row(icon: "circle.grid.2x2", title: "Groups", subtitle: "Rename, recolour, reorder, delete", key: "G") {
                state.go(.groups)
            },
        ]
    }

    var body: some View {
        let rows = rows
        VStack(spacing: 0) {
            HeaderBar(onBack: { state.goHome(highlight: 2) }) {
                Text("View").font(.system(size: 14, weight: .semibold))
            } trailing: {
                HintText(text: "↑↓ move · ⏎ open · Esc back")
            }
            VStack(spacing: 8) {
                ForEach(rows.indices, id: \.self) { i in
                    OptionRow(icon: rows[i].icon, title: rows[i].title, subtitle: rows[i].subtitle,
                              key: rows[i].key, highlighted: index == i, height: 52)
                        .onTapGesture { rows[i].open() }
                }
            }
            .padding(12)
            Spacer(minLength: 0)
        }
        .grabsFocus()
        .onKeyPress(phases: .down) { press in
            let n = rows.count
            switch press.key {
            case .upArrow: index = (index + n - 1) % n; return .handled
            case .downArrow: index = (index + 1) % n; return .handled
            case .return, .space: rows[index].open(); return .handled
            case .escape: state.goHome(highlight: 2); return .handled
            default: break
            }
            let ch = press.characters.uppercased()
            guard let row = rows.first(where: { $0.key == ch }) else { return .ignored }
            row.open()
            return .handled
        }
    }
}
