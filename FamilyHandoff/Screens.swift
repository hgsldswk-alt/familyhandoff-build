import SwiftUI
import UniformTypeIdentifiers


struct GroupView: View {
    @EnvironmentObject private var model: AppModel
    let group: Area
    @State private var editing: Entry?
    @State private var customTitle = ""
    @State private var addingCustom = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L.t("area.tip")).font(.footnote).foregroundStyle(Palette.muted)
                FlowLayout(spacing: 8) {
                    ForEach(Array(group.suggestionKeys.enumerated()), id: \.offset) { index, key in
                        let title = L.t(key)
                        let added = model.list.contains(title: title, in: group)
                        Button {
                            if let entry = model.add(title, to: group) { editing = entry }
                        } label: {
                            Text((added ? "✓ " : "+ ") + title)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12).frame(minHeight: 36)
                                .foregroundStyle(added ? Palette.accent : Color(red: 0.48, green: 0.35, blue: 0.11))
                                .background(added ? Palette.accentSoft : Palette.amberSoft, in: Capsule())
                        }
                        .disabled(added)
                        .accessibilityIdentifier("suggest.\(index + 1)")
                    }
                }

                let entries = model.list.entries(in: group)
                if !entries.isEmpty {
                    Card {
                        VStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                Button { editing = entry } label: { EntryRow(entry: entry) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("entry.\(index + 1)")
                                if index < entries.count - 1 { Divider().padding(.leading, 36) }
                            }
                        }
                    }
                }
                Text(L.t("area.password")).font(.caption).foregroundStyle(Palette.muted)
            }
            .padding(18)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(Text(L.t(group.titleKey)))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L.t("area.custom")) { addingCustom = true }.accessibilityIdentifier("area.custom")
            }
        }
        .alert(L.t("area.custom"), isPresented: $addingCustom) {
            TextField(L.t("area.custom.placeholder"), text: $customTitle)
            Button(L.t("common.add")) {
                if let entry = model.add(customTitle, to: group) { editing = entry }
                customTitle = ""
            }
            Button(L.t("common.cancel"), role: .cancel) { customTitle = "" }
        }
        .sheet(item: $editing) { EntryEditor(entry: $0) }
    }
}

private struct EntryRow: View {
    let entry: Entry
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(entry.isFilled ? Palette.ok : Palette.amber).frame(width: 10, height: 10).padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).font(.subheadline.bold()).foregroundStyle(Palette.ink)
                Text(entry.isFilled ? entry.detail : L.t("entry.empty"))
                    .font(.footnote).foregroundStyle(Palette.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

struct EntryEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var entry: Entry
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section(L.t("editor.name")) {
                    TextField(L.t("editor.name"), text: $entry.title).accessibilityIdentifier("editor.title")
                }
                Section {
                    TextField(L.t("editor.placeholder"), text: $entry.detail, axis: .vertical)
                        .lineLimit(4...10)
                        .focused($focused)
                        .accessibilityIdentifier("editor.detail")
                } header: {
                    Text(L.t("editor.detail"))
                } footer: {
                    Text(L.t("editor.footer"))
                }
                Section {
                    Button(L.t("editor.delete"), role: .destructive) {
                        model.remove(entry)
                        dismiss()
                    }
                    .accessibilityIdentifier("editor.delete")
                }
            }
            .navigationTitle(Text(L.t(entry.group.titleKey)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("common.done")) {
                        model.update(entry)
                        dismiss()
                    }
                    .accessibilityIdentifier("editor.save")
                }
            }
            .onAppear { if !entry.isFilled { focused = true } }
        }
    }
}


struct HandoffSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?
    @State private var passcode = Transfer.newPasscode()
    @State private var codeFile: URL?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Card {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.richtext.fill").font(.title).foregroundStyle(Palette.accent)
                                .frame(width: 54, height: 54).background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L.t("handoff.pdf")).font(.headline)
                                Text(L.t("handoff.pdf.note")).font(.footnote).foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(12)
                    }
                    if let pdfURL {
                        ShareLink(item: pdfURL) { Label(L.t("handoff.pdf.button"), systemImage: "square.and.arrow.up") }
                            .buttonStyle(PrimaryButton())
                            .accessibilityIdentifier("handoff.pdf")
                    }

                    Card {
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill").font(.title).foregroundStyle(Palette.amber)
                                .frame(width: 54, height: 54).background(Palette.amberSoft, in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L.t("handoff.code")).font(.headline)
                                Text(L.t("handoff.code.note")).font(.footnote).foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(12)
                    }
                    HStack {
                        Text(L.t("handoff.passcode")).font(.subheadline).foregroundStyle(Palette.muted)
                        Spacer()
                        Text(passcode).font(.title3.monospaced().bold()).foregroundStyle(Palette.ink)
                            .accessibilityIdentifier("handoff.passcode")
                    }
                    .padding(.horizontal, 4)
                    if let codeFile {
                        ShareLink(item: codeFile) { Label(L.t("handoff.code.button"), systemImage: "lock.doc") }
                            .buttonStyle(PrimaryButton(filled: false))
                            .accessibilityIdentifier("handoff.code")
                    }
                    Text(L.t("handoff.code.tell")).font(.caption).foregroundStyle(Palette.muted)
                }
                .padding(18)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle(Text(L.t("handoff.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("common.close")) { dismiss() }.accessibilityIdentifier("handoff.close")
                }
            }
            .task { prepare() }
        }
    }

    private func prepare() {
        let folder = FileManager.default.temporaryDirectory
        let pdf = folder.appendingPathComponent(L.t("pdf.filename") + ".pdf")
        try? Exporter.pdf(model.list).write(to: pdf, options: [.atomic, .completeFileProtection])
        pdfURL = pdf
        if let sealed = try? Transfer.seal(model.list, passcode: passcode) {
            let file = folder.appendingPathComponent(L.t("pdf.filename") + "." + Transfer.fileExtension)
            try? Data(sealed.utf8).write(to: file, options: [.atomic, .completeFileProtection])
            codeFile = file
        }
    }
}


struct ImportView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var initialText: String
    @State private var passcode = ""
    @State private var message: String?
    @State private var picking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if Transfer.looksLikeHandoff(initialText) {
                        Label(L.t("import.ready"), systemImage: "checkmark.seal.fill").foregroundStyle(Palette.ok)
                    } else {
                        Button(L.t("import.pick")) { picking = true }.accessibilityIdentifier("import.pick")
                        Button(L.t("import.paste")) { initialText = UIPasteboard.general.string ?? "" }
                    }
                } footer: { Text(L.t("import.note")) }
                Section(L.t("handoff.passcode")) {
                    TextField("XXXX-XXXX", text: $passcode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("import.passcode")
                }
                if let message { Text(message).foregroundStyle(Palette.rose) }
                Section {
                    Button(L.t("import.open")) { open() }
                        .disabled(Transfer.normalize(passcode).count < 8 || !Transfer.looksLikeHandoff(initialText))
                        .accessibilityIdentifier("import.open")
                }
            }
            .navigationTitle(Text(L.t("import.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("common.cancel")) { dismiss() } }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [UTType(filenameExtension: Transfer.fileExtension) ?? .data, .plainText]) { result in
                guard case let .success(url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                initialText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }
        }
    }

    private func open() {
        do {
            model.merge(try Transfer.open(initialText, passcode: passcode))
            dismiss()
        } catch Transfer.Failure.wrongPasscode {
            message = L.t("import.wrong")
        } catch {
            message = L.t("import.damaged")
        }
    }
}


struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(L.t("settings.lock"), isOn: Binding(get: { model.lockEnabled }, set: { model.lockEnabled = $0 }))
                        .accessibilityIdentifier("settings.lock")
                    Toggle(L.t("settings.reminder"), isOn: Binding(get: { model.reminderEnabled }, set: { model.reminderEnabled = $0 }))
                        .accessibilityIdentifier("settings.reminder")
                } footer: { Text(L.t("settings.reminder.note")) }
                Section {
                    Button(L.t("settings.import")) { importing = true }.accessibilityIdentifier("settings.import")
                    ShareLink(item: Exporter.storeURL, message: Text(L.t("settings.tell.message"))) {
                        Label(L.t("settings.tell"), systemImage: "heart")
                    }
                    .accessibilityIdentifier("settings.tell")
                }
                Section {
                    Text(L.t("settings.privacy")).font(.footnote).foregroundStyle(Palette.muted)
                    Link(L.t("settings.help"), destination: URL(string: "https://hgsldswk-alt.github.io/familyhandoff-support/")!)
                }
            }
            .navigationTitle(Text(L.t("settings.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("common.done")) { dismiss() }.accessibilityIdentifier("settings.done")
                }
            }
            .sheet(isPresented: $importing) { ImportView(initialText: "") }
        }
    }
}


struct DoneView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button(L.t("common.close")) { dismiss() }.foregroundStyle(.white).accessibilityIdentifier("done.close")
            }
            Spacer()
            DoneCard().accessibilityIdentifier("done.card")
            Spacer()
            if let image = ImageRenderer(content: DoneCard().frame(width: 360, height: 420)).uiImage {
                ShareLink(item: Image(uiImage: image), preview: SharePreview(L.t("done.title"), image: Image(uiImage: image))) {
                    Label(L.t("done.share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(AmberButton())
                .accessibilityIdentifier("done.share")
            }
            Text(L.t("done.private")).font(.caption).foregroundStyle(.white.opacity(0.65))
        }
        .padding(24)
        .background(LinearGradient(colors: [Palette.accent, Palette.accent.opacity(0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}

private struct AmberButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Palette.ink).background(Palette.amber, in: RoundedRectangle(cornerRadius: 15))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct DoneCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.white.opacity(0.12)).frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill").font(.system(size: 58)).foregroundStyle(Palette.amber)
            }
            Text(L.t("done.title")).font(.title2.bold()).multilineTextAlignment(.center)
            Text(L.t("done.subtitle")).font(.subheadline).opacity(0.8).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                if let qr = Exporter.qr(Exporter.storeURL.absoluteString, size: 120) {
                    Image(uiImage: qr).interpolation(.none).resizable().frame(width: 56, height: 56)
                        .padding(4).background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("app.name")).font(.footnote.bold())
                    Text("#FamilyHandoff").font(.caption).opacity(0.8)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.18)))
    }
}


struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}
