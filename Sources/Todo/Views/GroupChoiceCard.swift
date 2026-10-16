import SwiftUI
import TodoCore

struct GroupChoice {
    let label: String
    let value: String?
    let hex: String
    let isCurrent: Bool
}

/// A floating "pick a group" card. It only draws and takes clicks; the screen
/// that shows it owns `active` and handles the keys.
struct GroupChoiceCard: View {
    let title: String
    let subtitle: String?
    let choices: [GroupChoice]
    let active: Int
    let hint: String
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(choices.indices, id: \.self) { i in
                            let c = choices[i]
                            HStack(spacing: 8) {
                                Dot(hex: c.hex)
                                Text(c.label).font(.system(size: 13))
                                Spacer(minLength: 0)
                                if c.isCurrent {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 28)
                            .background(RoundedRectangle(cornerRadius: 6).fill(i == active ? Theme.accentSoft : .clear))
                            .contentShape(Rectangle())
                            .onTapGesture { onPick(i) }
                            .id(i)
                        }
                    }
                }
                .frame(maxHeight: 148)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: active) { _, i in proxy.scrollTo(i) }
            }
            HintText(text: hint).padding(.horizontal, 6)
        }
        .padding(8)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#C9CED6")))
    }
}

/// Moves `active` with ↑↓ or a first letter. Returns true when the key was used.
func moveChoice(_ press: KeyPress, choices: [GroupChoice], active: inout Int) -> Bool {
    switch press.key {
    case .upArrow: active = (active - 1 + choices.count) % choices.count; return true
    case .downArrow: active = (active + 1) % choices.count; return true
    default:
        guard let ch = press.characters.lowercased().first, ch.isLetter,
              let i = choices.firstIndex(where: { $0.label.lowercased().hasPrefix(String(ch)) })
        else { return false }
        active = i
        return true
    }
}
