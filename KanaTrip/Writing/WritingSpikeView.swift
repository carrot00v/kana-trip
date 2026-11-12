import SwiftUI

/// 쓰기 판정을 직접 써보며 감도를 조정하기 위한 스파이크 화면. 정식 화면이 아니다.
struct WritingSpikeView: View {
    private let kanaList = KanaStrokeStore.loadHiragana()

    @State private var selected = 0
    @State private var attempt = WritingAttempt()
    @State private var showGuide = true
    @State private var leniency = 1.0

    var body: some View {
        if kanaList.isEmpty {
            Text("획 데이터를 읽지 못했습니다.")
        } else {
            content(kana: kanaList[selected])
        }
    }

    private func content(kana: Kana) -> some View {
        VStack(spacing: 14) {
            picker

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(kana.char).font(.system(size: 44, weight: .medium))
                Text(kana.romaji).font(.title2).foregroundStyle(.secondary)
                Spacer()
                Text("획 \(min(attempt.doneCount, kana.strokes.count)) / \(kana.strokes.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            if let tip = kana.tip {
                Label(tip, systemImage: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)

            VerdictLine.forAttempt(attempt.feedback, idleText: showGuide ? L.traceHint : L.recallHint)

            WritingPad(
                kana: kana,
                showGuide: showGuide,
                attempt: $attempt,
                tolerance: JudgeTolerance().scaled(by: leniency)
            )
            .padding(.horizontal, 16)

            controls
        }
        .padding(.vertical, 12)
    }

    private var picker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(kanaList.indices, id: \.self) { index in
                    Button {
                        select(index)
                    } label: {
                        Text(kanaList[index].char)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(index == selected ? Color.accentColor : Color(.secondarySystemBackground), in: Circle())
                            .foregroundStyle(index == selected ? .white : .primary)
                    }
                    .accessibilityLabel(kanaList[index].romaji)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Toggle("가이드", isOn: $showGuide)
                    .toggleStyle(.button)
                Button("다시 쓰기") { reset() }
                Spacer()
                Button("다음 글자") { select((selected + 1) % kanaList.count) }
                    .buttonStyle(.borderedProminent)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            HStack {
                Text("판정").font(.footnote).foregroundStyle(.secondary)
                Text("엄격").font(.footnote)
                Slider(value: $leniency, in: 0.5...2.0, step: 0.1)
                Text("느슨").font(.footnote)
                Text(String(format: "%.1f", leniency))
                    .font(.footnote.monospacedDigit())
                    .frame(width: 28, alignment: .trailing)
            }
        }
        .padding(.horizontal, 20)
    }

    private func select(_ index: Int) {
        selected = index
        reset()
    }

    private func reset() {
        attempt = WritingAttempt()
    }
}

#Preview {
    WritingSpikeView()
}
