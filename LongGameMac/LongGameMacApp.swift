import SwiftUI
import SwiftData
import AppKit

/// Long Game for Mac. One window (the sidebar layout the iPad uses, at Mac size), the menus and shortcuts, and the
/// same SwiftData store as the iPhone.
@main
struct LongGameMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    @State private var store: StoreHost
    @State private var timerStore = TimerStore()
    @State private var iCloud = ICloudMonitor()
    @State private var tips = TipStore()
    @State private var commands = CommandCenter()

    init() {
        do {
            let host = try StoreHost()
            #if DEBUG
            DemoData.seedIfRequested(ModelContext(host.container))
            #endif
            _store = State(initialValue: host)
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
    }

    var body: some Scene {
        Window("Long Game", id: "main") {
            AppRoot()
                .modelContainer(store.container)
                .environment(store)
                .environment(timerStore)
                .environment(iCloud)
                .environment(tips)
                .environment(commands)
                .frame(minWidth: 900, minHeight: 600)
                .background(MacWindowSetup())
                .task(id: store.generation) { tips.start(context: store.container.mainContext) }
                .task { await iCloud.refresh(); iCloud.start() }
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 1180, height: 740)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands { LongGameMacCommands(center: commands, timer: timerStore) }

        // The sun in the menu bar: today's time, or the running clock, and a popover.
        MenuBarExtra {
            MenuBarPopover().menuBarEnvironment(store: store, timer: timerStore, commands: commands)
        } label: {
            MenuBarLabel().menuBarEnvironment(store: store, timer: timerStore, commands: commands)
        }
        .menuBarExtraStyle(.window)
    }
}

private extension View {
    func menuBarEnvironment(store: StoreHost, timer: TimerStore, commands: CommandCenter) -> some View {
        self.modelContainer(store.container)
            .environment(store)
            .environment(timer)
            .environment(commands)
    }
}

/// Lets the window be dragged by its background (the title bar is hidden), and keeps the traffic lights visible.
private struct MacWindowSetup: NSViewRepresentable {
    final class Anchor: NSView {
        override func viewDidMoveToWindow() {
            guard let window else { return }
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(LGColor.background)
            #if DEBUG
            MainActor.assumeIsolated { DebugSnapshot.scheduleIfRequested(window) }
            #endif
        }
    }

    func makeNSView(context: Context) -> NSView { Anchor() }
    func updateNSView(_ view: NSView, context: Context) {}
}

#if DEBUG
/// Debug builds: `-debug.snapshot /path/name` saves a picture of the window a few seconds after launch (and again
/// after each `-debug.snapshotKeys` step), so the layout can be checked without screen-recording permission.
enum DebugSnapshot {
    @MainActor
    static func scheduleIfRequested(_ window: NSWindow) {
        let args = ProcessInfo.processInfo.arguments
        guard let at = args.firstIndex(of: "-debug.snapshot"), args.indices.contains(at + 1) else { return }
        let base = args[at + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            save(window, to: base + ".png")
            if args.contains("-debug.snapshotQuit") { NSApp.terminate(nil) }
        }
    }

    @MainActor
    static func save(_ window: NSWindow, to path: String) {
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
#endif
