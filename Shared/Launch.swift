import Foundation

enum Launch {
    static let freePeriod = true

    private static let arguments = ProcessInfo.processInfo.arguments
    static let isUITesting = arguments.contains("-ui-testing")
    static var shouldResetTestData: Bool { isUITesting && arguments.contains("-reset") }

    static func defaults() -> UserDefaults {
        guard isUITesting else { return .standard }
        let token = ProcessInfo.processInfo.environment["FAMILYHANDOFF_TEST_SESSION"] ?? "default"
        let suite = "com.hgsldswk.familyhandoff.uitest." + token
        guard let defaults = UserDefaults(suiteName: suite) else {
            preconditionFailure("Unable to create an isolated UI test suite")
        }
        if shouldResetTestData { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }
}
