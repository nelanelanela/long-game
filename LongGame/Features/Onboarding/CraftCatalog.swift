import Foundation

struct CraftGroup: Identifiable {
    let name: String
    let crafts: [String]
    var id: String { name }
}

enum CraftCatalog {
    static let groups: [CraftGroup] = [
        CraftGroup(name: "Music", crafts: ["Piano", "Guitar", "Violin", "Cello", "Drums", "Bass", "Saxophone", "Flute", "Trumpet", "Singing", "Composing"]),
        CraftGroup(name: "Visual arts & making", crafts: ["Painting", "Drawing", "Sculpture", "Woodworking", "Ceramics", "Photography", "Illustration", "Printmaking", "Textiles", "Jewellery"]),
        CraftGroup(name: "Performing arts", crafts: ["Acting", "Dance", "Ballet", "Directing", "Stand-up"]),
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
}
