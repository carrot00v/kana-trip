import SwiftUI

/// S 장면 진입. 새 글자와 세션 3개의 상태를 보여 준다.
struct SceneDetailView: View {
    let scene: TripScene
    let onStart: (SessionKind) -> Void
    let onBackToList: () -> Void

    @Environment(ProgressStore.self) private var store

    private enum RowStatus {
        case ready, inProgress, locked, completed
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L.newKanaCount(scene.kana.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    kanaRow
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }

            Section {
                ForEach(SessionKind.allCases, id: \.self) { kind in
                    sessionRow(kind)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(scene.name)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Group {
                if let next = store.nextSession(sceneID: scene.id) {
                    PrimaryButton(title: L.sessionAction(next, resume: store.isInProgress(next, sceneID: scene.id))) {
                        onStart(next)
                    }
                } else {
                    PrimaryButton(title: L.backToSceneList, action: onBackToList)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    /// 새 글자를 같은 폭으로 나눠 놓고 아래에 발음을 붙인다.
    private var kanaRow: some View {
        HStack(spacing: 0) {
            ForEach(ContentLibrary.shared.kana(for: scene)) { kana in
                VStack(spacing: 4) {
                    KanaText(text: kana.char, size: 34)
                    HStack(spacing: 2) {
                        Text(kana.romaji).font(.subheadline).foregroundStyle(.secondary)
                        if store.soundOn { SpeakerBadge().imageScale(.small) }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .accessibilityElement(children: .combine)
                .speaks(kana.char, enabled: store.soundOn)
            }
        }
    }

    private func status(_ kind: SessionKind) -> RowStatus {
        if store.isCompleted(kind, sceneID: scene.id) { return .completed }
        if !store.isUnlocked(kind, sceneID: scene.id) { return .locked }
        return store.isInProgress(kind, sceneID: scene.id) ? .inProgress : .ready
    }

    private func total(_ kind: SessionKind) -> Int {
        switch kind {
        case .learn: scene.kana.count
        case .quiz: scene.kana.count * 2
        case .words: scene.words.count
        }
    }

    private func description(_ kind: SessionKind, status: RowStatus) -> String {
        switch status {
        case .ready: L.sessionDescription(kind, scene: scene.name, wordCount: scene.words.count)
        case .inProgress: L.resumeAt(done: store.doneCount(kind, sceneID: scene.id), total: total(kind))
        case .locked: L.sessionLocked(kind)
        case .completed: L.doneRedo
        }
    }

    @ViewBuilder
    private func sessionRow(_ kind: SessionKind) -> some View {
        let status = status(kind)
        let number = (SessionKind.allCases.firstIndex(of: kind) ?? 0) + 1
        Button {
            onStart(kind)
        } label: {
            HStack(spacing: 12) {
                Group {
                    switch status {
                    case .ready, .inProgress:
                        Image(systemName: "\(number).circle.fill").foregroundStyle(Color.accentColor)
                    case .locked:
                        Image(systemName: "lock.fill").foregroundStyle(.secondary)
                    case .completed:
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .font(.title2)
                .frame(width: 28)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.sessionTitle(kind))
                        .font(.headline)
                        .foregroundStyle(status == .locked ? .secondary : .primary)
                    Text(description(kind, status: status))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if status != .locked {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(status == .locked)
        .accessibilityElement(children: .combine)
    }
}
