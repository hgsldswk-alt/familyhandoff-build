import CoreImage.CIFilterBuiltins
import UIKit

enum Exporter {
    static var storeURL: URL {
        let id = (Bundle.main.object(forInfoDictionaryKey: "APP_STORE_ID") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
        if !id.isEmpty, id.allSatisfy(\.isNumber) {
            return URL(string: "https://apps.apple.com/app/id\(id)")!
        }
        return URL(string: "https://hgsldswk-alt.github.io/familyhandoff-support/")!
    }

    static func qr(_ text: String, size: CGFloat) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: size / output.extent.width,
                                                              y: size / output.extent.height))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func pdf(_ list: HandoffList, date: Date = .now) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 48
        let width = page.width - margin * 2
        let ink = UIColor(red: 0.14, green: 0.19, blue: 0.23, alpha: 1)
        let accent = UIColor(red: 0.28, green: 0.26, blue: 0.24, alpha: 1)
        let muted = UIColor(red: 0.40, green: 0.44, blue: 0.48, alpha: 1)
        let title: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 24, weight: .bold), .foregroundColor: ink]
        let head: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: accent]
        let itemTitle: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: ink]
        let body: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: ink]
        let small: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: muted]
        let code = qr(storeURL.absoluteString, size: 64)
        let stamp = date.formatted(date: .long, time: .omitted)

        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            var y: CGFloat = 0
            func footer() {
                let line = L.f("pdf.footer", stamp)
                line.draw(in: CGRect(x: margin, y: page.height - 54, width: width - 80, height: 30), withAttributes: small)
                code?.draw(in: CGRect(x: page.width - margin - 40, y: page.height - 62, width: 40, height: 40))
            }
            func newPage() {
                context.beginPage()
                footer()
                y = margin
            }
            func ensure(_ height: CGFloat) {
                if y + height > page.height - 80 { newPage() }
            }
            func draw(_ text: String, _ attributes: [NSAttributedString.Key: Any], indent: CGFloat = 0, after: CGFloat = 4) {
                let rect = (text as NSString).boundingRect(with: CGSize(width: width - indent, height: .greatestFiniteMagnitude),
                                                           options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
                ensure(rect.height)
                (text as NSString).draw(with: CGRect(x: margin + indent, y: y, width: width - indent, height: rect.height),
                                        options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
                y += ceil(rect.height) + after
            }

            newPage()
            draw(L.t("pdf.title"), title, after: 6)
            draw(L.t("pdf.intro"), small, after: 18)
            for group in Area.allCases {
                let entries = list.entries(in: group)
                guard !entries.isEmpty else { continue }
                ensure(60)
                draw(L.t(group.titleKey), head, after: 8)
                for entry in entries {
                    draw("• " + entry.title, itemTitle, indent: 6, after: 2)
                    draw(entry.isFilled ? entry.detail : L.t("pdf.blank"), body, indent: 18, after: 8)
                }
                y += 8
            }
        }
    }
}
