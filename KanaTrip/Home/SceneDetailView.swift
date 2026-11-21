import SwiftUI

/// S 장면 진입 (scene-flow.md 6번). 단계마다 섹션 하나(세션 행 → 목표 단어 행 → 못 읽는 단어 줄),
/// 마지막에 종합 퀴즈 섹션(세션 행만).
struct SceneDetailView: View {
    let scene: TripScene
    let onStart: (TripSession) -> Void
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
        let next = store.nextSession(in: scene)
        ScrollViewReader { proxy in
            List {
                GiriListBubble(text: GiriSpeech.scene(store.giriSceneTurn(scene)))
                ForEach(library.sessions(in: scene)) { session in
                    Section {
                        sessionRow(session)
                            .id(session.id)
                            .onAppear { visibleSteps.insert(session.id) }
                            .onDisappear { visibleSteps.remove(session.id) }
                            .listRowBackground(Color.cardBackground)
                        if let step = session.step {
                            wordRows(step, learned: learned)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
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
            // 기리 줄 + 주 버튼 (giri-companion.md 3.3). 장면 그림 움직임(김 카드)은 단어 그림으로 옮겨(word-art.md 7번)
            // 이 화면의 반복 움직임은 기리 숨쉬기 하나다.
            GiriBottomDock(text: GiriSpeech.scene(store.giriSceneTurn(scene))) {
                let next = store.nextSession(in: scene)
                if let next {
                    PrimaryButton(title: L.stepAction(L.sessionName(next), resume: store.isInProgress(next))) {
                        onStart(next)
                    }
                } else if store.isSceneCompleted(scene) {
                    PrimaryButton(title: L.backToSceneList, action: onBackToList)
                }
            }
        }
        .skinBackground(.medium)
    }

    // MARK: - 세션 행 (6.1, 6.2)

    private func status(_ session: TripSession) -> StepStatus {
        if store.isCompleted(session) { return .completed }
        if !store.isUnlocked(session) { return .locked }
        return store.isInProgress(session) ? .inProgress : .ready
    }

    private func quizLine(_ status: StepStatus) -> String {
        if status == .locked {
            return L.quizRowLocked(previous: scene.steps.last?.name ?? "")
        }
        let summary = store.quizSummary(for: scene)
        return L.quizRowSummary(kana: scene.kana.count, words: summary.words, review: summary.review)
    }

    /// 세션 행의 아랫줄 글자: 단계는 그 단계의 새 글자, 종합 퀴즈는 장면의 글자 전부.
    private func kana(_ session: TripSession) -> [String] {
        session.step?.kana ?? scene.kana
    }

    @ViewBuilder
    private func sessionRow(_ session: TripSession) -> some View {
        let status = status(session)
        Button {
            onStart(session)
        } label: {
            HStack(spacing: 12) {
                Group {
                    switch status {
                    case .ready, .inProgress:
                        Image(systemName: "\(session.number).circle.fill").foregroundStyle(SkinColor.accent)
                    case .locked:
                        Image(systemName: "lock.fill").foregroundStyle(Color.inkSecondary)
                    case .completed:
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.correct)
                    }
                }
                .font(.title2)
                .frame(width: 28)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L.sessionName(session))
                        .font(.headline)
                        .foregroundStyle(status == .locked ? Color.inkSecondary : Color.ink)
                    if session.isQuiz {
                        // 퀴즈 행의 아랫줄 (scene-flow.md 6.3).
                        Text(quizLine(status))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } else {
                        KanaText(text: kana(session).joined(separator: " "), size: 20)
                            .foregroundStyle(status == .locked ? Color.inkSecondary : Color.ink)
                    }
                }

                Spacer(minLength: 0)

                if status != .locked {
                    switch status {
                    case .inProgress:
                        Text(L.resumeShort).font(.subheadline).foregroundStyle(Color.inkSecondary)
                    case .completed:
                        Text(L.done).font(.subheadline).foregroundStyle(Color.inkSecondary)
                    default:
                        EmptyView()
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
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
        .accessibilityLabel(accessibilityLabel(session, status: status))
        .accessibilityAddTraits(.isButton)
    }

    private func accessibilityLabel(_ session: TripSession, status: StepStatus) -> String {
        let name = L.sessionName(session)
        switch status {
        case .locked:
            let previous = library.sessions(in: scene).last { $0.number < session.number }.map(L.sessionName) ?? ""
            return L.stepRowLockedLabel(number: session.number, name: name, previous: previous)
        case .ready:
            return L.stepRowLabel(number: session.number, name: name, kana: kana(session), status: L.myTurn)
        case .inProgress:
            return L.stepRowLabel(number: session.number, name: name, kana: kana(session), status: L.resumeLabel)
        case .completed:
            return L.stepRowLabel(number: session.number, name: name, kana: kana(session), status: L.doneRedoLabel)
        }
    }

    // MARK: - 목표 단어 행과 못 읽는 단어 줄 (6.3, 6.4)

    @ViewBuilder
    private func wordRows(_ step: TripStep, learned: Set<String>) -> some View {
        let style: (String) -> WordGlyphStyle = { learned.contains($0) ? .learned : .unlearned }
        ForEach(library.shownGoalWords(for: step)) { word in
            goalWordRow(word, learnedCount: word.count(in: learned), style: style)
                .listRowBackground(Color.cardBackground)
        }
        let rest = library.shownRestWords(for: step)
        if !rest.isEmpty {
            unreadableRow(rest, style: style)
                .listRowBackground(Color.cardBackground)
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
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                if readable {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark").foregroundStyle(Color.correct)
                        Text(L.canRead)
                    }
                    .font(.footnote)
                } else {
                    Text(L.learnedCount(learnedCount, of: total))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Color.inkSecondary)
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
                .foregroundStyle(Color.inkSecondary)
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
