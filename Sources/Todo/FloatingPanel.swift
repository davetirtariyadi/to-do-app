import AppKit

/// Borderless, rounded panel that can float above other apps and still take
/// keyboard focus for typing.
final class FloatingPanel: NSPanel {
    /// Called when Esc reaches the window without a view handling it.
    var onEscape: (() -> Void)?

    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    func setPinned(_ pinned: Bool) {
        level = pinned ? .floating : .normal
        isFloatingPanel = pinned
    }

    /// Puts the window in the top-right corner of the main screen the first time.
    func placeDefault() {
        guard let screen = NSScreen.main else { center(); return }
        let vf = screen.visibleFrame
        setFrameOrigin(NSPoint(x: vf.maxX - frame.width - 24, y: vf.maxY - frame.height - 24))
    }
}
