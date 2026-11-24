import CommonCrypto
import CryptoKit
import Security
import Foundation

enum Transfer {
    static let prefix = "FAMILYHANDOFF1:"
    static let fileExtension = "familyhandoff"
    private static let iterations: UInt32 = 120_000
    private static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    enum Failure: Error, Equatable {
        case notAHandoff, wrongPasscode, damaged
    }

    static func newPasscode() -> String {
        var generator = SystemRandomNumberGenerator()
        let chars = (0..<8).map { _ in alphabet.randomElement(using: &generator)! }
        return String(chars[0..<4]) + "-" + String(chars[4..<8])
    }

    static func normalize(_ passcode: String) -> String {
        passcode.uppercased().filter { alphabet.contains($0) }
    }

    static func seal(_ list: HandoffList, passcode: String) throws -> String {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let plain = try encoder.encode(list)
        let box = try AES.GCM.seal(plain, using: key(passcode, salt: salt))
        guard let combined = box.combined else { throw Failure.damaged }
        return prefix + (salt + combined).base64EncodedString()
    }

    static func open(_ text: String, passcode: String) throws -> HandoffList {
        guard let start = text.range(of: prefix) else { throw Failure.notAHandoff }
        let body = text[start.upperBound...].prefix { !$0.isWhitespace }
        guard let data = Data(base64Encoded: String(body)), data.count > 16 + 28 else { throw Failure.damaged }
        let salt = data.prefix(16)
        let plain: Data
        do {
            let box = try AES.GCM.SealedBox(combined: data.dropFirst(16))
            plain = try AES.GCM.open(box, using: key(passcode, salt: Data(salt)))
        } catch {
            throw Failure.wrongPasscode
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let list = try? decoder.decode(HandoffList.self, from: plain) else { throw Failure.damaged }
        return list
    }

    static func looksLikeHandoff(_ text: String?) -> Bool {
        text?.contains(prefix) == true
    }

    private static func key(_ passcode: String, salt: Data) -> SymmetricKey {
        let password = Array(normalize(passcode).utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        salt.withUnsafeBytes { saltBytes in
            _ = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                     password.map { Int8(bitPattern: $0) }, password.count,
                                     saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
                                     &derived, derived.count)
        }
        return SymmetricKey(data: derived)
    }
}
