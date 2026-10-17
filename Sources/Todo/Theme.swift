import AppKit
import SwiftUI
import TodoCore

/// Colours and type from the prototype. Each colour has a light and a dark
/// value and follows the window's appearance (see `Appearance`).
enum Theme {
    static let ink = Color(light: "#16181D", dark: "#ECEEF2")
    static let ink2 = Color(light: "#3F4450", dark: "#C4C8D0")
    static let muted = Color(light: "#5B616E", dark: "#9AA0AB")
    static let faint = Color(light: "#8A909C", dark: "#737985")
    static let line = Color(light: "#DDE1E6", dark: "#2C3039")
    static let border = Color(light: "#D5D9DF", dark: "#3A3F49")
    static let ground = Color(light: "#F4F5F7", dark: "#15171B")
    static let surface = Color(light: "#FFFFFF", dark: "#1F2227")
    static let column = Color(light: "#E7EAEE", dark: "#101215")
    static let accent = Color(light: "#2B59C3", dark: "#4A78DE")
    static let accentSoft = Color(light: "#E8EEFB", dark: "#1F2B45")
    static let cursor = Color(light: "#E3E9F8", dark: "#263452")
    static let sun = Color(light: "#B45309", dark: "#E8A13A")
    static let sunSoft = Color(light: "#FDF1E3", dark: "#3A2A16")
    static let sunInk = Color(light: "#8A3B06", dark: "#F5C07A")
    static let overdue = Color(light: "#B42318", dark: "#F07065")

    /// Outline of popovers, buttons and idle fields.
    static let stroke = Color(light: "#C9CED6", dark: "#454B56")
    /// Idle ring of the title field; days outside the shown month.
    static let dim = Color(light: "#B9BFC9", dark: "#555B66")
    /// Empty check circle and an unset Today sun.
    static let hollow = Color(light: "#9AA0AA", dark: "#6E7480")
    static let disabled = Color(light: "#A9AEB8", dark: "#555B66")
    static let doneInk = Color(light: "#6B717D", dark: "#7C828E")
    /// Track behind the Today / All / Board tabs.
    static let segment = Color(light: "#EEF0F3", dark: "#111316")
    /// Text and marks on an `accent` fill.
    static let onAccent = Color.white
    static let onAccentLine = Color(light: "#8FA6E0", dark: "#A9C0F5")
    static let accentDisabled = Color(light: "#9DB0E2", dark: "#34466E")
    /// Text on an `ink` fill.
    static let onInk = Color(light: "#FFFFFF", dark: "#15171B")
    static let sunLine = Color(light: "#F0C48E", dark: "#8A5A1F")
    /// Dims the screen behind a modal card.
    static let scrim = Color(light: "#000000", dark: "#000000", lightOpacity: 0.06, darkOpacity: 0.35)

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
        self.init(nsColor: NSColor(hex: hex))
    }

    /// A colour that switches with the light/dark appearance it's drawn in.
    init(light: String, dark: String, lightOpacity: CGFloat = 1, darkOpacity: CGFloat = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(hex: dark, alpha: darkOpacity)
                : NSColor(hex: light, alpha: lightOpacity)
        })
    }
}

extension NSColor {
    convenience init(hex: String, alpha: CGFloat = 1) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(
            srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// The app's light/dark setting, chosen from the menu bar menu.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Match System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
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

/// A group's colour dot, or its emoji on a light tint of that colour.
struct GroupMark: View {
    let hex: String
    var emoji: String? = nil
    var dotSize: CGFloat = 7

    var body: some View {
        if let emoji, let mark = TodoGroup.normalizedEmoji(emoji) {
            let box = max(dotSize + 6, 15)
            Text(mark)
                .font(.system(size: box * 0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: box, height: box)
                .background(Circle().fill(Color(hex: hex).opacity(0.2)))
        } else {
            Dot(hex: hex, size: dotSize)
        }
    }
}

/// The round done/not-done mark.
struct CheckCircle: View {
    let done: Bool
    var size: CGFloat = 16
    var body: some View {
        ZStack {
            Circle()
                .fill(done ? Theme.accent : Theme.surface)
                .overlay(Circle().stroke(done ? Theme.accent : Theme.hollow, lineWidth: 1.5))
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Header bar with optional back arrow.
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
