import Testing
import Foundation
import SwiftUI
@testable import LongGame

// Update 45: the dark look.

struct DarkModeTests {
    @Test func theTimerStopsAtDawnInTheDarkLook() {
        #expect(TimerSunrise.sceneProgress(1, dark: true) == 0.55)
        #expect(TimerSunrise.sceneProgress(0.5, dark: true) == 0.275)
        #expect(TimerSunrise.sceneProgress(0, dark: true) == 0)
        #expect(TimerSunrise.sceneProgress(1.4, dark: true) == 0.55)
        // The light look is unchanged.
        #expect(TimerSunrise.sceneProgress(0.8, dark: false) == 0.8)
        #expect(TimerSunrise.sceneProgress(1, dark: false) == 1)
    }

    @Test func theWordsStayWhiteThroughoutInTheDarkLook() {
        for p in stride(from: 0.0, through: 1.0, by: 0.05) {
            let scene = TimerSunrise.sceneProgress(p, dark: true)
            #expect(TimerSunrise.lightness(p: scene) == 0)
            #expect(TimerSunrise.inkHex(p: scene) == 0xFFFFFF)
        }
    }

    @Test func theAppearanceSetting() {
        #expect(AppAppearance.automatic.isDark(systemIsDark: true))
        #expect(!AppAppearance.automatic.isDark(systemIsDark: false))
        #expect(AppAppearance.dark.isDark(systemIsDark: false))
        #expect(!AppAppearance.light.isDark(systemIsDark: true))
        #expect(AppAppearance.automatic.colorScheme == nil)
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
        #expect(AppSettings().appearance == .automatic)
        let s = AppSettings()
        s.appearance = .dark
        #expect(s.appearanceRaw == "dark")
        #expect(AppAppearance(rawValue: "nonsense") == nil)
    }

    #if os(iOS)
    /// The light look keeps its exact colours; the dark look uses the board's table.
    @Test func theColourTable() {
        func hex(_ c: Color, _ style: UIUserInterfaceStyle) -> UInt32 {
            let ui = UIColor(c).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return UInt32((r * 255).rounded()) << 16 | UInt32((g * 255).rounded()) << 8 | UInt32((b * 255).rounded())
        }
        let table: [(Color, UInt32, UInt32)] = [
            (LGColor.background, 0xFAF7F1, 0x0B1029), (LGColor.surface, 0xFFFFFF, 0x172044),
            (LGColor.ink, 0x16244A, 0xF4EFE6), (LGColor.inkMuted, 0x5E6782, 0xA9B1C9),
            (LGColor.primaryFill, 0x16244A, 0xFFD66B), (LGColor.primaryLabel, 0xFFFFFF, 0x16244A),
            (LGColor.ember, 0xB4561A, 0xFFB877), (LGColor.segmentTrack, 0xEFE2CF, 0x262F57),
            (LGColor.hairline, 0xECE7DE, 0x222B52), (LGColor.rest, 0xC5D0EC, 0x3D4D93),
            (LGColor.peachWashSetup, 0xFFF1DA, 0x2A2440),
        ]
        for (colour, light, dark) in table {
            #expect(hex(colour, .light) == light)
            #expect(hex(colour, .dark) == dark)
        }
        // The sun's navy and the paper never change.
        #expect(hex(LGColor.navy, .dark) == 0x16244A)
        #expect(hex(LGColor.paper, .dark) == 0xFAF7F1)
    }
    #endif
}
