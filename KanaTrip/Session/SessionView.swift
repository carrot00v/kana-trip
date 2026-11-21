import SwiftUI

/// 홈과 장면 진입에서 세션을 띄울 때 넘기는 값.
struct SessionRoute: Identifiable, Hashable {
    let sessionID: String

    var id: String { sessionID }
}

/// fullScreenCover 하나 안에서 세션 하나를 이어서 보여 준다 (scene-flow.md 1번).
/// 단계 세션: 배우기 → 단어 읽기 → C1. 종합 퀴즈 세션: QI → 부 1~3 → C2(처음 통과) 또는 C1(다시 함).
/// C1에서 다음 세션으로 넘어갈 때도 같은 덮개 안에서 내용만 바꾼다 (2.1).
struct SessionView: View {
    let initialSession: TripSession
    /// 덮개를 닫고 지도로 돌아간다. 어디서 열었든 지도다 (home-map.md 3.4). 닫기, C1 "여기까지 하기"·"지도로 돌아가기".
    let onClose: () -> Void
    /// 덮개를 닫고 지도로 돌아간다(C2 "지도로 돌아가기"). 지금은 `onClose`와 같은 곳이다.
    let onBackToList: () -> Void
    /// 덮개를 닫고 지도 위에 기리 꾸미기를 띄운다 (reward-flow.md 2.2, home-map.md 3.4).
    let onCustomize: () -> Void

    @Environment(ProgressStore.self) private var store
    @State private var run: SessionRun?
    @State private var stage: Stage?

    private enum Stage: Hashable {
        case learn, words, quizIntro, quiz
        case sessionDone(RewardGrant)
        case sceneDone(RewardGrant)
    }

    var body: some View {
        Group {
            if let run, let stage {
                content(run, stage)
            } else {
                Color.clear.skinBackground(SkinPolicy.learningLevel)
            }
        }
        .fadeOnChange(of: "\(run?.session.id ?? "")-\(String(describing: stage))")
        .onAppear {
            if run == nil { start(initialSession) }
        }
    }

    @ViewBuilder
    private func content(_ run: SessionRun, _ stage: Stage) -> some View {
        switch stage {
        case .learn:
            // 안내 화면 없이 바로 단어 읽기로 (scene-flow.md 7.3).
            LearnSessionView(run: run, onClose: onClose) { self.stage = .words }
        case .words:
            WordSessionView(run: run, onClose: onClose) { finish(run) }
        case .quizIntro:
            QuizIntroView(run: run, onClose: onClose) { self.stage = .quiz }
        case .quiz:
            QuizSessionView(run: run, onClose: onClose) { finish(run) }
        case .sessionDone(let grant):
            StepDoneView(run: run, grant: grant, onContinue: start, onClose: onClose)
        case .sceneDone(let grant):
            SceneDoneView(scene: run.scene, quizWrong: run.progress.quizWrong, grant: grant,
                          onBackToList: onBackToList, onCustomize: onCustomize)
        }
    }

    private func start(_ session: TripSession) {
        let next = SessionRun(session: session, store: store)
        run = next
        switch next.entry {
        case .learn: stage = .learn
        case .words: stage = .words
        case .quizIntro:
            next.prepareQuiz()
            stage = .quizIntro
        case .quiz: stage = .quiz
        }
    }

    /// 세션의 마지막 항목을 끝낸 뒤. 완료와 지급을 저장하고 완료 화면을 고른다.
    private func finish(_ run: SessionRun) {
        let grant = run.complete()
        // 종합 퀴즈를 처음 통과하면 장면 완료(C2), 그 밖에는 세션 완료(C1).
        stage = run.session.isQuiz && !run.isReplay ? .sceneDone(grant) : .sessionDone(grant)
    }
}

/// QI 퀴즈 안내 (scene-flow.md 12.5). 무엇이 몇 문항 나오는지 보여 주고 시작하게 한다. 축하하지 않는다.
struct QuizIntroView: View {
    let run: SessionRun
    let onClose: () -> Void
    let onStart: () -> Void

    var body: some View {
        let quiz = run.progress.quiz
        let parts = quiz?.parts ?? []
        SessionScaffold(
            progress: .quiz(partIndex: 0, partCount: parts.count, done: 0, total: parts.first?.items.count ?? 0, partName: nil),
            level: .medium,
            onClose: onClose
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    // 기리가 퀴즈를 안내한다(120pt, 말하기, 최대 4줄). 지금의 가운데 기리와 설명 줄을 대신한다 (giri-companion.md 3.7).
                    GiriSpeechRow(
                        pose: .talk,
                        text: GiriSpeech.quizIntro(scene: run.scene.name, isReplay: run.isReplay),
                        size: 120,
                        maxLines: 4,
                        expandsAtLargeType: true
                    )
                    .padding(.top, 16)
                    VStack(spacing: 0) {
                        Text(L.quizTitle(scene: run.scene.name))
                            .font(.title2.bold())
                            .foregroundStyle(Color.ink)
                            .padding(.top, 16)
                        KanaRow(kana: run.scene.kana, marked: [])
                            .padding(.top, 24)
                        VStack(spacing: 0) {
                            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                                HStack {
                                    Text(L.quizPartName(part.kind))
                                        .foregroundStyle(Color.ink)
                                    Spacer()
                                    Text(L.questionCount(part.items.count))
                                        .monospacedDigit()
                                        .foregroundStyle(Color.inkSecondary)
                                }
                                .font(.body)
                                .frame(minHeight: 28)
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        if let review = quiz?.review, !review.isEmpty {
                            Text(L.reviewIncluded(review))
                                .font(.subheadline)
                                .foregroundStyle(Color.ink)
                                .padding(.top, 16)
                        }
                        Text(L.resumeAnytime)
                            .font(.footnote)
                            .foregroundStyle(Color.inkSecondary)
                            .padding(.top, 8)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        } bottom: {
            PrimaryButton(title: L.quizStart, action: onStart)
        }
    }
}
