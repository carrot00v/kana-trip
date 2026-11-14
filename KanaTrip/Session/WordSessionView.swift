import SwiftUI

/// 단어 읽기 구간. 소리 내어 읽고 "읽기 확인"으로 읽기와 뜻을 보는 자기 확인. 채점하지 않는다.
/// 단어 순서는 목표 단어 → 못 읽는 단어 (scene-flow.md 12번).
struct WordSessionView: View {
    let run: SessionRun
    let onClose: () -> Void
    let onFinished: () -> Void

    @Environment(ProgressStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var revealed = false
    @State private var revealTick = 0
    /// 단어 그림 위 요소들(단어 ~ 기리 줄)의 실제 높이. 그림 영역 = 보이는 높이 − 이 값 (word-art.md 2.4).
    @State private var aboveArtHeight: CGFloat = 0

    private var words: [TripWord] { run.orderedWords }

    /// 아직 끝내지 않은 첫 단어.
    private var current: TripWord? {
        let done = run.progress.wordsDone
        return words.first { !done.contains($0.text) }
    }

    private var doneCount: Int {
        let done = run.progress.wordsDone
        return words.count { done.contains($0.text) }
    }

    var body: some View {
        if let word = current {
            let isLast = doneCount == words.count - 1
            SessionScaffold(progress: PartProgress.step(.words, done: doneCount, total: words.count), onClose: onClose) {
                content(word).fadeOnChange(of: word.text)
            } bottom: {
                // 버튼 하나의 문구만 바꾼다. 버튼을 갈아 끼우면 전환 중에 누른 것이 무시된다.
                PrimaryButton(title: revealed ? (isLast ? L.done : L.next) : L.checkReading) {
                    if revealed {
                        advance(from: word)
                    } else {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { revealed = true }
                        revealTick += 1
                        // 읽기, 뜻, 기리 설명을 알림 하나로 묶어 읽는다 (giri-companion.md 6.1).
                        AccessibilityNotification.Announcement("\(word.reading), \(word.meaning). \(explanation(word))").post()
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: revealTick)
        } else {
            Color.appBackground
        }
    }

    private var learned: Set<String> {
        run.step.map { ContentLibrary.shared.kana(through: $0) } ?? []
    }

    /// 발음 표기가 붙는 단어인지: 붙여 쓴 한자나 아직 안 배운 글자가 있다 (WordBlock과 같은 기준).
    private func hasRuby(_ word: TripWord) -> Bool {
        word.units.contains { $0.isKanji || !learned.contains($0.kana) }
    }

    /// 읽기 전 기리 안내 (giri-companion.md 3.6, giri-lines.md 4.2).
    private func beforeLine(_ word: TripWord) -> String {
        let isReread = run.rereadWord?.text == word.text
        let firstRuby = words.first(where: hasRuby)?.text == word.text
        return GiriSpeech.beforeReading(GiriSpeech.readingContext(
            isReread: isReread,
            previousStep: run.scene.steps.first?.name,
            isFirstRuby: firstRuby,
            hasKanji: word.units.contains(where: \.isKanji)
        ))
    }

    private func explanation(_ word: TripWord) -> String {
        GiriSpeech.afterReading(word.giri, scene: run.scene.name, step: run.step?.name ?? "")
    }

    private func content(_ word: TripWord) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    aboveArt(word)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { aboveArtHeight = $0 }
                    // 기리 줄 아래, 주 버튼 위의 남는 공간 가운데에 단어 그림. 확인 뒤에만 보인다 (word-art.md 2, 3).
                    let area = max(0, proxy.size.height - aboveArtHeight)
                    WordArtView(art: word.art, revealed: revealed, side: WordArtView.side(forArea: area))
                        .frame(maxWidth: .infinity)
                        .frame(height: area)
                        .id(word.text)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// 단어, 읽기·뜻, 기리 줄. 확인 전후로 높이가 같다(읽기·뜻 자리와 기리 줄 100pt를 비워 둔다).
    private func aboveArt(_ word: TripWord) -> some View {
            VStack(spacing: 0) {
                // 맨 위 안내("소리 내어 읽어 보세요")는 기리가 대신 말한다 (3.6).
                wordRow(word)
                    .padding(.top, 24)

                // 확인 전에도 자리(70pt)를 차지해서 단어와 기리의 세로 위치가 바뀌지 않게 한다.
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text(word.reading).font(.title2.bold())
                        if store.soundOn { SpeakerBadge() }
                    }
                    .frame(minHeight: 44)
                    .speaks(word.text, enabled: store.soundOn && revealed)
                    Text(word.meaning).font(.body)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .opacity(revealed ? 1 : 0)
                .accessibilityHidden(!revealed)

                // 읽기 전에는 같이 읽는 생각 표정, 확인 뒤에는 손을 들고 단어를 설명한다.
                // 줄 높이는 4줄 자리(100pt)로 고정해 확인할 때 기리가 움직이지 않게 한다. 큰 글자 크기에서는 내용에 맞춘다 (3.6, 6.2).
                // W에서는 단어 그림이 반복 움직임 자리를 쓰므로 기리가 숨쉬지 않는다 (word-art.md 6.4).
                GiriSpeechRow(
                    pose: revealed ? .point : .think,
                    text: revealed ? explanation(word) : beforeLine(word),
                    size: 96,
                    maxLines: revealed ? 4 : 3,
                    reservedLines: typeSize >= .xLarge ? nil : 4,
                    expandsAtLargeType: true,
                    breathes: false
                )
                .padding(.top, 16)
            }
    }

    private func wordRow(_ word: TripWord) -> some View {
        WordBlock(word: word, learned: learned, soundOn: store.soundOn)
    }

    private func advance(from word: TripWord) {
        // 확인 후 "다음"을 누른 단어까지 끝낸 것으로 저장한다.
        run.markWordDone(word.text)
        revealed = false
        if current == nil { onFinished() }
    }
}
