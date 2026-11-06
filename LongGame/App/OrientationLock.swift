import SwiftUI
import UIKit

/// Every screen stays upright except the running session (the timer), which may rotate.
/// The app declares landscape in its settings so the timer can use it; this decides, screen by screen, what is allowed.
@MainActor
enum OrientationLock {
    static var allowed: UIInterfaceOrientationMask = .portrait

    /// Allow (or stop allowing) rotation, and turn the screen upright when rotation is taken away.
    static func set(rotating: Bool) {
        allowed = rotating ? .allButUpsideDown : .portrait
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if !rotating { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

final class LongGameAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { OrientationLock.allowed }
    }
}

extension View {
    /// This screen may rotate while it is on show; the screens after it stay upright.
    func allowsRotation() -> some View {
        onAppear { OrientationLock.set(rotating: true) }
            .onDisappear { OrientationLock.set(rotating: false) }
    }
}
