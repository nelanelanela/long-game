import Foundation

struct CraftGroup: Identifiable, Equatable {
    let name: String
    let crafts: [String]
    var id: String { name }
}

enum CraftSuggestions {
    static let groups: [CraftGroup] = [
        CraftGroup(name: "Music", crafts: ["Piano", "Guitar", "Violin", "Cello", "Drums", "Bass", "Saxophone", "Flute", "Trumpet", "Singing", "Composing"]),
        CraftGroup(name: "Visual arts & making", crafts: ["Painting", "Drawing", "Sculpture", "Woodworking", "Ceramics", "Photography", "Illustration", "Printmaking", "Textiles", "Jewellery"]),
        CraftGroup(name: "Performing arts", crafts: ["Acting", "Dance", "Ballet", "Directing"]),
        CraftGroup(name: "Words & mind", crafts: ["Writing", "Poetry", "Languages", "Chess", "Coding"]),
        CraftGroup(name: "Professions", crafts: ["Medicine", "Law", "Architecture", "Design", "Cooking", "Teaching"]),
    ]

    static let customCategory = "Your own"

    /// Case-insensitive match against the suggestions.
    static func match(_ text: String) -> (group: String, craft: String)? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for g in groups {
            if let c = g.crafts.first(where: { $0.lowercased() == t }) { return (g.name, c) }
        }
        return nil
    }

    static func isValidName(_ text: String) -> Bool {
        (2...40).contains(text.trimmingCharacters(in: .whitespacesAndNewlines).count)
    }

    /// What the list shows (updates 53 and 54). The list is never filtered: every group and every choice is always
    /// there, and the typed name is added on top as its own chip.
    struct Choice: Equatable {
        /// "Your own": the typed text as a chip, from 2 characters, unless it matches a choice exactly.
        var own: String?
        /// The choice that is selected: one tapped (`picked`), or the one the typed text matches exactly.
        var selectedChoice: String?
        /// Every group, always.
        var groups: [CraftGroup]
        /// "Not on the list? It's your game, call it anything." shows exactly when the own chip shows.
        var showsNoMatchLine: Bool { own != nil }
        /// The own chip is selected while no choice is.
        var ownSelected: Bool { own != nil && selectedChoice == nil }
        /// The craft the button plays: the selected choice, or the typed name.
        var selected: String? { selectedChoice ?? own }
    }

    /// - Parameters:
    ///   - text: what is typed in the field (kept as typed when a choice is tapped).
    ///   - picked: a choice tapped in the list, which wins over the typed text.
    static func choice(_ text: String, picked: String? = nil) -> Choice {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        let exact = match(trimmed)?.craft
        let own = exact == nil && trimmed.count >= 2 ? trimmed : nil
        return Choice(own: own, selectedChoice: picked ?? exact, groups: groups)
    }

    /// The group a choice belongs to.
    static func group(of craft: String) -> String? {
        groups.first { $0.crafts.contains(craft) }?.name
    }

    /// "Play Calligraphy" once a name of 2 to 40 characters is chosen, otherwise nil ("Continue", disabled).
    static func playTitle(_ name: String?) -> String? {
        guard let name, isValidName(name) else { return nil }
        return String(localized: "Play \(name)")
    }
}
