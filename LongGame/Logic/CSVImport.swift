import Foundation

/// Reads back the file that `CSVExport` writes: `Craft,Date,Start,Minutes,Source,Note`.
/// Pure and testable; the Settings screen decides which craft each row belongs to and saves.
enum CSVImport {
    struct Row: Equatable {
        var craft: String
        var start: Date
        var durationSec: Double
        var source: String
        var note: String
    }

    struct Parsed: Equatable {
        var rows: [Row]
        /// Lines that could not be read (bad date, minutes that are not a number, too few columns).
        var skipped: Int
    }

    /// Splits CSV text into records of fields. Handles quoted fields, doubled quotes,
    /// commas and line breaks inside quotes, CRLF, and a leading byte-order mark.
    static func records(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text.unicodeScalars.map(Character.init))
        if chars.first == "\u{FEFF}" { chars.removeFirst() }

        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { inQuotes = false }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": record.append(field); field = ""
                case "\n", "\r\n", "\r":
                    record.append(field); field = ""
                    records.append(record); record = []
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !record.isEmpty { record.append(field); records.append(record) }
        return records.filter { !($0.count == 1 && $0[0].trimmingCharacters(in: .whitespaces).isEmpty) }
    }

    static func sessions(_ text: String, calendar: Calendar = .current) -> Parsed {
        var all = records(text)
        guard !all.isEmpty else { return Parsed(rows: [], skipped: 0) }
        // Drop the header row if there is one.
        if all[0].first?.trimmingCharacters(in: .whitespaces).lowercased() == "craft" { all.removeFirst() }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var rows: [Row] = []
        var skipped = 0
        for r in all {
            guard r.count >= 4,
                  let start = formatter.date(from: "\(r[1].trimmingCharacters(in: .whitespaces)) \(r[2].trimmingCharacters(in: .whitespaces))"),
                  let minutes = Double(r[3].trimmingCharacters(in: .whitespaces)), minutes > 0, minutes.isFinite
            else { skipped += 1; continue }
            rows.append(Row(craft: r[0].trimmingCharacters(in: .whitespaces),
                            start: start,
                            durationSec: minutes * 60,
                            source: r.count > 4 ? r[4].trimmingCharacters(in: .whitespaces) : "manual",
                            note: r.count > 5 ? r[5] : ""))
        }
        return Parsed(rows: rows, skipped: skipped)
    }

    /// A session counts as already there when it starts in the same minute with the same length.
    static func key(craftId: UUID, start: Date, durationSec: Double) -> String {
        "\(craftId.uuidString)|\(Int(start.timeIntervalSince1970 / 60))|\(Int((durationSec / 60).rounded()))"
    }

    struct CraftRef {
        var id: UUID
        var name: String
    }

    struct Plan {
        var toAdd: [(craftId: UUID, row: Row)] = []
        var duplicates = 0
        /// Rows for a craft that is not on this iPhone.
        var unmatched = 0
    }

    /// Rows go to the craft with the same name (ignoring case). If the file only mentions one craft
    /// and no name matches (a new device set up with a different name), they go to the active craft.
    static func plan(rows: [Row], crafts: [CraftRef], activeId: UUID, existingKeys: Set<String>) -> Plan {
        let byName = Dictionary(crafts.map { ($0.name.lowercased(), $0.id) }, uniquingKeysWith: { first, _ in first })
        let names = Set(rows.map { $0.craft.lowercased() })
        let fallback: UUID? = (names.count == 1 && byName[names.first!] == nil) ? activeId : nil

        var plan = Plan()
        var seen = existingKeys
        for row in rows {
            guard let id = byName[row.craft.lowercased()] ?? fallback else { plan.unmatched += 1; continue }
            let k = key(craftId: id, start: row.start, durationSec: row.durationSec)
            if seen.contains(k) { plan.duplicates += 1; continue }
            seen.insert(k)
            plan.toAdd.append((id, row))
        }
        return plan
    }
}
