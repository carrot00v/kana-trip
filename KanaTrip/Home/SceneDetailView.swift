import SwiftUI

/// S 장면 진입 (scene-flow.md 6번). 단계마다 섹션 하나: 단계 행 → 목표 단어 행 → 못 읽는 단어 줄.
struct SceneDetailView: View {
    let scene: TripScene
    let onStart: (TripStep) -> Void
    let onBackToList: () -> Void

    @Environment(ProgressStore.self) private var store
    /// 화면에 들어와 있는 단계 행. 할 차례인 행이 보이지 않을 때만 자동으로 스크롤한다.
    @State private var visibleSteps: Set<String> = []
    @State private var didAutoScroll = false

    private enum StepStatus {
        case ready, inProgress, completed, locked
    }

    private var library: ContentLibrary { .shared }

    var body: some View {
        let learned = store.learnedKana(in: scene)
        let next = store.nextStep(in: scene)
        ScrollViewReader { proxy in
            List {
                ForEach(scene.steps) { step in
                    Section {
                        stepRow(step)
                            .id(step.id)
                            .onAppear { visibleSteps.insert(step.id) }
                            .onDisappear { visibleSteps.remove(step.id) }
                        wordRows(step, learned: learned)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(16)
            .contentMargins(.top, 8, for: .scrollContent)
            .task {
                // 할 차례·하던 중인 단계 행이 보이는 영역 밖이면 맨 위로 올린다 (6.6). 애니메이션 없이.
                guard !didAutoScroll, let next else { return }
                didAutoScroll = true
                try? await Task.sleep(for: .milliseconds(100))
                if !visibleSteps.contains(next.id) {
                    proxy.scrollTo(next.id, anchor: .top)
                }
            }
        }
        .navigationTitle(scene.name)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Group {
                if let next {
                    PrimaryButton(title: L.stepAction(next.name, resume: store.isInProgress(next))) {
                        onStart(next)
                    }
                } else if store.isSceneCompleted(scene) {
                    PrimaryButton(title: L.backToSceneList, action: onBackToList)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 단계 행 (6.1, 6.2)

    private func status(_ step: TripStep) -> StepStatus {
        if store.isCompleted(step) { return .completed }
        if !store.isUnlocked(step) { return .locked }
        return store.isInProgress(step) ? .inProgress : .ready
    }

    @ViewBuilder
    private func stepRow(_ step: TripStep) -> some View {
        let status = status(step)
        Button {
            onStart(step)
        } label: {
            HStack(spacing: 12) {
                Group {
                    switch status {
                    case .ready, .inProgress:
                        Image(systemName: "\(step.number).circle.fill").foregroundStyle(Color.accentColor)
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
                    Text(step.name)
                        .font(.headline)
                        .foregroundStyle(status == .locked ? .secondary : .primary)
                    KanaText(text: step.kana.joined(separator: " "), size: 20)
                        .foregroundStyle(status == .locked ? .secondary : .primary)
                }

                Spacer(minLength: 0)

                if status != .locked {
                    switch status {
                    case .inProgress:
                        Text(L.resumeShort).font(.subheadline).foregroundStyle(.secondary)
                    case .completed:
                        Text(L.done).font(.subheadline).foregroundStyle(.secondary)
                    default:
                        EmptyView()
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 50)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(status == .locked)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(step, status: status))
        .accessibilityAddTraits(.isButton)
    }

    private func accessibilityLabel(_ step: TripStep, status: StepStatus) -> String {
        switch status {
        case .locked:
            let previous = scene.steps.last { $0.index < step.index }?.name ?? ""
            return L.stepRowLockedLabel(number: step.number, name: step.name, previous: previous)
        case .ready:
            return L.stepRowLabel(number: step.number, name: step.name, kana: step.kana, status: L.myTurn)
        case .inProgress:
            return L.stepRowLabel(number: step.number, name: step.name, kana: step.kana, status: L.resumeLabel)
        case .completed:
            return L.stepRowLabel(number: step.number, name: step.name, kana: step.kana, status: L.doneRedoLabel)
        }
    }

    // MARK: - 목표 단어 행과 못 읽는 단어 줄 (6.3, 6.4)

    @ViewBuilder
    private func wordRows(_ step: TripStep, learned: Set<String>) -> some View {
        let style: (String) -> WordGlyphStyle = { learned.contains($0) ? .learned : .unlearned }
        ForEach(library.shownGoalWords(for: step)) { word in
            goalWordRow(word, learnedCount: word.count(in: learned), style: style)
        }
        let rest = library.shownRestWords(for: step)
        if !rest.isEmpty {
            unreadableRow(rest, style: style)
        }
    }

    private func goalWordRow(_ word: TripWord, learnedCount: Int, style: @escaping (String) -> WordGlyphStyle) -> some View {
        let total = word.kanaUnits.count
        // 탁음 칸은 배운 글자에 들지 않으므로 탁음이 든 단어(3a의 うどん, そば)는 "읽을 수 있어요"가 되지 않는다.
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
            CenteredFlow(spacing: 16, lineSpacing: 6, alignment: .leading) {
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
}
