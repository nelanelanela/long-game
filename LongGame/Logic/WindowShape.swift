import CoreGraphics

/// Which layout a window gets. Chosen from the window's own size, never from the device model, so the same code
/// works on an iPhone, the Duo closed or open, Split View at any width and devices that don't exist yet.
enum WindowShape: Equatable, Sendable {
    /// The normal phone layout.
    case compact
    /// Compact width but under `shortHeight` tall (the Duo's outer display, an iPhone SE): a smaller hero.
    case short
    /// Wide and wider than tall (the Duo open, an iPad window): two panes.
    case wide
    /// A full-screen iPad in landscape, or a Stage Manager window at least `sidebarWidth` wide: sidebar and two columns.
    case sidebar
    /// A regular-width window that is taller than wide (an iPad in portrait): top tabs, bigger sun, two cards.
    case tall

    /// Windows shorter than this get the short variant.
    static let shortHeight: CGFloat = 700
    /// Without a regular size class, a window at least this wide still counts as wide (a phone turned sideways).
    static let wideWidth: CGFloat = 700
    /// At least this wide (and wider than tall, regular width) gets the sidebar layout.
    static let sidebarWidth: CGFloat = 1000
    /// A regular-width window needs at least this much width to count as tall; narrower is the iPhone layout.
    static let tallWidth: CGFloat = 600
    /// Sheets become centred cards no wider than this.
    static let sheetWidth: CGFloat = 520

    /// `width` and `height` are the whole window, safe areas included.
    static func make(width: CGFloat, height: CGFloat, isRegularWidth: Bool) -> WindowShape {
        if isRegularWidth && width >= sidebarWidth && width > height { return .sidebar }
        if (isRegularWidth || width >= wideWidth) && width > height { return .wide }
        if isRegularWidth && width >= tallWidth { return .tall }
        return height < shortHeight ? .short : .compact
    }

    /// Two panes or more (Home's left/right split, History side by side, the wide Timer).
    var isWide: Bool { self == .wide || self == .sidebar }
    var isTall: Bool { self == .tall }
}

/// Home's left pane: the gauge gets the pane's height, but never less than a phone's short hero.
enum WideGauge {
    static let minHeight: CGFloat = 220
    static let maxHeight: CGFloat = 470
    /// What the header and the tabs take above the gauge.
    static let chrome: CGFloat = 104

    static func height(forWindow height: CGFloat) -> CGFloat {
        min(maxHeight, max(minHeight, height - chrome))
    }
}
