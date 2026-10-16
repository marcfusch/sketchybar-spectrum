import AppKit

/// Transparent, click through window that sits right above the SketchyBar window.
/// Always ordered in (hidden through alpha only) so it never leaves its sticky space.
final class OverlayWindow: NSWindow {
    init(content: NSView) {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        contentView = content
        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func pin() {
        orderFrontRegardless()
        StickySpace.attach(self)
    }

    func fade(in show: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            animator().alphaValue = show ? 1 : 0
        }
    }
}
