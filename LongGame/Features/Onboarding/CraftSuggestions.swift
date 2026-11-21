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

    static func filtered(_ query: String) -> [CraftGroup] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return groups }
        return groups.compactMap { g in
            let hits = g.crafts.filter { $0.lowercased().contains(q) }
            return hits.isEmpty ? nil : CraftGroup(name: g.name, crafts: hits)
        }
    }

    static func isValidName(_ text: String) -> Bool {
        (2...40).contains(text.trimmingCharacters(in: .whitespacesAndNewlines).count)
    }

    /// What the list shows for the typed text (update 53).
    struct Choice: Equatable {
        /// "Your own": the typed text as a chip, already selected. Nil below 2 characters or on an exact match.
        var own: String?
        /// The suggestion the text matches exactly (ignoring case), which is selected instead.
        var matched: String?
        /// The groups to show under their labels.
        var groups: [CraftGroup]
        /// "Not on the list? It's your game, call it anything." when only the own chip is left.
        var showsNoMatchLine: Bool

        /// The craft the button would play: the exact match, or the own text.
        var selected: String? { matched ?? own }
    }

    static func choice(_ text: String) -> Choice {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hit = match(trimmed)
        // An exact match shows every group again, so another craft is one tap away.
        let shown = hit != nil ? groups : filtered(trimmed)
        let own = hit == nil && trimmed.count >= 2 ? String(trimmed.prefix(40)) : nil
        return Choice(own: own, matched: hit?.craft, groups: shown, showsNoMatchLine: own != nil && shown.isEmpty)
    }

    /// "Play Calligraphy" once a name of 2 to 40 characters exists, otherwise nil ("Continue", disabled).
    static func playTitle(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidName(trimmed) else { return nil }
        return String(localized: "Play \(match(trimmed)?.craft ?? trimmed)")
    }
}
