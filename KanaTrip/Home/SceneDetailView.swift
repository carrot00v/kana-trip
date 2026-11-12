import SwiftUI

/// S 장면 진입. 이 장면에서 읽게 될 단어, 새 글자, 세션 3개의 상태를 보여 준다.
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
            goalWordSection

            Section {
                VStack(alignment: .leading, spacing: 8) {
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
        .listSectionSpacing(16)
        .contentMargins(.top, 8, for: .scrollContent)
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

    // MARK: - 목표 단어 카드

    /// 이 장면의 글자를 배우면 읽게 되는 단어. 배운 글자만 진하게 채운다. 누를 수 없다.
    @ViewBuilder
    private var goalWordSection: some View {
        let library = ContentLibrary.shared
        let groups = library.wordGroups(for: scene)
        let learned = library.learnedKana(in: scene, progress: store.progress(for: scene.id))
        let style: (String) -> WordGlyphStyle = { learned.contains($0) ? .learned : .unlearned }

        if !groups.goal.isEmpty || !groups.rest.isEmpty {
            Section {
                ForEach(groups.goal) { word in
                    goalWordRow(word, learnedCount: word.count(in: learned), style: style)
                }
                if !groups.rest.isEmpty {
                    unreadableRow(groups.rest, style: style)
                }
            } header: {
                Text(L.goalWordsHeader(scene: scene.name, allLearned: scene.kana.allSatisfy(learned.contains)))
                    .font(.footnote)
                    .textCase(nil)
            }
        }
    }

    private func goalWordRow(_ word: TripWord, learnedCount: Int, style: @escaping (String) -> WordGlyphStyle) -> some View {
        let total = word.units.count
        let readable = learnedCount == total
        return HStack(spacing: 12) {
            WordGlyphs(word: word, size: 28, style: style)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(word.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if readable {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark").foregroundStyle(.green)
                        Text(L.canRead)
                    }
                    .font(.footnote)
                } else {
                    Text(L.learnedCount(learnedCount, of: total))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minHeight: 40)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            KanaText.japanese(word.text)
                + AttributedString(", \(word.meaning), \(readable ? L.canRead : L.learnedCountLabel(learnedCount, of: total))")
        ))
    }

    private func unreadableRow(_ words: [TripWord], style: @escaping (String) -> WordGlyphStyle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.unreadableWords)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                ForEach(words) { word in
                    WordGlyphs(word: word, size: 17, spacing: 0, style: style)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            AttributedString("\(L.unreadableWords), ")
                + KanaText.japanese(words.map(\.text).joined(separator: ", "))
        ))
    }

    // MARK: - 새 글자와 세션 행

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
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(status == .locked)
        .accessibilityElement(children: .combine)
    }
}
