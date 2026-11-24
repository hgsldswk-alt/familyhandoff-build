import SwiftUI

enum Palette {
    static let accent = Color(red: 0x47 / 255, green: 0x42 / 255, blue: 0x3D / 255)
    static let accentSoft = Color(red: 0xEC / 255, green: 0xE8 / 255, blue: 0xE2 / 255)
    static let amber = Color(red: 0xD9 / 255, green: 0xA4 / 255, blue: 0x41 / 255)
    static let amberSoft = Color(red: 0xF7 / 255, green: 0xEB / 255, blue: 0xD2 / 255)
    static let background = Color(red: 0xFA / 255, green: 0xF6 / 255, blue: 0xEF / 255)
    static let paper = Color.white
    static let ink = Color(red: 0x23 / 255, green: 0x30 / 255, blue: 0x3A / 255)
    static let muted = Color(red: 0x66 / 255, green: 0x71 / 255, blue: 0x7B / 255)
    static let line = Color(red: 0xE6 / 255, green: 0xE0 / 255, blue: 0xD5 / 255)
    static let ok = Color(red: 0x4F / 255, green: 0x7A / 255, blue: 0x5C / 255)
    static let rose = Color(red: 0xC9 / 255, green: 0x7B / 255, blue: 0x63 / 255)
}

extension Area {
    var symbol: String {
        switch self {
        case .money: return "creditcard.fill"
        case .accounts: return "iphone"
        case .documents: return "folder.fill"
        case .autopay: return "clock.fill"
        case .contacts: return "person.2.fill"
        case .home: return "heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .money: return Palette.amber
        case .accounts: return Palette.accent
        case .documents: return Palette.rose
        case .autopay: return Palette.ok
        case .contacts: return Color(red: 0x8A / 255, green: 0x6A / 255, blue: 0x3A / 255)
        case .home: return Palette.rose
        }
    }

    var soft: Color { tint.opacity(0.16) }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.line))
    }
}

struct PrimaryButton: ButtonStyle {
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(filled ? Color.white : Palette.accent)
            .background(filled ? Palette.accent : Palette.paper, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(filled ? .clear : Palette.line))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct ProgressRing: View {
    let value: Double
    var body: some View {
        ZStack {
            Circle().stroke(Palette.line, lineWidth: 8)
            Circle().trim(from: 0, to: value)
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((value * 100).rounded()))%").font(.subheadline.bold()).foregroundStyle(Palette.ink)
        }
        .frame(width: 64, height: 64)
    }
}
