import SwiftUI

/// 단어 속 글자 하나의 진하기 (docs/design/visual-rules.md 2.5).
enum WordGlyphStyle {
    /// 본문 색, 굵게.
    case learned
    /// 보조 색, 보통 굵기.
    case unlearned
    /// 강조색, 굵게, 밑줄. 글자 소개의 지금 글자.
    case current
}

/// 단어를 글자마다 다른 진하기로 그린다. 크기는 Dynamic Type을 따르지 않는다.
struct WordGlyphs: View {
    let word: TripWord
    let size: CGFloat
    var spacing: CGFloat = 2
    let style: (String) -> WordGlyphStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            ForEach(Array(word.units.enumerated()), id: \.offset) { _, unit in
                glyph(unit.kana, style: style(unit.kana))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(KanaText.japanese(word.text)))
    }

    @ViewBuilder
    private func glyph(_ kana: String, style: WordGlyphStyle) -> some View {
        switch style {
        case .learned:
            KanaText(text: kana, size: size, weight: .bold)
                .foregroundStyle(.primary)
        case .unlearned:
            KanaText(text: kana, size: size)
                .foregroundStyle(.secondary)
        case .current:
            KanaText(text: kana, size: size, weight: .bold)
                .foregroundStyle(Color.accentColor)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                        .offset(y: 2)
                }
        }
    }
}

/// 글자 소개의 단어 카드. 지금 글자가 나오는 장면 단어 하나를 보여 준다. 누를 수 없다.
struct SceneWordCard: View {
    let scene: TripScene
    let char: String
    let intro: IntroWord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let icon = scene.icon {
                    Image(systemName: icon)
                }
                Text(L.sceneWords(scene.name))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                WordGlyphs(word: intro.word, size: 28) { kana in
                    if kana == char { .current } else if intro.known.contains(kana) { .learned } else { .unlearned }
                }
                Spacer(minLength: 0)
                Text(intro.word.meaning)
                    .font(.subheadline)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
    }

    /// "공항 단어, ようこそ의 よ, 환영합니다". 가나는 일본어로 읽게 한다.
    private var label: AttributedString {
        AttributedString("\(L.sceneWords(scene.name)), ")
            + KanaText.japanese(intro.word.text)
            + AttributedString(L.possessive)
            + KanaText.japanese(char)
            + AttributedString(", \(intro.word.meaning)")
    }
}

/// 넓이가 모자라면 줄을 바꾸고 줄마다 가운데로 모으는 배치.
struct CenteredFlow: Layout {
    var spacing: CGFloat = 16
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.midX - row.width / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widened = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty, widened > width {
                rows.append(row)
                row = Row(indices: [index], width: size.width, height: size.height)
            } else {
                row.indices.append(index)
                row.width = widened
                row.height = max(row.height, size.height)
            }
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
