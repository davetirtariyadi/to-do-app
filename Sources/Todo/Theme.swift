import SwiftUI
import TodoCore

/// Colours and type from the prototype.
enum Theme {
    static let ink = Color(hex: "#16181D")
    static let ink2 = Color(hex: "#3F4450")
    static let muted = Color(hex: "#5B616E")
    static let faint = Color(hex: "#8A909C")
    static let line = Color(hex: "#DDE1E6")
    static let border = Color(hex: "#D5D9DF")
    static let ground = Color(hex: "#F4F5F7")
    static let surface = Color.white
    static let column = Color(hex: "#E7EAEE")
    static let accent = Color(hex: "#2B59C3")
    static let accentSoft = Color(hex: "#E8EEFB")
    static let cursor = Color(hex: "#E3E9F8")
    static let sun = Color(hex: "#B45309")
    static let sunSoft = Color(hex: "#FDF1E3")
    static let sunInk = Color(hex: "#8A3B06")
    static let overdue = Color(hex: "#B42318")

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func dateColor(_ kind: DayKey.Kind) -> Color {
        switch kind {
        case .overdue: return overdue
        case .today: return ink
        case .tomorrow: return ink2
        default: return muted
        }
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension KeyPress {
    /// The Backspace key arrives as U+007F on macOS, which `.delete` (U+0008)
    /// doesn't match, so check both plus forward-delete.
    var isBackspace: Bool {
        key == .delete || key == .deleteForward || characters == "\u{7F}" || characters == "\u{8}"
    }
}

// MARK: - Small shared pieces

/// A keyboard key hint, e.g. [A].
struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.mono(11))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border))
    }
}

struct Dot: View {
    let hex: String
    var size: CGFloat = 7
    var body: some View {
        Circle().fill(Color(hex: hex)).frame(width: size, height: size)
    }
}

/// The round done/not-done mark.
struct CheckCircle: View {
    let done: Bool
    var size: CGFloat = 16
    var body: some View {
        ZStack {
            Circle()
                .fill(done ? Theme.accent : Color.white)
                .overlay(Circle().stroke(done ? Theme.accent : Color(hex: "#9AA0AA"), lineWidth: 1.5))
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

/// White header bar with optional back arrow.
struct HeaderBar<Leading: View, Trailing: View>: View {
    var onBack: (() -> Void)?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back to home (Esc)")
            }
            leading
            Spacer(minLength: 4)
            trailing
        }
        .padding(.leading, onBack == nil ? 16 : 6)
        .padding(.trailing, 8)
        .frame(height: 44)
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

struct HintText: View {
    let text: String
    var body: some View {
        Text(text).font(Theme.mono(10.5)).foregroundStyle(Theme.muted).lineLimit(1)
    }
}

/// The "keep window on top" pin.
struct PinButton: View {
    @EnvironmentObject var controller: AppController
    var body: some View {
        Button { controller.pinned.toggle() } label: {
            Image(systemName: controller.pinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(controller.pinned ? Theme.accent : Theme.faint)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7).fill(controller.pinned ? Theme.accentSoft : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(controller.pinned ? "Keep on top: on" : "Keep on top: off")
    }
}
