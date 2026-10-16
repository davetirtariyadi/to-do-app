import AppKit
import TodoCore

/// Developer aid, off unless TODO_SNAPSHOT_DIR is set: drives the real window
/// with synthetic key presses and saves a PNG of each step, then quits.
/// Run it with TODO_DATA_FILE pointing at a scratch file so real data is untouched:
///
///   TODO_DATA_FILE=/tmp/t.json TODO_SNAPSHOT_DIR=/tmp/shots build/Todo.app/Contents/MacOS/Todo
enum DevHarness {
    enum Step {
        case key(UInt16, String, NSEvent.ModifierFlags = [])
        case type(String)
        case snap(String)
    }

    // Virtual key codes.
    static let tab: UInt16 = 48, ret: UInt16 = 36, esc: UInt16 = 53, space: UInt16 = 49
    static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126

    static var scenario: [Step] {
        [
            .snap("01-home"),
            .type("a"),
            .snap("02-add"),
            .type("Renew passport"),
            .key(tab, "\t"),
            .key(ret, "\r"),
            .snap("03-group-open"),
            .key(down, "\u{F701}"),
            .key(ret, "\r"),
            .key(tab, "\t"),
            .key(ret, "\r"),
            .snap("04-calendar"),
            .key(right, "\u{F703}"),
            .key(right, "\u{F703}"),
            .key(ret, "\r"),
            .key(tab, "\t"),
            .key(space, " "),
            .snap("05-add-filled"),
            .key(ret, "\r", .command),
            .snap("06-home-toast"),
            .type("v"),
            .snap("07-view"),
            .type("t"),
            .snap("08-today"),
            .key(down, "\u{F701}"),
            .key(space, " "),
            .snap("09-today-marked"),
            .type("3"),
            .snap("10-board"),
            .key(esc, "\u{1B}"),
            .type("c"),
            .snap("11-catchup"),
            .key(right, "\u{F703}"),
            .snap("12-catchup-next"),
            // Groups screen: rename, recolour, reorder, delete, create.
            .key(esc, "\u{1B}"),
            .type("v"),
            .snap("13-view"),
            .type("g"),
            .key(down, "\u{F701}"),
            .snap("14-groups"),
            .key(ret, "\r"),
            .key(backspace, "\u{7F}"), .key(backspace, "\u{7F}"), .key(backspace, "\u{7F}"), .key(backspace, "\u{7F}"),
            .type("House"),
            .snap("15-renaming"),
            .key(ret, "\r"),
            .type("c"),
            .key(up, "\u{F700}", .option),
            .snap("16-renamed-moved"),
            .key(down, "\u{F701}"),
            .key(down, "\u{F701}"),
            .key(backspace, "\u{7F}"),
            .snap("17-delete-card"),
            .key(down, "\u{F701}"),
            .key(ret, "\r"),
            .type("n"),
            .type("Garden"),
            .key(ret, "\r"),
            .snap("18-after-delete-create"),
            // Move a to-do to another group from the Today list.
            .key(esc, "\u{1B}"),
            .type("v"),
            .type("t"),
            .type("g"),
            .snap("19-move-chooser"),
            .type("g"),
            .key(ret, "\r"),
            .snap("20-moved"),
        ]
    }

    static let backspace: UInt16 = 51

    static func runIfRequested(controller: AppController, window: NSWindow) {
        guard let dir = ProcessInfo.processInfo.environment["TODO_SNAPSHOT_DIR"] else { return }
        let out = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        seedSampleData(controller.store)

        let steps = scenario
        func run(_ i: Int) {
            guard i < steps.count else {
                controller.store.saveNow()
                NSApp.terminate(nil)
                return
            }
            switch steps[i] {
            case let .key(code, chars, mods): press(window, code: code, chars: chars, mods: mods)
            case let .type(text): for ch in text { press(window, code: 0, chars: String(ch), mods: []) }
            case let .snap(name): snapshot(window, to: out.appendingPathComponent(name + ".png"))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { run(i + 1) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { run(0) }
    }

    private static func seedSampleData(_ store: Store) {
        guard store.items.isEmpty else { return }
        let t = store.today
        store.add(title: "Reply to Q4 planning thread", group: "Work", date: t, onToday: true)
        store.add(title: "Review onboarding doc draft", group: "Work", date: DayKey.addDays(t, 1), onToday: true)
        store.add(title: "Book dentist appointment", group: "Home", date: nil, onToday: true)
        store.add(title: "Renew car registration", group: "Errands", date: DayKey.addDays(t, -2), onToday: false)
        store.add(title: "Order a new desk lamp", group: "Home", date: DayKey.addDays(t, 5), onToday: false)
        store.add(title: "Sort out travel receipts", group: nil, date: nil, onToday: false)
    }

    private static func press(_ window: NSWindow, code: UInt16, chars: String, mods: NSEvent.ModifierFlags) {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            guard let event = NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: mods, timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: chars,
                charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code
            ) else { continue }
            window.sendEvent(event)
        }
    }

    private static func snapshot(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
