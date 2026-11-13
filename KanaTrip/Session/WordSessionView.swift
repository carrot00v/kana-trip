import SwiftUI

/// 단어 읽기 세션. 소리 내어 읽고 "읽기 확인"으로 읽기와 뜻을 보는 자기 확인. 채점하지 않는다.
struct WordSessionView: View {
    let scene: TripScene
    let onClose: () -> Void
    let onFinished: () -> Void

    @Environment(ProgressStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var revealTick = 0

    /// 아직 끝내지 않은 첫 단어.
    private var current: TripWord? {
        let done = store.progress(for: scene.id).wordsDone
        return scene.words.first { !done.contains($0.text) }
    }

    var body: some View {
        if let word = current {
            let isLast = store.doneCount(.words, sceneID: scene.id) == scene.words.count - 1
            SessionScaffold(done: store.doneCount(.words, sceneID: scene.id), total: scene.words.count, onClose: onClose) {
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

    /// 글자마다 위에 발음 표기 칸, 아래에 글자 칸을 쌓는다.
    /// 이 장면까지 배운 글자는 위 칸을 비워 두고, 배우지 않은 글자와 탁음 글자에만 표기를 붙인다.
    private func wordRow(_ word: TripWord) -> some View {
        let learned = ContentLibrary.shared.learnedKana(through: scene)
        let compact = word.units.count >= 6
        return HStack(spacing: 4) {
            ForEach(Array(word.units.enumerated()), id: \.offset) { _, unit in
                let ruby = learned.contains(unit.kana) ? nil : unit.romaji
                VStack(spacing: 0) {
                    Text(ruby ?? " ")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(height: 20)
                    KanaText(text: unit.kana, size: compact ? 48 : 56)
                }
                .frame(width: compact ? 52 : 64)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(KanaText.japanese(unit.kana)) + Text(ruby.map { ", \($0)" } ?? ""))
                .speaks(unit.kana, enabled: store.soundOn)
            }
        }
    }

    private func advance(from word: TripWord) {
        // 확인 후 "다음"을 누른 단어까지 끝낸 것으로 저장한다.
        store.markWordDone(word.text, sceneID: scene.id)
        revealed = false
        if current == nil {
            store.completeSession(.words, sceneID: scene.id)
            onFinished()
        }
    }
}
