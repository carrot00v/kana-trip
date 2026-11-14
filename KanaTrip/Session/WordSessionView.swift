import SwiftUI

/// 단어 읽기 구간. 소리 내어 읽고 "읽기 확인"으로 읽기와 뜻을 보는 자기 확인. 채점하지 않는다.
/// 단어 순서는 목표 단어 → 못 읽는 단어 (scene-flow.md 12번).
struct WordSessionView: View {
    let run: SessionRun
    let onClose: () -> Void
    let onFinished: () -> Void

    @Environment(ProgressStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var revealTick = 0

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
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: revealTick)
        } else {
            Color.appBackground
        }
    }

    private func content(_ word: TripWord) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Text(L.readAloud)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                wordRow(word)
                    .padding(.top, 72)

                // 확인 전에도 자리를 차지해서 단어의 세로 위치가 바뀌지 않게 한다.
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text(word.reading).font(.title2.bold())
                        if store.soundOn { SpeakerBadge() }
                    }
                    .frame(minHeight: 44)
                    .speaks(word.text, enabled: store.soundOn && revealed)
                    Text(word.meaning).font(.body)
                    if let note = word.note {
                        Text(note).font(.subheadline).foregroundStyle(Color.inkSecondary)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .opacity(revealed ? 1 : 0)
                .accessibilityHidden(!revealed)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func wordRow(_ word: TripWord) -> some View {
        WordBlock(word: word, learned: run.step.map { ContentLibrary.shared.kana(through: $0) } ?? [], soundOn: store.soundOn)
    }

    private func advance(from word: TripWord) {
        // 확인 후 "다음"을 누른 단어까지 끝낸 것으로 저장한다.
        run.markWordDone(word.text)
        revealed = false
        if current == nil { onFinished() }
    }
}
