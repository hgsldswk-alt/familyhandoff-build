import Foundation

private final class ResourceMarker: NSObject {}

enum L {
    static let bundle = Bundle(for: ResourceMarker.self)

    static func t(_ key: String, bundle: Bundle = L.bundle) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func f(_ key: String, _ arguments: CVarArg..., bundle: Bundle = L.bundle) -> String {
        String(format: t(key, bundle: bundle), arguments: arguments)
    }
}
