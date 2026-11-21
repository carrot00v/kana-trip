import SwiftUI

/// 종합 퀴즈 세션의 문항 화면들. 부(유형)를 차례로 풀고, 틀린 문항은 그 부의 끝에 다시 나온다 (quiz-rules.md 5.1, scene-flow.md 12번).
/// 문항 목록은 QI에서 `SessionRun.prepareQuiz()`가 만들어 저장한다. 유형을 더할 때는 `QuizKind`와 `content(_:)`에 잇는다.
struct QuizSessionView: View {
    let run: SessionRun
    let onClose: () -> Void
    let onFinished: () -> Void

    /// 지금 화면에 낸 문항과 그 문항이 속한 부. 답한 결과는 바로 저장하지만 화면은 "다음"을 누를 때까지 그대로 둔다.
    @State private var shown: (item: QuizItem, partIndex: Int, header: QuizPartHeader)?
    @State private var itemSerial = 0

    private var quiz: QuizProgress? { run.progress.quiz }

    var body: some View {
        Group {
            if let shown, let quiz {
                content(shown.item, partIndex: shown.partIndex, header: shown.header, quiz: quiz)
                    .id(itemSerial)
            } else {
                Color.clear.skinBackground(SkinPolicy.learningLevel)
            }
        }
        .fadeOnChange(of: itemSerial)
        .onAppear {
            if shown == nil { loadNext() }
        }
    }

    @ViewBuilder
    private func content(_ item: QuizItem, partIndex: Int, header: QuizPartHeader, quiz: QuizProgress) -> some View {
        let part = quiz.parts[partIndex]
        let progress = PartProgress.quiz(partIndex: partIndex, partCount: quiz.parts.count,
                                         done: part.done.count, total: part.items.count, partName: L.quizPartName(part.kind))
        // 마지막 문항을 맞히면 "완료" (scene-flow.md 12.6).
        let nextTitle = quiz.isFinished ? L.done : L.next
        let library = ContentLibrary.shared
        // 질문은 기리가 한다 (giri-companion.md 3.8, 3.11).
        let giriQuestion = GiriSpeech.question(kind: item.kind, isPartStart: header.isPartStart, isRetry: header.isRetry)
        switch item.kind {
        case .readingChoice:
            if let char = item.kana, let kana = library.kana(char) {
                ChoiceQuestionView(
                    header: header, giriQuestion: giriQuestion, item: item, progress: progress,
                    nextTitle: nextTitle, singleColumn: false, onClose: onClose,
                    wrongLine: { picked in GiriSpeech.wrongAnswer(item: item, picked: picked, word: nil, lookup: library) },
                    onAnswered: { picked in answer(item, picked: picked) }, onNext: loadNext
                ) { answered in
                    GlyphProblem(kana: kana, answered: answered)
                }
            }
        case .wordReading:
            if let text = item.word, let word = library.word(text: text) {
                // 보기 가운데 하나라도 2열 칸에 안 들어가면 한 줄 목록으로 (scene-flow.md 13.5).
                let long = ([item.answer] + item.wrongs.map(\.romaji)).contains { $0.count > 10 }
                ChoiceQuestionView(
                    header: header, giriQuestion: giriQuestion, item: item, progress: progress,
                    nextTitle: nextTitle, singleColumn: long, onClose: onClose,
                    wrongLine: { picked in GiriSpeech.wrongAnswer(item: item, picked: picked, word: word, lookup: library) },
                    onAnswered: { picked in answer(item, picked: picked) }, onNext: loadNext
                ) { answered in
                    WordProblem(word: word, learned: QuizBuilder.learned(through: run.scene, library: library), answered: answered)
                }
            }
        case .recallWrite:
            if let char = item.kana, let kana = library.kana(char) {
                RecallWriteView(
                    kana: kana, header: header, giriQuestion: giriQuestion, progress: progress, nextTitle: nextTitle, onClose: onClose,
                    onGuideUsed: { run.markGuideUsed(kana.char) },
                    // 가이드를 본 글자는 틀린 것으로 보고 부의 끝에 다시 낸다.
                    onCompleted: { usedGuide in run.answerCurrent(correct: !usedGuide, wrongKana: kana.char) },
                    onNext: loadNext
                )
            }
        }
    }

    private func answer(_ item: QuizItem, picked: String) {
        let correct = picked == item.answer
        run.answerCurrent(correct: correct, wrongKana: correct ? nil : item.wrongKana(picked: picked))
    }

    private func loadNext() {
        guard let quiz, let partIndex = quiz.currentPartIndex, let item = quiz.currentItem else {
            shown = nil
            if quiz?.isFinished == true { onFinished() }
            return
        }
        itemSerial += 1
        shown = (item, partIndex, QuizPartHeader(quiz: quiz, partIndex: partIndex))
        if case .partStart(let name, let count) = shown?.header {
            AccessibilityNotification.Announcement(L.partStartLabel(name: name, count: count)).post()
        }
    }
}

/// 부 머리 줄 (scene-flow.md 12.4).
enum QuizPartHeader: Equatable {
    /// 두 번째 부부터 부의 첫 문항: "여기부터 {부 이름} {m}문항".
    case partStart(name: String, count: Int)
    /// "{부 이름} {k} / {m}".
    case position(name: String, index: Int, count: Int)
    /// "다시 풀기 · {남은 수}개 남음".
    case retry(remaining: Int)

    init(quiz: QuizProgress, partIndex: Int) {
        let part = quiz.parts[partIndex]
        let name = L.quizPartName(part.kind)
        guard let id = part.queue.first else {
            self = .position(name: name, index: part.items.count, count: part.items.count)
            return
        }
        if part.isRetrying {
            self = .retry(remaining: part.queue.filter(part.missed.contains).count)
            return
        }
        let index = (part.items.firstIndex { $0.id == id } ?? 0) + 1
        self = index == 1 && partIndex > 0 ? .partStart(name: name, count: part.items.count)
            : .position(name: name, index: index, count: part.items.count)
    }

    var isPartStart: Bool {
        if case .partStart = self { return true }
        return false
    }

    var isRetry: Bool {
        if case .retry = self { return true }
        return false
    }
}

struct QuizPartHeaderView: View {
    let header: QuizPartHeader

    var body: some View {
        Group {
            switch header {
            case .partStart(let name, let count):
                Text(L.partStart(name: name, count: count))
                    .bold()
                    .foregroundStyle(Color.ink)
            case .position(let name, let index, let count):
                Text("\(name) \(index) / \(count)")
                    .monospacedDigit()
                    .foregroundStyle(Color.inkSecondary)
            case .retry(let remaining):
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(L.retryRemaining(remaining))
                }
                .foregroundStyle(Color.inkSecondary)
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// QA의 문제: 획 데이터로 그린 글자 160pt.
private struct GlyphProblem: View {
    let kana: Kana
    let answered: Bool

    @Environment(ProgressStore.self) private var store

    var body: some View {
        VStack(spacing: 8) {
            KanaGlyphView(kana: kana, side: 160)
            // 답하기 전에는 소리가 답을 알려 주므로 아이콘도 재생도 없다.
            SpeakerBadge().opacity(answered && store.soundOn ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(answered ? Text(KanaText.japanese(kana.char)) : Text(L.questionGlyph))
        .speaks(kana: kana.char, enabled: answered && store.soundOn)
    }
}

/// QD의 문제: 단어 읽기(W)와 같은 단어 블록. 답한 뒤 아래에 뜻.
private struct WordProblem: View {
    let word: TripWord
    let learned: Set<String>
    let answered: Bool

    @Environment(ProgressStore.self) private var store

    var body: some View {
        VStack(spacing: 8) {
            WordBlock(word: word, learned: learned, soundOn: store.soundOn)
            Text(word.meaning)
                .font(.body)
                .foregroundStyle(Color.inkSecondary)
                .frame(height: 26)
                .opacity(answered ? 1 : 0)
                .accessibilityHidden(!answered)
        }
        .speaks(word: word.text, enabled: answered && store.soundOn)
    }
}

// MARK: - QA·QD 고르기

struct ChoiceQuestionView<Problem: View>: View {
    let header: QuizPartHeader
    /// 기리가 하는 질문 (3.11).
    let giriQuestion: String
    let item: QuizItem
    let progress: PartProgress
    let nextTitle: String
    /// 보기를 한 줄 목록으로 그릴지 (긴 로마자 단어).
    let singleColumn: Bool
    let onClose: () -> Void
    /// 고른 오답에 기리가 짚는 말 (giri-lines.md 6.1).
    let wrongLine: (String) -> String?
    let onAnswered: (String) -> Void
    let onNext: () -> Void
    @ViewBuilder let problem: (_ answered: Bool) -> Problem

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var picked: String?
    /// 보기 자리는 문항이 나올 때마다 섞는다. 다시 내는 문항도 새로 섞인다.
    @State private var options: [String] = []
    @State private var correctTick = 0
    @State private var wrongTick = 0

    private var answered: Bool { picked != nil }

    /// 답하기 전에는 생각, 정답이면 웃음(말풍선 사라짐), 오답이면 아쉬움 + 짚는 말.
    private var giriPose: GiriPose {
        guard let picked else { return .think }
        return picked == item.answer ? .happy : .sorry
    }

    private var giriText: String? {
        guard let picked else { return giriQuestion }
        return picked == item.answer ? nil : (wrongLine(picked) ?? giriQuestion)
    }

    var body: some View {
        SessionScaffold(progress: progress, onClose: onClose) {
            VStack(spacing: 0) {
                QuizPartHeaderView(header: header)
                // 기리 줄은 높이 96pt(기리 96pt, 말풍선 3줄 80pt)로 고정해 말풍선이 바뀌거나 사라져도 아래가 움직이지 않는다 (3.8).
                // 큰 글자 크기에서는 28자가 들어가는 줄 수로 고정한다: xLarge 3줄, xxLarge 이상 4줄 (6.2).
                let lines = typeSize >= .xxLarge ? 4 : 3
                GiriSpeechRow(pose: giriPose, text: giriText, size: 96, maxLines: lines, reservedLines: lines,
                              hop: picked == item.answer ? 1 : 0, focusOnAppear: true)
                    .padding(.top, 8)
                ScrollView {
                    problem(answered)
                        .padding(.top, 8)
                }
                .scrollBounceBehavior(.basedOnSize)

                verdict
                    .padding(.bottom, 12)

                let columns = typeSize.isAccessibilitySize || singleColumn ? 1 : 2
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        choice(option, compact: columns == 1)
                    }
                }
                .padding(.horizontal, 16)
            }
        } bottom: {
            PrimaryButton(title: nextTitle, enabled: answered, action: onNext)
        }
        .sensoryFeedback(.success, trigger: correctTick)
        .sensoryFeedback(.error, trigger: wrongTick)
        .onAppear {
            if options.isEmpty { options = ([item.answer] + item.wrongs.map(\.romaji)).shuffled() }
        }
    }

    @ViewBuilder
    private var verdict: some View {
        if let picked {
            if picked == item.answer {
                VerdictLine(kind: .good, text: L.choiceCorrect)
            } else {
                VerdictLine(kind: .bad, text: L.choiceAnswer(item.answer))
            }
        } else {
            Color.clear.frame(height: VerdictLine.height)
        }
    }

    private func choice(_ option: String, compact: Bool) -> some View {
        let isAnswer = option == item.answer
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: compact && singleColumn ? 52 : 72)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                .cardOutline(
                    cornerRadius: 16,
                    color: mark?.color ?? .outline,
                    lineWidth: mark == nil ? AppStyle.outlineWidth : AppStyle.verdictOutlineWidth
                )
                .overlay(alignment: singleColumn ? .trailing : .topTrailing) {
                    if let mark {
                        Image(systemName: mark.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(mark.color)
                            .padding(singleColumn ? 16 : 8)
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
        let correct = option == item.answer
        if correct { correctTick += 1 } else { wrongTick += 1 }
        // 오답은 판정과 기리의 짚는 말을 알림 하나로 묶는다 (giri-companion.md 6.1).
        let announcement = correct ? L.choiceCorrect
            : [L.choiceAnswer(item.answer), wrongLine(option)].compactMap { $0 }.joined(separator: ". ")
        AccessibilityNotification.Announcement(announcement).post()
        onAnswered(option)
    }
}

// MARK: - QC 기억으로 쓰기

struct RecallWriteView: View {
    /// 한 글자에서 획을 이만큼 틀리면 가이드가 켜진다.
    static let mistakesBeforeGuide = 3

    let kana: Kana
    let header: QuizPartHeader
    let giriQuestion: String
    let progress: PartProgress
    let nextTitle: String
    let onClose: () -> Void
    let onGuideUsed: () -> Void
    let onCompleted: (_ usedGuide: Bool) -> Void
    let onNext: () -> Void

    @Environment(ProgressStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var attempt = WritingAttempt()
    @State private var guideOn = false
    /// 가이드가 방금 켜져서 판정 줄에 안내를 보여 주는 중인지. 다음 획을 그으면 꺼진다.
    @State private var showsGuideNotice = false
    @State private var isDrawing = false

    private var finished: Bool { attempt.isFinished(strokeCount: kana.strokes.count) }

    /// 답하는 동안 생각. 가이드가 켜지면 말하기 + 쓰기 포인트. 완성하면 말풍선이 사라지고, 가이드 없이 썼으면 웃으며 깡충 (3.8).
    private var giriPose: GiriPose {
        if finished { return guideOn ? .normal : .happy }
        return guideOn ? .talk : .think
    }

    private var giriText: String? {
        if finished { return nil }
        return guideOn ? GiriSpeech.guideTip(kana.tip) : giriQuestion
    }

    /// 기리 크기 (giri-companion.md 2.4.1). 걸침 배치라 작은 화면에서도 96pt.
    static let giriSize: CGFloat = 96
    /// 발음 줄 높이 (로마자 48pt, 2.4.3).
    static let romajiHeight: CGFloat = 58

    /// 발음 줄이 기리 오른쪽에 걸칠 수 있는지: 가운데 정렬한 발음 줄의 왼쪽 끝이 기리 오른쪽 끝 + 8pt 이상 (2.4.3).
    static func romajiFitsBeside(romajiWidth: CGFloat, screenWidth: CGFloat) -> Bool {
        (screenWidth - romajiWidth) / 2 >= 16 + giriSize + 8
    }

    /// 발음 줄의 폭: 로마자 48pt + 간격 4 + 스피커 아이콘.
    static func romajiWidth(_ romaji: String, sound: Bool) -> CGFloat {
        let text = (romaji as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 48)]).width
        return ceil(text) + (sound ? 4 + 22 : 0)
    }

    /// 기리 블록 높이: max(G, 말풍선 + 8 + 발음). 걸치지 못하거나 기리를 숨기면 말풍선(또는 기리) 아래에 발음을 둔다 (2.4.3, 6.2).
    static func blockHeight(lines: Int, typeSize: DynamicTypeSize, beside: Bool) -> CGFloat {
        let bubble = GiriSpeechRow.bubbleHeight(lines: lines, typeSize: typeSize)
        if typeSize.isAccessibilitySize { return bubble + 8 + romajiHeight }
        if beside { return max(giriSize, bubble + 8 + romajiHeight) }
        return max(giriSize, bubble) + 8 + romajiHeight
    }

    /// 말풍선 줄 수 (2.4.3, 3.8): 4줄로 잡아도 캔버스가 화면 폭 − 32를 지키면 4줄, 아니면 2줄.
    /// 그래도 캔버스가 300pt보다 작으면 1줄까지 줄인다 (2.4.2). 부 안에서는 문항이 바뀌어도 같은 값이다.
    static func giriLines(in area: CGSize, typeSize: DynamicTypeSize, beside: Bool) -> Int {
        // 부 머리 줄 26 + 판정 줄 + VStack 간격 8 × 4
        let others = 26 + VerdictLine.height + 32
        func canvas(_ lines: Int) -> CGFloat {
            min(area.width - 32, area.height - others - blockHeight(lines: lines, typeSize: typeSize, beside: beside))
        }
        if canvas(4) >= area.width - 32 { return 4 }
        return [2, 1].first { canvas($0) >= 300 } ?? 1
    }

    var body: some View {
        SessionScaffold(progress: progress, onClose: onClose) {
            GeometryReader { proxy in
                // 쓰기 화면은 글자 크기가 accessibility1에서 멈춘다(아래 `.dynamicTypeSize`).
                let type = min(typeSize, .accessibility1)
                let beside = Self.romajiFitsBeside(romajiWidth: Self.romajiWidth(kana.romaji, sound: store.soundOn),
                                                   screenWidth: proxy.size.width)
                let lines = Self.giriLines(in: proxy.size, typeSize: type, beside: beside)
                VStack(spacing: 8) {
                    QuizPartHeaderView(header: header)
                    giriBlock(lines: lines, beside: beside, typeSize: type)
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
            }
        } bottom: {
            Group {
                SecondaryButton(title: L.showGuide, enabled: !guideOn && !finished, action: turnGuideOn)
                PrimaryButton(title: nextTitle, enabled: finished, action: onNext)
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

    /// 기리 + 말풍선 + 발음 줄. 기리는 말풍선과 위 끝을 맞추고 발음 줄 왼쪽까지 내려온다(걸침 배치, 2.4.3).
    /// 질문 줄 대신 기리가 말한다. 쓰기 화면이라 숨쉬지 않는다.
    private func giriBlock(lines: Int, beside: Bool, typeSize: DynamicTypeSize) -> some View {
        let showsFigure = !typeSize.isAccessibilitySize
        let bubble = GiriSpeechRow.bubbleHeight(lines: lines, typeSize: typeSize)
        // 발음 줄의 위 끝: 걸치면 말풍선 아래 8pt, 걸치지 못하면 기리 아래 8pt.
        let romajiTop = showsFigure && !beside ? max(Self.giriSize, bubble) + 8 : bubble + 8
        return ZStack(alignment: .top) {
            GiriSpeechRow(pose: giriPose, text: giriText, size: Self.giriSize, maxLines: lines, reservedLines: lines,
                          hangs: true, breathes: false, hop: finished && !guideOn ? 1 : 0,
                          limitsLinesAtLargeType: true, focusOnAppear: true)
            HStack(spacing: 4) {
                Text(kana.romaji).font(.system(size: 48))
                if store.soundOn { SpeakerBadge() }
            }
            .frame(height: Self.romajiHeight)
            .speaks(kana: kana.char, enabled: store.soundOn)
            .padding(.top, romajiTop)
        }
        .frame(height: Self.blockHeight(lines: lines, typeSize: typeSize, beside: beside), alignment: .top)
    }

    private func turnGuideOn() {
        guard !guideOn, !finished else { return }
        guideOn = true
        showsGuideNotice = true
        onGuideUsed()
        AccessibilityNotification.Announcement([L.guideOn, kana.tip].compactMap { $0 }.joined(separator: ". ")).post()
    }
}
