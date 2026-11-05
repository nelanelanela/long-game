import AVFoundation

/// The little bit of the system audio session the giggle needs, so tests can watch it without a speaker.
@MainActor
protocol GiggleAudioSession {
    /// True while something else (a podcast, a call) wants the sound to stay quiet.
    var otherAudioWantsSilence: Bool { get }
    /// Ambient: silent with the Ring/Silent switch on silent, mixes with music, never stops or ducks it.
    func useAmbient()
}

struct SystemGiggleAudioSession: GiggleAudioSession {
    var otherAudioWantsSilence: Bool { AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint }

    func useAmbient() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}

/// Plays the sun's giggles: the clips are loaded once, one is picked at random (never the same twice in a row),
/// only one is ever heard at a time, and the longest one is kept for the five-tap laugh.
/// With the setting off it does nothing at all, and never touches the audio session.
@MainActor
final class GiggleSoundPlayer {
    static let shared = GiggleSoundPlayer()
    nonisolated static let volume: Float = 0.7
    /// The laugh sound starts after the gasp (0.10 s in the spec).
    nonisolated static let startDelay: TimeInterval = 0.10

    private let session: GiggleAudioSession
    private let loader: () -> [AVAudioPlayer]
    private var players: [AVAudioPlayer] = []
    private var bigIndex: Int?
    private var picker = GiggleClipPicker(count: 0)
    private var current: AVAudioPlayer?

    init(session: GiggleAudioSession = SystemGiggleAudioSession(),
         loader: @escaping () -> [AVAudioPlayer] = GiggleSoundPlayer.bundledClips) {
        self.session = session
        self.loader = loader
    }

    /// Sets up the audio session and loads the clips, once. Only when the setting is on.
    func prepare(enabled: Bool) {
        guard enabled else { return }
        session.useAmbient()
        loadClipsIfNeeded()
    }

    private func loadClipsIfNeeded(force: Bool = false) {
        guard force || players.isEmpty else { return }
        current?.stop()
        current = nil
        players = loader()
        bigIndex = players.indices.max(by: { players[$0].duration < players[$1].duration })
        // The other clips take turns at random; the longest is for the big laugh.
        picker = GiggleClipPicker(count: max(0, players.count - (bigIndex == nil ? 0 : 1)))
    }

    /// Plays a giggle and returns how long it lasts, or nil when nothing was played (setting off, no clips,
    /// or a clip is already playing and this is not the big laugh).
    /// The audio session is woken before every giggle (calls, Siri, the timer and the lock screen can all switch
    /// it off), and if a clip refuses to start the clips are loaded afresh and tried once more, so it always giggles.
    @discardableResult
    func play(big: Bool, enabled: Bool) -> TimeInterval? {
        guard enabled else { return nil }
        session.useAmbient()
        loadClipsIfNeeded()
        guard !players.isEmpty else { return nil }
        if current?.isPlaying == true {
            guard big else { return nil }
            current?.stop()
        }
        if let length = start(big: big) { return length }
        loadClipsIfNeeded(force: true)
        return start(big: big)
    }

    private func start(big: Bool) -> TimeInterval? {
        guard let player = big ? bigIndex.map({ players[$0] }) : nextClip() else { return nil }
        player.currentTime = 0
        player.volume = Self.volume
        player.prepareToPlay()
        guard player.play(atTime: player.deviceCurrentTime + Self.startDelay) else { return nil }
        current = player
        return player.duration + Self.startDelay
    }

    func stop() {
        current?.stop()
        current = nil
    }

    private func nextClip() -> AVAudioPlayer? {
        var generator = SystemRandomNumberGenerator()
        guard let pick = picker.next(using: &generator) else { return nil }
        // Index among the clips that are not the big one.
        let others = players.indices.filter { $0 != bigIndex }
        return pick < others.count ? players[others[pick]] : nil
    }

    /// `giggle-1.m4a`, `giggle-2.m4a`, … from the app bundle, loaded and ready to start instantly.
    nonisolated static func bundledClips() -> [AVAudioPlayer] {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: "Sounds") ?? [])
        return urls
            .filter { $0.lastPathComponent.hasPrefix("giggle-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                player.volume = volume
                player.prepareToPlay()
                return player
            }
    }
}
