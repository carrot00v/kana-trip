import SwiftUI

/// 종합 퀴즈 세션. `QuizProgress`의 부(유형)를 차례로 풀고, 틀린 항목은 그 부의 끝에 다시 나온다.
/// 문항은 장면의 새 글자 전부 + 앞 장면 복습 글자이고, 퀴즈 안내(P2)에서 `SessionRun.prepareQuiz()`가 만든다.
/// 유형을 더할 때는 `QuizKind`에 case를 두고 `loadNext()`에서 화면을 잇는다.
struct QuizSessionView: View {
    let run: SessionRun
    let onClose: () -> Void
    let onFinished: () -> Void

    @State private var item: Item?
    @State private var itemSerial = 0

    /// 지금 화면에 낸 항목. 답한 결과는 바로 저장하지만 화면은 "다음"을 누를 때까지 그대로 둔다.
    private enum Item {
        case choice(Kana, options: [String])
        case write(Kana)
    }

    private var partProgress: PartProgress {
        let quiz = run.progress.quiz
        return PartProgress(segments: PartProgress.quizSegments, part: .quiz, done: quiz?.doneCount ?? 0, total: quiz?.totalCount ?? 0)
    }

    var body: some View {
        Group {
            switch item {
            case .choice(let kana, let options):
                ChoiceQuestionView(
                    kana: kana, options: options, progress: partProgress, onClose: onClose,
                    onAnswered: { correct in run.answer(kana.char, correct: correct) },
                    onNext: loadNext
                )
                .id(itemSerial)
            case .write(let kana):
                RecallWriteView(
                    kana: kana, progress: partProgress, onClose: onClose,
                    onGuideUsed: { run.markGuideUsed(kana.char) },
                    // 가이드를 본 글자는 틀린 것으로 보고 부의 끝에 다시 낸다.
                    onCompleted: { usedGuide in run.answer(kana.char, correct: !usedGuide) },
                    onNext: loadNext
                )
                .id(itemSerial)
            case nil:
                Color.appBackground
            }
        }
        .fadeOnChange(of: itemSerial)
        .onAppear {
            if item == nil { loadNext() }
        }
    }

    private func loadNext() {
        let library = ContentLibrary.shared
        guard let quiz = run.progress.quiz else { return }
        itemSerial += 1
        guard let index = quiz.currentPartIndex else {
            item = nil
            onFinished()
            return
        }
        let part = quiz.parts[index]
        guard let char = part.queue.first, let kana = library.kana(char) else { return }
        switch part.kind {
        case .readingChoice: item = .choice(kana, options: ChoiceOptions.make(for: kana, library: library))
        case .recallWrite: item = .write(kana)
        }
    }
}

/// 사지선다 선택지 (scene-flow.md 10.1). 정답 하나와 오답 셋, 자리는 문항마다 섞는다.
enum ChoiceOptions {
    static let count = 4

    /// 오답은 아래 순서로 채운다. 같은 로마자는 두 번 나오지 않는다.
    /// 1. 그 글자가 배정된 단계의 다른 새 글자 전부(섞은 순서). 복습 글자도 원래 단계 기준이다.
    /// 2. 같은 장면의 다른 단계 글자에서 무작위.
    /// 3. 앞 장면들의 새 글자에서 무작위.
    /// 4. 다음 장면의 새 글자에서 무작위.
    static func make(for kana: Kana, library: ContentLibrary) -> [String] {
        var options = [kana.romaji]
        func add(_ chars: [String]) {
            for char in chars.shuffled() where options.count < count {
                guard let romaji = library.kana(char)?.romaji, !options.contains(romaji) else { continue }
                options.append(romaji)
            }
        }
        if let step = library.homeStep(of: kana.char), let scene = library.scene(of: step) {
            add(step.kana)
            add(scene.steps.filter { $0.id != step.id }.flatMap(\.kana))
            add(Array(library.kana(before: scene)))
            if let next = library.scene(after: scene) { add(next.kana) }
        }
        return options.shuffled()
    }
}

// MARK: - Q1 사지선다

struct ChoiceQuestionView: View {
    let kana: Kana
    let options: [String]
    let progress: PartProgress
    let onClose: () -> Void
    let onAnswered: (Bool) -> Void
    let onNext: () -> Void

    @Environment(ProgressStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var picked: String?
    @State private var correctTick = 0
    @State private var wrongTick = 0

    private var answered: Bool { picked != nil }

    var body: some View {
        SessionScaffold(progress: progress, onClose: onClose) {
            VStack(spacing: 8) {
                ScrollView {
                    VStack(spacing: 24) {
                        Text(L.choiceQuestion)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        VStack(spacing: 8) {
                            KanaGlyphView(kana: kana, side: 160)
                            // 답하기 전에는 소리가 답을 알려 주므로 아이콘도 재생도 없다.
                            SpeakerBadge().opacity(answered && store.soundOn ? 1 : 0)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(answered ? Text(KanaText.japanese(kana.char)) : Text(L.questionGlyph))
                        .speaks(kana.char, enabled: answered && store.soundOn)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                verdict

                let columns = typeSize.isAccessibilitySize ? 1 : 2
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        choice(option)
                    }
                }
                .padding(.horizontal, 16)
            }
        } bottom: {
            PrimaryButton(title: L.next, enabled: answered, action: onNext)
        }
        .sensoryFeedback(.success, trigger: correctTick)
        .sensoryFeedback(.error, trigger: wrongTick)
    }

    @ViewBuilder
    private var verdict: some View {
        if let picked {
            if picked == kana.romaji {
                VerdictLine(kind: .good, text: L.choiceCorrect)
            } else {
                VerdictLine(kind: .bad, text: L.choiceAnswer(kana.romaji))
            }
        } else {
            Color.clear.frame(height: VerdictLine.height)
        }
    }

    private func choice(_ option: String) -> some View {
        let isAnswer = option == kana.romaji
        let isPicked = option == picked
        // 답한 뒤: 정답 칸은 초록, 잘못 고른 칸은 빨강 외곽선(3pt), 나머지는 흐리게.
        let mark: (icon: String, color: Color)? = !answered ? nil
            : isAnswer ? ("checkmark.circle.fill", .correct)
            : isPicked ? ("xmark.circle.fill", .wrong)
            : nil

        return Button {
            pick(option)
        } label: {
            Text(option)
                .font(.title2.bold())
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                .cardOutline(
                    cornerRadius: 16,
                    color: mark?.color ?? .outline,
                    lineWidth: mark == nil ? AppStyle.outlineWidth : AppStyle.verdictOutlineWidth
                )
                .overlay(alignment: .topTrailing) {
                    if let mark {
                        Image(systemName: mark.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(mark.color)
                            .padding(8)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .opacity(answered && mark == nil ? AppStyle.dimmedOpacity : 1)
        .animation(.easeInOut(duration: 0.15), value: picked)
        .allowsHitTesting(!answered)
        .accessibilityLabel(
            !answered ? option
                : isAnswer ? "\(option), \(L.correctAnswer)"
                : isPicked ? "\(option), \(L.myWrongAnswer)"
                : option
        )
    }

    private func pick(_ option: String) {
        guard picked == nil else { return }
        picked = option
        let correct = option == kana.romaji
        if correct { correctTick += 1 } else { wrongTick += 1 }
        AccessibilityNotification.Announcement(correct ? L.choiceCorrect : L.choiceAnswer(kana.romaji)).post()
        onAnswered(correct)
    }
}

// MARK: - Q2 기억으로 쓰기

struct RecallWriteView: View {
    /// 한 글자에서 획을 이만큼 틀리면 가이드가 켜진다.
    static let mistakesBeforeGuide = 3

    let kana: Kana
    let progress: PartProgress
    let onClose: () -> Void
    let onGuideUsed: () -> Void
    let onCompleted: (_ usedGuide: Bool) -> Void
    let onNext: () -> Void

    @Environment(ProgressStore.self) private var store
    @State private var attempt = WritingAttempt()
    @State private var guideOn = false
    /// 가이드가 방금 켜져서 판정 줄에 안내를 보여 주는 중인지. 다음 획을 그으면 꺼진다.
    @State private var showsGuideNotice = false
    @State private var isDrawing = false

    private var finished: Bool { attempt.isFinished(strokeCount: kana.strokes.count) }

    var body: some View {
        SessionScaffold(progress: progress, onClose: onClose) {
            VStack(spacing: 8) {
                Text(L.recallQuestion)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                HStack(spacing: 4) {
                    Text(kana.romaji).font(.system(size: 48))
                    if store.soundOn { SpeakerBadge() }
                }
                .frame(minHeight: 64)
                .speaks(kana.char, enabled: store.soundOn)

                Spacer(minLength: 0)

                if showsGuideNotice {
                    VerdictLine(kind: .guide, text: L.guideOn)
                } else {
                    VerdictLine.forAttempt(
                        attempt.feedback,
                        idleText: L.recallHint,
                        finishedText: guideOn ? L.recallFinishedWithGuide : L.recallFinished
                    )
                }

                WritingPad(
                    kana: kana,
                    showGuide: guideOn,
                    attempt: $attempt,
                    revealsKanaToVoiceOver: false,
                    finishedAnnouncement: guideOn ? L.recallFinishedWithGuide : L.recallFinished,
                    isDrawing: $isDrawing,
                    onRejectedCleared: {
                        // 3번째 틀린 획의 빨간 표시가 사라진 뒤 자동으로 켠다.
                        if attempt.mistakes >= Self.mistakesBeforeGuide { turnGuideOn() }
                    }
                )
                .padding(.horizontal, 16)
            }
        } bottom: {
            Group {
                SecondaryButton(title: L.showGuide, enabled: !guideOn && !finished, action: turnGuideOn)
                PrimaryButton(title: L.next, enabled: finished, action: onNext)
            }
            .allowsHitTesting(!isDrawing)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onChange(of: isDrawing) { _, drawing in
            if drawing { showsGuideNotice = false }
        }
        .onChange(of: attempt.feedback) { _, feedback in
            // 완성한 시점에 결과를 저장한다. "다음"을 누르기 전에 나가도 남는다.
            if case .finished = feedback { onCompleted(guideOn) }
        }
    }

    private func turnGuideOn() {
        guard !guideOn, !finished else { return }
        guideOn = true
        showsGuideNotice = true
        onGuideUsed()
        AccessibilityNotification.Announcement(L.guideOn).post()
    }
}
