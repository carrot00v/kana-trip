import SwiftUI

/// 배우기 세션. 글자마다 L1 글자 소개 → L2 따라 쓰기 2번을 반복한다.
struct LearnSessionView: View {
    static let traceRounds = 2

    let scene: TripScene
    let onClose: () -> Void
    let onFinished: () -> Void

    @Environment(ProgressStore.self) private var store
    @State private var phase = Phase.intro
    @State private var attempt = WritingAttempt()
    @State private var isDrawing = false

    private enum Phase: Hashable {
        case intro
        case trace(round: Int)
    }

    private var kanaList: [Kana] { ContentLibrary.shared.kana(for: scene) }

    /// 아직 끝내지 않은 첫 글자. 하던 글자는 저장하지 않으므로 다시 들어오면 소개부터 시작한다.
    private var current: Kana? {
        let done = store.progress(for: scene.id).learnDone
        return kanaList.first { !done.contains($0.char) }
    }

    var body: some View {
        let done = store.doneCount(.learn, sceneID: scene.id)
        if let kana = current {
            switch phase {
            case .intro:
                SessionScaffold(done: done, total: kanaList.count, onClose: onClose) {
                    intro(kana).fadeOnChange(of: kana.char)
                } bottom: {
                    PrimaryButton(title: L.tryWriting) { startTrace(round: 1) }
                }
            case .trace(let round):
                SessionScaffold(done: done, total: kanaList.count, onClose: onClose) {
                    trace(kana, round: round).fadeOnChange(of: "\(kana.char)-\(round)")
                } bottom: {
                    let finished = attempt.isFinished(strokeCount: kana.strokes.count)
                    Group {
                        SecondaryButton(title: L.rewrite, enabled: attempt.doneCount > 0 || attempt.mistakes > 0) {
                            attempt = WritingAttempt()
                        }
                        PrimaryButton(title: L.next, enabled: finished) { advance(from: kana, round: round) }
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

                if let word = ContentLibrary.shared.introWord(for: kana.char, in: scene) {
                    SceneWordCard(scene: scene, char: kana.char, intro: word)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                if let tip = kana.tip {
                    TipBox(text: tip)
                        .padding(.horizontal, 16)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - L2 따라 쓰기

    private func trace(_ kana: Kana, round: Int) -> some View {
        VStack(spacing: 8) {
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

            if let tip = kana.tip {
                TipBox(text: tip, lineLimit: 3)
                    .padding(.horizontal, 16)
            }

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
        store.markLearnDone(kana.char, sceneID: scene.id)
        attempt = WritingAttempt()
        phase = .intro
        if current == nil {
            store.completeSession(.learn, sceneID: scene.id)
            onFinished()
        }
    }
}
