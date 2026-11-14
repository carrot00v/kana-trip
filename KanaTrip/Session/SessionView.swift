import SwiftUI

/// 홈과 장면 진입에서 세션(단계 하나)을 띄울 때 넘기는 값.
struct SessionRoute: Identifiable, Hashable {
    let stepID: String

    var id: String { stepID }
}

/// fullScreenCover 하나 안에서 단계 하나의 배우기 → P2 → 퀴즈 → P3 → 단어 읽기 → 완료를 이어서 보여 준다.
/// C1에서 다음 단계로 넘어갈 때도 같은 덮개 안에서 내용만 바꾼다 (scene-flow.md 2.1, 7번).
struct SessionView: View {
    let initialStep: TripStep
    /// 덮개를 닫고 장면 진입으로 돌아간다.
    let onClose: () -> Void
    /// 덮개를 닫고 홈까지 돌아간다.
    let onBackToList: () -> Void

    @Environment(ProgressStore.self) private var store
    @State private var run: StepRun?
    @State private var stage: Stage?

    private enum Stage: Hashable {
        case learn, quizIntro, quiz, wordsIntro, words, stepDone, sceneDone
    }

    var body: some View {
        Group {
            if let run, let stage {
                content(run, stage)
            } else {
                Color(.systemBackground)
            }
        }
        .fadeOnChange(of: "\(run?.step.id ?? "")-\(String(describing: stage))")
        .onAppear {
            if run == nil { start(initialStep) }
        }
    }

    @ViewBuilder
    private func content(_ run: StepRun, _ stage: Stage) -> some View {
        switch stage {
        case .learn:
            LearnSessionView(run: run, onClose: onClose) {
                run.finishLearning()
                self.stage = .quizIntro
            }
        case .quizIntro:
            PartIntroView(
                progress: quizProgress(run),
                title: L.quizIntroTitle,
                message: run.reviewKana.isEmpty ? L.quizIntroBody : L.quizIntroReview(run.reviewKana.count),
                kana: run.step.kana,
                marked: [],
                notice: nil,
                buttonTitle: L.quizStart,
                onClose: onClose
            ) { self.stage = .quiz }
        case .quiz:
            QuizSessionView(run: run, onClose: onClose) { self.stage = .wordsIntro }
        case .wordsIntro:
            let wrong = run.progress.quizWrong
            PartIntroView(
                progress: PartProgress(part: .words, done: 0, total: run.step.words.count),
                title: L.wordsIntroTitle,
                message: L.wordsIntroBody(step: run.step.name, count: run.step.words.count),
                kana: run.step.kana,
                marked: Set(wrong),
                // 다시 하는 단계는 틀린 글자를 기록하지 않고, 마지막 장면은 다음 장면이 없으므로 "다시 나와요" 안내를 하지 않는다.
                notice: wrong.isEmpty || run.isReplay || ContentLibrary.shared.scene(after: run.scene) == nil
                    ? nil : L.wrongKanaReturns(wrong),
                buttonTitle: L.wordsStart,
                onClose: onClose
            ) { self.stage = .words }
        case .words:
            WordSessionView(run: run, onClose: onClose) { finish(run) }
        case .stepDone:
            StepDoneView(run: run, onContinue: start, onClose: onClose)
        case .sceneDone:
            SceneDoneView(scene: run.scene, onBackToList: onBackToList)
        }
    }

    private func quizProgress(_ run: StepRun) -> PartProgress {
        let quiz = run.progress.quiz
        return PartProgress(part: .quiz, done: quiz?.doneCount ?? 0, total: quiz?.totalCount ?? run.step.kana.count * 2)
    }

    private func start(_ step: TripStep) {
        let next = StepRun(step: step, store: store)
        run = next
        switch next.entry {
        case .learn: stage = .learn
        case .quizIntro:
            next.finishLearning()
            stage = .quizIntro
        case .quiz: stage = .quiz
        case .wordsIntro: stage = .wordsIntro
        case .words: stage = .words
        }
    }

    /// 단어 읽기의 마지막 "완료". 단계 완료를 저장한 뒤 완료 화면을 고른다 (scene-flow.md 12번 전환).
    private func finish(_ run: StepRun) {
        let isLastStep = ContentLibrary.shared.step(after: run.step) == nil
        run.complete()
        // 단계 b를 처음 끝냈으면 장면 완료(C2)만, 그 밖에는 단계 완료(C1).
        stage = !run.isReplay && isLastStep ? .sceneDone : .stepDone
    }
}

/// P2 퀴즈 안내, P3 단어 읽기 안내 (scene-flow.md 7.3). 축하하지 않고 다음 구간에서 할 일만 알린다.
struct PartIntroView: View {
    let progress: PartProgress
    let title: String
    let message: String
    let kana: [String]
    /// 글자 밑에 점을 붙일 글자(P3의 틀린 글자).
    let marked: Set<String>
    let notice: String?
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
                        Text(message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        KanaRow(kana: kana, marked: marked)
                            .padding(.top, 24)
                        if let notice {
                            Text(notice)
                                .font(.subheadline)
                                .padding(.top, 16)
                        }
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
