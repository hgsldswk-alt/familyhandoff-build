import LocalAuthentication
import SwiftUI
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var list: HandoffList
    @Published var locked: Bool
    @Published var showDone = false
    var pendingDone = false
    @Published var importText: String?

    private let store: Store
    private let defaults = Launch.defaults()

    var lockEnabled: Bool {
        get { defaults.object(forKey: "lock.enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "lock.enabled"); objectWillChange.send() }
    }

    var reminderEnabled: Bool {
        get { defaults.bool(forKey: "reminder.enabled") }
        set {
            defaults.set(newValue, forKey: "reminder.enabled")
            objectWillChange.send()
            Task { await scheduleReminder() }
        }
    }

    init(store: Store = .live()) {
        self.store = store
        list = store.load()
        locked = !Launch.isUITesting
        if Launch.isUITesting { seedForScreenshots() }
    }


    @discardableResult
    func add(_ title: String, to group: Area, detail: String = "") -> Entry? {
        guard let entry = list.add(title, to: group, detail: detail) else { return nil }
        commit()
        return entry
    }

    func update(_ entry: Entry) {
        list.update(entry)
        commit()
    }

    func remove(_ entry: Entry) {
        list.remove(entry.id)
        commit()
    }

    func merge(_ other: HandoffList) {
        list.merge(other)
        commit()
    }

    private func commit() {
        store.save(list)
        if list.everyGroupStarted && !list.celebrated {
            list.celebrated = true
            store.save(list)
            pendingDone = true
        }
        if list.filledCount > 0 { CoreReview.shared.record() }
        Task { await scheduleReminder() }
    }


    func unlock() {
        guard lockEnabled else { locked = false; return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { locked = false; return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L.t("lock.reason")) { ok, _ in
            Task { @MainActor in if ok { self.locked = false } }
        }
    }

    func relock() {
        if lockEnabled && !Launch.isUITesting { locked = true }
    }


    func scheduleReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["review"])
        guard reminderEnabled, !Launch.isUITesting, let date = list.reviewDate(), date > .now else { return }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = L.t("reminder.title")
        content.body = L.t("reminder.body")
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var at = parts
        at.hour = 10
        try? await center.add(UNNotificationRequest(identifier: "review", content: content,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: at, repeats: false)))
    }


    private func seedForScreenshots() {
        guard ProcessInfo.processInfo.arguments.contains("-seed"), list.entries.isEmpty else { return }
        let samples: [(Area, String, String)] = [
            (.money, "suggest.money.1", "seed.money.1"),
            (.money, "suggest.money.2", "seed.money.2"),
            (.money, "suggest.money.3", ""),
            (.accounts, "suggest.accounts.1", "seed.accounts.1"),
            (.accounts, "suggest.accounts.2", "seed.accounts.2"),
            (.documents, "suggest.documents.1", "seed.documents.1"),
            (.autopay, "suggest.autopay.1", "seed.autopay.1"),
            (.contacts, "suggest.contacts.1", "seed.contacts.1"),
            (.contacts, "suggest.contacts.2", "seed.contacts.2")
        ]
        let day: TimeInterval = 86_400
        for (offset, sample) in samples.enumerated() {
            list.add(L.t(sample.1), to: sample.0, detail: sample.2.isEmpty ? "" : L.t(sample.2),
                     at: Date.now.addingTimeInterval(-day * Double(3 + offset)))
        }
        store.save(list)
    }
}
