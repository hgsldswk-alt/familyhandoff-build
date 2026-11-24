import Foundation

enum Area: String, CaseIterable, Codable, Identifiable, Sendable {
    case money, accounts, documents, autopay, contacts, home

    var id: String { rawValue }
    var titleKey: String { "group.\(rawValue)" }
    var hintKey: String { "group.\(rawValue).hint" }

    var suggestionKeys: [String] {
        let count: Int
        switch self {
        case .money: count = 8
        case .accounts: count = 6
        case .documents: count = 7
        case .autopay: count = 6
        case .contacts: count = 5
        case .home: count = 6
        }
        return (1...count).map { "suggest.\(rawValue).\($0)" }
    }
}

struct Entry: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var group: Area
    var title: String
    var detail: String
    var updated: Date

    var isFilled: Bool { !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct HandoffList: Codable, Equatable, Sendable {
    static let goalPerGroup = 3

    var entries: [Entry] = []
    var updated: Date?
    var celebrated = false

    func entries(in group: Area) -> [Entry] {
        entries.filter { $0.group == group }
    }

    func filledCount(in group: Area) -> Int {
        entries(in: group).filter(\.isFilled).count
    }

    func progress(in group: Area) -> Double {
        Double(min(filledCount(in: group), Self.goalPerGroup)) / Double(Self.goalPerGroup)
    }

    var filledCount: Int { entries.filter(\.isFilled).count }

    var progress: Double {
        Area.allCases.map { progress(in: $0) }.reduce(0, +) / Double(Area.allCases.count)
    }

    var everyGroupStarted: Bool { Area.allCases.allSatisfy { filledCount(in: $0) > 0 } }

    func contains(title: String, in group: Area) -> Bool {
        entries(in: group).contains { $0.title.caseInsensitiveCompare(title) == .orderedSame }
    }

    @discardableResult
    mutating func add(_ title: String, to group: Area, detail: String = "", at date: Date = .now) -> Entry? {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !contains(title: clean, in: group) else { return nil }
        let entry = Entry(group: group, title: clean, detail: detail, updated: date)
        entries.append(entry)
        updated = date
        return entry
    }

    mutating func update(_ entry: Entry, at date: Date = .now) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var next = entry
        next.title = next.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.title.isEmpty else { return }
        next.updated = date
        entries[index] = next
        updated = date
    }

    mutating func remove(_ id: UUID, at date: Date = .now) {
        entries.removeAll { $0.id == id }
        updated = date
    }

    mutating func merge(_ other: HandoffList) {
        for incoming in other.entries {
            if let index = entries.firstIndex(where: {
                $0.group == incoming.group && $0.title.caseInsensitiveCompare(incoming.title) == .orderedSame
            }) {
                if incoming.updated > entries[index].updated { entries[index] = incoming }
            } else {
                entries.append(incoming)
            }
        }
        if let theirs = other.updated { updated = max(updated ?? theirs, theirs) }
    }

    func reviewDate(calendar: Calendar = .current) -> Date? {
        guard let updated else { return nil }
        return calendar.date(byAdding: .month, value: 6, to: updated)
    }
}
