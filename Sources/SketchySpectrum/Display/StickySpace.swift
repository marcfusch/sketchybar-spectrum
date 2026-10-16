import AppKit

/// Moves a window into a private space shown above every desktop, like SketchyBar's `sticky=on`,
/// so it stays put while swiping between desktops. Private SkyLight API, resolved at runtime.
enum StickySpace {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> UInt64
    private typealias SetAbsoluteLevel = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindows = @convention(c) (Int32, UInt64, CFArray, Int32) -> Int32

    private static let skylight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func symbol<T>(_ name: String, as _: T.Type) -> T? {
        guard let skylight, let sym = dlsym(skylight, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    private static let space: UInt64? = {
        guard let cid = symbol("SLSMainConnectionID", as: MainConnection.self)?(),
              let create = symbol("SLSSpaceCreate", as: SpaceCreate.self),
              let setLevel = symbol("SLSSpaceSetAbsoluteLevel", as: SetAbsoluteLevel.self),
              let show = symbol("SLSShowSpaces", as: ShowSpaces.self) else { return nil }
        let sid = create(cid, 1, 0)
        guard sid != 0 else { return nil }
        _ = setLevel(cid, sid, 0)
        _ = show(cid, [NSNumber(value: sid)] as CFArray)
        return sid
    }()

    static func attach(_ window: NSWindow) {
        guard let sid = space,
              let cid = symbol("SLSMainConnectionID", as: MainConnection.self)?(),
              let add = symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", as: AddWindows.self) else {
            log("sticky space unavailable, the spectrum will slide with desktops")
            return
        }
        _ = add(cid, sid, [NSNumber(value: window.windowNumber)] as CFArray, 0x7)
    }
}
