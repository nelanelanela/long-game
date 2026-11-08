import SwiftUI
import UserNotifications
import UIKit

/// Every screen stays upright except the running session (the timer), which may rotate.
/// The app declares landscape in its settings so the timer can use it; this decides, screen by screen, what is allowed.
@MainActor
enum OrientationLock {
    static var allowed: UIInterfaceOrientationMask = .portrait

    /// An iPad turns freely on every screen (its layouts are chosen by window size); only the iPhone is held upright.
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Allow (or stop allowing) rotation, and turn the screen upright when rotation is taken away.
    static func set(rotating: Bool) {
        if isPad { allowed = .all; return }
        allowed = rotating ? .all : .portrait
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if !rotating { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

final class LongGameAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Tapping a notification opens the app where it points, so the opening sunrise stays out of the way.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { NotificationCenter.default.post(name: .openingShouldSkip, object: nil) }
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { OrientationLock.isPad ? .all : OrientationLock.allowed }
    }
}

extension View {
    /// This screen may rotate while it is on show; the screens after it stay upright.
    func allowsRotation() -> some View {
        onAppear { OrientationLock.set(rotating: true) }
            .onDisappear { OrientationLock.set(rotating: false) }
    }
}
