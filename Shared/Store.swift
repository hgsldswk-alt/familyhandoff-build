import Foundation

struct Store {
    let url: URL

    static func live() -> Store {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if Launch.isUITesting {
            let token = ProcessInfo.processInfo.environment["FAMILYHANDOFF_TEST_SESSION"] ?? "default"
            return Store(url: base.appendingPathComponent("uitest-\(token).json"))
        }
        return Store(url: base.appendingPathComponent("handoff.json"))
    }

    func load() -> HandoffList {
        if Launch.shouldResetTestData { try? FileManager.default.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url) else { return HandoffList() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode(HandoffList.self, from: data)) ?? HandoffList()
    }

    func save(_ list: HandoffList) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(list) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
