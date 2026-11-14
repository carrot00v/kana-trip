import SwiftUI

/// 배우기 구간. 단계의 새 글자마다 L1 글자 소개 → L2 따라 쓰기 2번을 반복한다.
struct LearnSessionView: View {
    static let traceRounds = 2

    let run: SessionRun
    let onClose: () -> Void
    let onFinished: () -> Void

    @Environment(ProgressStore.self) private var store
    @Environment(\.isSmallScreen) private var isSmallScreen
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var phase = Phase.intro
    @State private var attempt = WritingAttempt()
    @State private var isDrawing = false

    private enum Phase: Hashable {
        case intro
        case trace(round: Int)
    }

    private var kanaList: [Kana] { run.step.map { ContentLibrary.shared.kana(for: $0) } ?? [] }

    /// 아직 끝내지 않은 첫 글자. 하던 글자는 저장하지 않으므로 다시 들어오면 소개부터 시작한다.
    private var current: Kana? {
        let done = run.progress.learnDone
        return kanaList.first { !done.contains($0.char) }
    }

    private var partProgress: PartProgress {
        let done = run.progress.learnDone
        return PartProgress.step(.learn, done: kanaList.count { done.contains($0.char) }, total: kanaList.count)
    }

    var body: some View {
        if let kana = current {
            switch phase {
            case .intro:
                SessionScaffold(progress: partProgress, onClose: onClose) {
                    intro(kana).fadeOnChange(of: kana.char)
                } bottom: {
                    PrimaryButton(title: L.tryWriting) { startTrace(round: 1) }
                }
            case .trace(let round):
                SessionScaffold(progress: partProgress, onClose: onClose) {
                    trace(kana, round: round).fadeOnChange(of: "\(kana.char)-\(round)")
                } bottom: {
                    let finished = attempt.isFinished(strokeCount: kana.strokes.count)
                    Group {
                        SecondaryButton(title: L.rewrite, enabled: attempt.doneCount > 0 || attempt.mistakes > 0) {
                            attempt = WritingAttempt()
                        }
                        // 마지막 글자의 마지막 따라 쓰기에서는 다음 할 일을 알린다 (scene-flow.md 7.3).
                        let isLast = round == Self.traceRounds && kana.char == kanaList.last?.char
                        PrimaryButton(title: isLast ? L.wordsStart : L.next, enabled: finished) { advance(from: kana, round: round) }
                    }
                    .allowsHitTesting(!isDrawing)
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        } else {
            Color.appBackground
        }
    }

    // MARK: - L1 글자 소개

    private func intro(_ kana: Kana) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(L.newKana)
                    .font(.headline)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                VStack(spacing: 8) {
                    KanaGlyphView(kana: kana, side: 200, showsOrder: true)
                    HStack(spacing: 4) {
                        Text(kana.romaji).font(.title)
                        if store.soundOn { SpeakerBadge() }
                    }
                    Text(L.strokeCount(kana.strokes.count))
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }
                .padding(.top, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(kana.char), \(kana.romaji), \(L.strokeCount(kana.strokes.count))")
                .speaks(kana.char, enabled: store.soundOn)

                if let word = run.step.flatMap({ ContentLibrary.shared.introWord(for: kana.char, in: $0) }) {
                    SceneWordCard(scene: run.scene, char: kana.char, intro: word)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                // 쓰기 포인트는 기리가 말한다. 손 들기 표정으로 위의 글자를 가리킨다 (giri-companion.md 3.4).
                GiriSpeechRow(pose: .point, text: GiriSpeech.writingTip(kana.tip), size: 96, maxLines: 4,
                              expandsAtLargeType: true)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - L2 따라 쓰기

    /// 따라 쓰기의 기리 크기와 말풍선 줄 수 (giri-companion.md 2.4.2, 3.5).
    /// 캔버스 한 변 = min(폭 − 32, 남는 높이)가 300pt 이상이 되게 줄 수 4 → 1, 그다음 기리 96 → 80 → 72pt 순서로 줄인다.
    /// 문구가 같은 글자 안에서 바뀌지 않으므로 글자 하나 안에서는 값이 바뀌지 않는다.
    static func traceGiri(tip: String, in area: CGSize, isSmallScreen: Bool, typeSize: DynamicTypeSize) -> (size: CGFloat, lines: Int) {
        // 글자 정보 줄 52 + 판정 줄 + VStack 간격 8 × 4
        let others = 52 + VerdictLine.height + 32
        let showsFigure = !typeSize.isAccessibilitySize
        let sizes: [CGFloat] = isSmallScreen ? [80, 72] : [96, 80, 72]
        for size in sizes {
            for lines in stride(from: 4, through: 1, by: -1) {
                let bubble = GiriSpeechRow.bubbleHeight(for: tip, maxLines: lines, screenWidth: area.width, size: size,
                                                        showsFigure: showsFigure, typeSize: typeSize)
                let row = showsFigure ? max(size, bubble) : bubble
                let canvas = min(area.width - 32, area.height - others - row)
                if canvas >= 300 { return (size, lines) }
            }
        }
        // 지금 기기와 글자 크기에서는 오지 않는다. 캔버스는 남는 높이만큼 작아진다 (2.4.2의 3단계).
        return (sizes.last ?? 72, 1)
    }

    private func trace(_ kana: Kana, round: Int) -> some View {
        GeometryReader { proxy in
            traceBody(kana, round: round, area: proxy.size)
        }
    }

    private func traceBody(_ kana: Kana, round: Int, area: CGSize) -> some View {
        let tip = GiriSpeech.writingTip(kana.tip)
        // 쓰기 화면은 글자 크기가 accessibility1에서 멈춘다(아래 `.dynamicTypeSize`).
        let giri = Self.traceGiri(tip: tip, in: area, isSmallScreen: isSmallScreen, typeSize: min(typeSize, .accessibility1))
        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    KanaText(text: kana.char, size: 34)
                    Text(kana.romaji).font(.title2).foregroundStyle(Color.inkSecondary)
                    if store.soundOn { SpeakerBadge() }
                }
                .speaks(kana.char, enabled: store.soundOn)
                Spacer()
                Text(L.traceRound(round, of: Self.traceRounds))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(height: 52)
            .padding(.horizontal, 20)

            // 쓰는 동안 옆에서 쓰기 포인트를 말한다. 획마다 반응하지 않고, 글자를 완성하면 웃으며 깡충 뛴다 (3.5).
            // 쓰기 화면이라 숨쉬지 않는다 (5.2).
            let finished = attempt.isFinished(strokeCount: kana.strokes.count)
            GiriSpeechRow(
                pose: finished ? .happy : .talk,
                text: tip,
                size: giri.size,
                maxLines: giri.lines,
                breathes: false,
                hop: finished ? 1 : 0,
                limitsLinesAtLargeType: true
            )

            Spacer(minLength: 0)

            VerdictLine.forAttempt(attempt.feedback, idleText: L.traceHint)

            WritingPad(kana: kana, showGuide: true, attempt: $attempt, isDrawing: $isDrawing)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - 전환

    private func startTrace(round: Int) {
        attempt = WritingAttempt()
        phase = .trace(round: round)
    }

    private func advance(from kana: Kana, round: Int) {
        if round < Self.traceRounds {
            startTrace(round: round + 1)
            return
        }
        // 글자 하나(소개 + 따라 쓰기 2번)를 끝낸 시점에 저장한다.
        run.markLearnDone(kana.char)
        attempt = WritingAttempt()
        phase = .intro
        if current == nil { onFinished() }
    }
}
