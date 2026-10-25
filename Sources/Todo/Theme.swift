import AppKit
import SwiftUI
import TodoCore

/// Warm paper and sumi ink, the same family as the home screen.
/// Each colour has a light and a dark value and follows the window's
/// appearance (see `Appearance`).
enum Theme {
    static let ink = Color(light: "#2C2824", dark: "#E8E3DA")
    static let ink2 = Color(light: "#4A453E", dark: "#C9C2B6")
    static let muted = Color(light: "#6A645C", dark: "#A8A196")
    static let faint = Color(light: "#8F877C", dark: "#7A746A")
    static let line = Color(light: "#DDD6CC", dark: "#3A3631")
    static let border = Color(light: "#D4CBBF", dark: "#4A453E")
    static let ground = Color(light: "#F4F1EB", dark: "#171614")
    static let surface = Color(light: "#FBF9F5", dark: "#24211D")
    static let column = Color(light: "#E8E2D8", dark: "#100E0C")
    /// Warm off-white in dark, warm charcoal in light (Enso).
    static let accent = Color(light: "#2A2925", dark: "#ECE8DF")
    static let accentSoft = Color(light: "#ECE9E2", dark: "#3F3830")
    static let cursor = Color(light: "#E8E5DE", dark: "#2B2A27")
    /// Faint warm glow behind the breathing ring.
    static let glow = Color(light: "#2A2925", dark: "#ECE8DF", lightOpacity: 0.08, darkOpacity: 0.14)
    static let sun = Color(light: "#B45309", dark: "#E8A13A")
    static let sunSoft = Color(light: "#FDF1E3", dark: "#3A2A16")
    static let sunInk = Color(light: "#8A3B06", dark: "#F5C07A")
    static let overdue = Color(light: "#B42318", dark: "#F07065")

    /// Outline of popovers, buttons and idle fields.
    static let stroke = Color(light: "#C9C0B3", dark: "#564F47")
    /// Idle ring of the title field; days outside the shown month.
    static let dim = Color(light: "#B7AFA3", dark: "#6B645B")
    /// Empty check circle and an unset Today sun.
    static let hollow = Color(light: "#A3998C", dark: "#7A7368")
    static let disabled = Color(light: "#B0A89C", dark: "#6B645B")
    static let doneInk = Color(light: "#7A7368", dark: "#8A8378")
    /// Track behind the Today / All / Board tabs.
    static let segment = Color(light: "#EBE6DE", dark: "#100E0C")
    /// Dot for a to-do that has no group.
    static let ungroupedHex = TodoGroup.ungroupedHex
    /// Text and marks on an `accent` fill.
    static let onAccent = Color(light: "#FFFFFF", dark: "#171614")
    static let onAccentLine = Color(light: "#8C887F", dark: "#6B675E")
    static let accentDisabled = Color(light: "#B8B4AB", dark: "#4A4843")
    /// Text on an `ink` fill.
    static let onInk = Color(light: "#FBF9F5", dark: "#171614")
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
