import SwiftUI

/// 홈과 장면 진입에서 세션을 띄울 때 넘기는 값.
struct SessionRoute: Identifiable, Hashable {
    let sessionID: String

    var id: String { sessionID }
}

/// fullScreenCover 하나 안에서 세션 하나를 이어서 보여 준다.
/// 단계 세션: 배우기 → P3 → 단어 읽기 → C1. 종합 퀴즈 세션: P2 → 퀴즈 → C2(처음 통과) 또는 C1(다시 함).
/// C1에서 다음 세션으로 넘어갈 때도 같은 덮개 안에서 내용만 바꾼다 (scene-flow.md 2.1).
struct SessionView: View {
    let initialSession: TripSession
    /// 덮개를 닫고 장면 진입으로 돌아간다.
    let onClose: () -> Void
    /// 덮개를 닫고 홈까지 돌아간다.
    let onBackToList: () -> Void
    /// 덮개를 닫고 홈 위에 기리 꾸미기를 띄운다 (reward-flow.md 2.2).
    let onCustomize: () -> Void

    @Environment(ProgressStore.self) private var store
    @State private var run: SessionRun?
    @State private var stage: Stage?

    private enum Stage: Hashable {
        case learn, wordsIntro, words, quizIntro, quiz
        case sessionDone(RewardGrant)
        case sceneDone(RewardGrant)
    }

    var body: some View {
        Group {
            if let run, let stage {
                content(run, stage)
            } else {
                Color.appBackground
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
            LearnSessionView(run: run, onClose: onClose) { self.stage = .wordsIntro }
        case .wordsIntro:
            if let step = run.step {
                PartIntroView(
                    progress: PartProgress(segments: PartProgress.stepSegments, part: .words, done: 0, total: step.words.count),
                    title: L.wordsIntroTitle,
                    message: L.wordsIntroBody(step: step.name, count: step.words.count),
                    kana: step.kana,
                    buttonTitle: L.wordsStart,
                    onClose: onClose
                ) { self.stage = .words }
            }
        case .words:
            WordSessionView(run: run, onClose: onClose) { finish(run) }
        case .quizIntro:
            PartIntroView(
                progress: PartProgress(segments: PartProgress.quizSegments, part: .quiz, done: 0, total: run.progress.quiz?.totalCount ?? 0),
                title: L.quizIntroTitle,
                message: run.reviewKana.isEmpty ? L.quizIntroBody : L.quizIntroReview(run.reviewKana.count),
                kana: run.scene.kana,
                buttonTitle: L.quizStart,
                onClose: onClose
            ) { self.stage = .quiz }
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
        case .wordsIntro: stage = .wordsIntro
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

/// 구간 안내 (scene-flow.md 7.3). 축하하지 않고 다음 구간에서 할 일만 알린다.
/// P2는 종합 퀴즈 세션의 첫 화면, P3은 단계 세션의 단어 읽기 앞이다.
struct PartIntroView: View {
    let progress: PartProgress
    let title: String
    let message: String
    let kana: [String]
    let buttonTitle: String
    let onClose: () -> Void
    let onStart: () -> Void

    var body: some View {
        SessionScaffold(progress: progress, onClose: onClose) {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Text(title)
                            .font(.title2.bold())
                            .foregroundStyle(Color.ink)
                        Text(message)
                            .font(.body)
                            .foregroundStyle(Color.inkSecondary)
                            .padding(.top, 8)
                        KanaRow(kana: kana, marked: [])
                            .padding(.top, 24)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, geo.size.height / 4)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        } bottom: {
            PrimaryButton(title: buttonTitle, action: onStart)
        }
    }
}
