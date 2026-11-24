import StoreKit
import SwiftUI

@main
struct FamilyHandoffApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            Root()
                .environmentObject(model)
                .onOpenURL { url in
                    guard url.isFileURL, let text = try? String(contentsOf: url, encoding: .utf8) else { return }
                    model.importText = text
                }
                .onChange(of: phase) { _, now in
                    if now == .background { model.relock() }
                }
        }
    }
}

private struct Root: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            NavigationStack { HomeView() }
                .tint(Palette.accent)
            if model.locked { LockView().transition(.opacity) }
        }
        .animation(.easeOut(duration: 0.2), value: model.locked)
    }
}

struct LockView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(Palette.amber)
            Text(L.t("lock.title")).font(.title2.bold()).foregroundStyle(.white)
            Text(L.t("lock.note")).font(.subheadline).foregroundStyle(.white.opacity(0.75))
            Spacer()
            Button(L.t("lock.unlock")) { model.unlock() }
                .buttonStyle(PrimaryButton())
                .accessibilityIdentifier("lock.unlock")
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Palette.accent, Palette.accent.opacity(0.85)], startPoint: .top, endPoint: .bottom))
        .onAppear { model.unlock() }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.requestReview) private var requestReview
    @State private var showHandoff = false
    @State private var showSettings = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    HStack(spacing: 14) {
                        ProgressRing(value: model.list.progress)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L.f("home.filled", model.list.filledCount)).font(.headline).foregroundStyle(Palette.ink)
                            Text(updatedLine).font(.footnote).foregroundStyle(Palette.muted)
                        }
                    }
                    .padding(14)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home.progress")

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Area.allCases) { group in
                        NavigationLink(value: group) { GroupTile(group: group) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("group.\(group.rawValue)")
                    }
                }

                Button(L.t("home.handoff")) { showHandoff = true }
                    .buttonStyle(PrimaryButton())
                    .accessibilityIdentifier("home.handoff")
                    .padding(.top, 6)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(Text(L.t("home.title")))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel(L.t("settings.title"))
                    .accessibilityIdentifier("home.settings")
            }
        }
        .navigationDestination(for: Area.self) { GroupView(group: $0) }
        .sheet(isPresented: $showHandoff) { HandoffSheet() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: Binding(get: { model.importText.map(ImportPayload.init) }, set: { model.importText = $0?.text })) {
            ImportView(initialText: $0.text)
        }
        .fullScreenCover(isPresented: $model.showDone) { DoneView() }
        .reviewAfterCoreAction(when: !model.showDone && !showHandoff) { requestReview() }
        .onAppear {
            guard model.pendingDone else { return }
            model.pendingDone = false
            model.showDone = true
        }
    }

    private var updatedLine: String {
        guard let updated = model.list.updated else { return L.t("home.private") }
        return L.f("home.updated", updated.formatted(.relative(presentation: .named)))
    }
}

struct ImportPayload: Identifiable {
    let text: String
    var id: String { text }
}

private struct GroupTile: View {
    @EnvironmentObject private var model: AppModel
    let group: Area

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: group.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(group.tint)
                    .frame(width: 36, height: 36)
                    .background(group.soft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text(L.t(group.titleKey)).font(.subheadline.bold()).foregroundStyle(Palette.ink)
                Text(L.t(group.hintKey)).font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                ProgressView(value: model.list.progress(in: group)).tint(Palette.accent)
            }
            .padding(12)
            .frame(minHeight: 112, alignment: .topLeading)
        }
    }
}
