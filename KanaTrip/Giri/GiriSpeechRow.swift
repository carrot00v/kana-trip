import CoreText
import SwiftUI

// 기리 말풍선 줄 (docs/design/giri-companion.md 2번, 5번, 6번).
// 왼쪽에 기리, 오른쪽에 꼬리 달린 말풍선. 누를 수 없고 진행을 막지 않는다.

/// 기리 + 말풍선 한 줄. 모든 화면이 이 부품 하나를 쓴다.
struct GiriSpeechRow: View {
    let pose: GiriPose
    /// 말풍선 문구. nil이면 말풍선을 숨기고 자리는 남긴다(퀴즈 정답 뒤).
    let text: String?
    /// 기리 크기 G. 학습 화면·H·S 96, 작은 화면 L2 80(줄이면 72), QI·C1·C2 120 (giri-companion.md 2.4.1).
    var size: CGFloat = 96
    /// 말풍선 최대 줄 수. 넘치면 말줄임표로 자르고 VoiceOver에는 전체 문구를 준다.
    var maxLines: Int = 3
    /// 줄 높이를 이 줄 수의 말풍선 높이로 고정한다(퀴즈 3줄, W 4줄). nil이면 내용에 맞춘다.
    var reservedLines: Int? = nil
    /// QC 걸침 배치(2.4.3): 기리와 말풍선의 위 끝을 맞추고, 줄 높이는 말풍선 자리(`reservedLines`)만 차지한다.
    /// 기리는 그 아래로 내려와 발음 줄 왼쪽에 걸친다. 꼬리는 기리 입 높이(말풍선 위 끝에서 min(0.53G, 높이 − 16)).
    var hangs = false
    /// xLarge ~ xxxLarge 글자 크기에서 줄 수 제한을 풀지(내용 영역이 스크롤되는 L1, W, QI, C1, C2, 6.2).
    var expandsAtLargeType = false
    /// 숨쉬기(반복 움직임). 쓰기 화면, 움직이는 장면 그림이 있는 화면에서는 끈다 (5.2, 5.3).
    var breathes = true
    /// 값이 커질 때마다 깡충 뛴다(정답, 글자 완성). 작아질 때(다음 문항으로 돌아감)는 뛰지 않는다.
    var hop = 0
    /// 큰 글자 크기에서도 줄 수 제한을 둘지(쓰기 화면 L2, QC는 캔버스 자리를 지킨다, 6.2).
    var limitsLinesAtLargeType = false
    /// 말풍선이 처음 뜨기까지 기다리는 시간(C1·C2는 기리 등장 0.15초 뒤, 5.2).
    var bubbleDelay: Double = 0
    /// 기리 그림 대신 그릴 것(C1·C2의 체크 배지 달린 등장 기리). 크기는 `size`에 맞춘다.
    var customFigure: AnyView? = nil
    /// 나타날 때 VoiceOver 초점을 말풍선으로 옮길지(퀴즈 문항이 바뀔 때, 6.1).
    var focusOnAppear = false

    @Environment(ProgressStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var bubbleShown = true
    @State private var hops = 0
    @AccessibilityFocusState private var focused: Bool

    /// 말풍선 높이 = 20n + 20pt (2.1). 글자 크기가 바뀌면 줄 높이 = 20 × 글자 pt ÷ 15 (6.2).
    static func bubbleHeight(lines: Int, typeSize: DynamicTypeSize = .large) -> CGFloat {
        ceil(CGFloat(lines) * lineHeight(typeSize)) + 20
    }

    /// 말풍선 글자 한 줄의 높이. 기본 크기(15pt)에서 20pt.
    static func lineHeight(_ typeSize: DynamicTypeSize) -> CGFloat {
        bubbleFont(typeSize).pointSize * 20 / 15
    }

    static func bubbleFont(_ typeSize: DynamicTypeSize) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(typeSize))
        return UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits)
    }

    /// 화면 폭에서 기리 옆 말풍선 글 폭: 폭 − 좌우 여백 32 − G − 간격·꼬리 12 − 안쪽 여백 24 (2.2).
    /// 기리를 숨기는 접근성 글자 크기에서는 전체 폭 카드라 폭 − 32 − 24.
    static func textWidth(screenWidth: CGFloat, size: CGFloat, showsFigure: Bool) -> CGFloat {
        showsFigure ? screenWidth - 32 - size - 12 - 24 : screenWidth - 32 - 24
    }

    /// 문구가 이 폭에서 몇 줄이 되는지(띄어쓰기에서만 줄을 바꾼다).
    static func lineCount(_ text: String, width: CGFloat, typeSize: DynamicTypeSize) -> Int {
        WordWrapLabel.wrap(text, width: width, font: bubbleFont(typeSize)).count
    }

    /// 말풍선이 실제로 차지하는 높이: 문구 줄 수와 최대 줄 수 가운데 작은 것.
    static func bubbleHeight(for text: String, maxLines: Int, screenWidth: CGFloat, size: CGFloat,
                             showsFigure: Bool, typeSize: DynamicTypeSize) -> CGFloat {
        let width = textWidth(screenWidth: screenWidth, size: size, showsFigure: showsFigure)
        let lines = min(maxLines, max(1, lineCount(text, width: width, typeSize: typeSize)))
        return bubbleHeight(lines: lines, typeSize: typeSize)
    }

    private var isLargeType: Bool { typeSize.isAccessibilitySize }

    /// 이 글자 크기에서 쓰는 최대 줄 수. nil이면 제한 없음.
    private var lineLimit: Int? {
        if isLargeType { return limitsLinesAtLargeType ? maxLines : nil }
        if expandsAtLargeType, typeSize >= .xLarge { return nil }
        return maxLines
    }

    var body: some View {
        Group {
            if isLargeType {
                // 큰 글자 크기: 기리를 숨기고 꼬리 없는 전체 폭 카드만 (6.2).
                bubble(tail: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if hangs {
                // 걸침 배치: 줄 높이는 말풍선 자리만. 기리는 아래로 넘쳐 발음 줄 옆까지 내려온다 (2.4.3).
                let height = reservedHeight ?? Self.bubbleHeight(lines: maxLines, typeSize: typeSize)
                HStack(alignment: .top, spacing: 4) {
                    figure
                        .frame(width: size, height: height, alignment: .top)
                    bubble(tail: true, tailFromTop: size * 0.53)
                        .layoutPriority(1)
                    Spacer(minLength: 0)
                }
                .frame(height: height, alignment: .top)
            } else {
                HStack(alignment: .center, spacing: 4) {
                    figure
                    // 말풍선이 남은 폭을 먼저 받는다(줄바꿈 폭이 Spacer와 나뉘지 않게).
                    bubble(tail: true)
                        .layoutPriority(1)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: rowHeight)
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            if bubbleDelay > 0, !reduceMotion {
                bubbleShown = false
                DispatchQueue.main.asyncAfter(deadline: .now() + bubbleDelay) { bubbleShown = true }
            }
            if focusOnAppear {
                // 화면 전환 페이드(0.2초)가 끝난 뒤 옮긴다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { focused = true }
            }
        }
    }

    private var reservedHeight: CGFloat? {
        reservedLines.map { Self.bubbleHeight(lines: $0, typeSize: typeSize) }
    }

    private var rowHeight: CGFloat {
        max(size, reservedHeight ?? 0)
    }

    /// 숨쉬기: 기리 크기와 상관없이 진폭 1.5pt (5.2).
    private var breathScale: CGFloat { 1 + 1.5 / size }

    // MARK: 기리

    private var figure: some View {
        Group {
            if let customFigure {
                customFigure.frame(width: size, height: size)
            } else {
                GiriView(pose: pose, outfit: store.giriOutfit, side: size)
            }
        }
            // 반복 애니메이션은 크기에만 건다. 바깥 배치 변화(자리 이동)까지 반복되지 않게 범위를 좁힌다.
            .animation(breathing ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : .default) { content in
                content.scaleEffect(x: 1, y: breathing ? breathScale : 1, anchor: .bottom)
            }
            .keyframeAnimator(initialValue: 0.0, trigger: hops) { content, y in
                content.offset(y: y)
            } keyframes: { _ in
                // 깡충: 기리 크기의 0.1배 (96pt에서 10pt, 5.2).
                CubicKeyframe(-0.1 * size, duration: 0.12)
                CubicKeyframe(0, duration: 0.18)
            }
            .onChange(of: hop) { old, new in
                if new > old, !reduceMotion { hops += 1 }
            }
            .onAppear { updateBreathing() }
            .onChange(of: breathes) { _, _ in updateBreathing() }
            .onChange(of: reduceMotion) { _, _ in updateBreathing() }
            .accessibilityHidden(true)
    }

    private func updateBreathing() {
        breathing = breathes && !reduceMotion
    }

    // MARK: 말풍선

    @ViewBuilder
    private func bubble(tail: Bool, tailFromTop: CGFloat? = nil) -> some View {
        ZStack(alignment: .leading) {
            if let text, bubbleShown {
                bubbleBody(text, tail: tail, tailFromTop: tailFromTop)
                    .id(text)
                    .transition(
                        reduceMotion ? .identity : .asymmetric(
                            insertion: .scale(scale: 0.92, anchor: .leading).combined(with: .opacity),
                            removal: .opacity.animation(.easeOut(duration: 0.15))
                        )
                    )
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.85), value: text)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.85), value: bubbleShown)
    }

    private func bubbleBody(_ text: String, tail: Bool, tailFromTop: CGFloat?) -> some View {
        let tailWidth: CGFloat = tail ? 8 : 0
        return BubbleLabel(text: text, maxLines: lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10)
            .padding(.leading, 12 + tailWidth)
            .padding(.trailing, 12)
            .frame(minWidth: 88 + tailWidth, minHeight: Self.bubbleHeight(lines: 1), alignment: .leading)
            .background {
                BubbleShape(tailWidth: tailWidth, tailFromTop: tailFromTop)
                    .fill(Color.cardBackground)
                BubbleShape(tailWidth: tailWidth, tailFromTop: tailFromTop)
                    .stroke(Color.outline, style: StrokeStyle(lineWidth: AppStyle.outlineWidth, lineJoin: .round))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(GiriBubbleText.attributed(text)))
            .accessibilityAddTraits(.isStaticText)
            .accessibilityFocused($focused)
    }
}

/// 말풍선 몸통(모서리 14pt)과 왼쪽 꼬리(밑변 14pt, 길이 8pt)를 한 경로로 (2.1).
/// 꼬리는 세로 가운데에 두되 위·아래 끝에서 16pt 안쪽으로 제한한다.
/// 걸침 배치(QC)는 `tailFromTop`으로 말풍선 위 끝에서 잰 꼬리 높이를 준다 (2.4.3).
/// 지도의 왼쪽 말풍선은 `tailOnRight`로 좌우를 뒤집어 꼬리를 오른쪽 변에 붙인다 (home-map.md 2.4).
struct BubbleShape: Shape {
    var tailWidth: CGFloat = 8
    var radius: CGFloat = 14
    var tailBase: CGFloat = 14
    var tailFromTop: CGFloat? = nil
    var tailOnRight = false

    func path(in rect: CGRect) -> Path {
        let path = leftTailPath(in: rect)
        guard tailOnRight else { return path }
        return path.applying(CGAffineTransform(translationX: rect.minX + rect.maxX, y: 0).scaledBy(x: -1, y: 1))
    }

    private func leftTailPath(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX + tailWidth, y: rect.minY, width: rect.width - tailWidth, height: rect.height)
        let r = min(radius, body.height / 2)
        var p = Path()
        guard tailWidth > 0 else {
            p.addRoundedRect(in: body, cornerSize: CGSize(width: r, height: r), style: .continuous)
            return p
        }
        let wanted = tailFromTop.map { body.minY + $0 } ?? rect.midY
        let tailY = min(max(wanted, body.minY + 16), body.maxY - 16)
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        p.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        p.addArc(center: CGPoint(x: body.maxX - r, y: body.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        p.addArc(center: CGPoint(x: body.maxX - r, y: body.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        p.addArc(center: CGPoint(x: body.minX + r, y: body.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: body.minX, y: tailY + tailBase / 2))
        p.addLine(to: CGPoint(x: rect.minX, y: tailY))
        p.addLine(to: CGPoint(x: body.minX, y: tailY - tailBase / 2))
        p.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        p.addArc(center: CGPoint(x: body.minX + r, y: body.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// 말풍선 글자. 가나와 한자는 일본어로 표시해 한국어 기기에서도 일본 글꼴로 보이고 VoiceOver가 일본어로 읽는다.
enum GiriBubbleText {
    static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString()
        for (run, japanese) in runs(text) {
            var part = AttributedString(run)
            if japanese { part.languageIdentifier = "ja" }
            result += part
        }
        return result
    }

    /// 일본어 글자 묶음과 그 밖의 묶음으로 나눈다.
    static func runs(_ text: String) -> [(String, Bool)] {
        var result: [(String, Bool)] = []
        for ch in text {
            let japanese = ch.unicodeScalars.contains { isJapanese($0) }
            if let last = result.last, last.1 == japanese {
                result[result.count - 1].0.append(ch)
            } else {
                result.append((String(ch), japanese))
            }
        }
        return result
    }

    private static func isJapanese(_ s: Unicode.Scalar) -> Bool {
        (0x3040...0x30FF).contains(s.value) || (0x4E00...0x9FFF).contains(s.value)
    }
}

/// 말풍선 글 (.subheadline, Ink, 줄 높이 20pt). 줄은 띄어쓰기에서만 바꾼다(giri-companion.md 2.2 "낱말 단위 줄바꿈").
/// SwiftUI `Text`와 UILabel의 `hangulWordPriority` 모두 이 앱에서 한글 낱말 가운데서 줄을 바꿔("간판 / 부터")
/// 폭에 맞춰 직접 줄을 나눈 뒤 줄바꿈 문자를 넣어 그린다.
private struct BubbleLabel: UIViewRepresentable {
    let text: String
    /// nil이면 줄 수 제한 없음.
    let maxLines: Int?

    func makeUIView(context: Context) -> WordWrapLabel {
        let label = WordWrapLabel()
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.isAccessibilityElement = false
        return label
    }

    func updateUIView(_ label: WordWrapLabel, context: Context) {
        // SwiftUI 쪽 글자 크기(쓰기 화면의 accessibility1 상한 포함)를 따른다.
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(context.environment.dynamicTypeSize))
        label.configure(text: text, maxLines: maxLines, font: UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView label: WordWrapLabel, context: Context) -> CGSize? {
        label.fittingSize(width: proposal.width ?? .greatestFiniteMagnitude)
    }
}

/// 띄어쓰기에서만 줄을 바꾸는 UILabel. 줄 수를 넘으면 마지막 줄 끝을 말줄임표로 자른다.
final class WordWrapLabel: UILabel {
    private var source = ""
    private var maxLines: Int?
    private var textFont = UIFont.preferredFont(forTextStyle: .subheadline)
    private var wrappedWidth: CGFloat = -1

    func configure(text: String, maxLines: Int?, font: UIFont) {
        guard text != source || maxLines != self.maxLines || font != textFont else { return }
        source = text
        self.maxLines = maxLines
        textFont = font
        numberOfLines = maxLines ?? 0
        lineBreakMode = .byTruncatingTail
        wrappedWidth = -1
        apply(width: bounds.width > 0 ? bounds.width : .greatestFiniteMagnitude)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        if abs(bounds.width - wrappedWidth) > 0.5 { apply(width: bounds.width) }
        super.layoutSubviews()
    }

    func fittingSize(width: CGFloat) -> CGSize {
        let lines = Self.wrap(source, width: width, font: textFont, maxLines: maxLines)
        let shown = attributed(lines.joined(separator: "\n"))
        let rect = shown.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return CGSize(width: min(ceil(rect.width), width), height: ceil(rect.height))
    }

    private func apply(width: CGFloat) {
        wrappedWidth = width
        attributedText = attributed(Self.wrap(source, width: width, font: textFont, maxLines: maxLines).joined(separator: "\n"))
    }

    /// 낱말을 앞에서부터 채운다. 줄 수를 넘으면 남은 낱말을 마지막 줄에 이어 붙여 UILabel이 말줄임표로 자르게 한다.
    /// 화면이 줄 수를 미리 셀 때(캔버스 300pt 계산)도 같은 함수를 쓴다.
    static func wrap(_ source: String, width: CGFloat, font: UIFont, maxLines: Int? = nil) -> [String] {
        let words = source.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var lines: [String] = []
        var current = ""
        for word in words {
            let candidate = current.isEmpty ? word : current + " " + word
            if current.isEmpty || attributed(candidate, font: font).size().width <= width {
                current = candidate
            } else {
                lines.append(current)
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        if let maxLines, maxLines > 0, lines.count > maxLines {
            let kept = Array(lines.prefix(maxLines - 1))
            let rest = lines.dropFirst(maxLines - 1).joined(separator: " ")
            return kept + [rest]
        }
        return lines
    }

    private func attributed(_ text: String) -> NSAttributedString {
        Self.attributed(text, font: textFont)
    }

    private static func attributed(_ text: String, font textFont: UIFont) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        // 15pt 글자의 줄 높이 20pt (2.1). 글자 크기가 커지면 비율대로 늘어난다.
        paragraph.lineSpacing = max(0, textFont.pointSize * 20 / 15 - textFont.lineHeight)
        let result = NSMutableAttributedString()
        for (run, japanese) in GiriBubbleText.runs(text) {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: UIColor(named: "Ink") ?? .label,
                .paragraphStyle: paragraph,
            ]
            if japanese { attributes[NSAttributedString.Key(kCTLanguageAttributeName as String)] = "ja" }
            result.append(NSAttributedString(string: run, attributes: attributes))
        }
        return result
    }
}

/// 꼬리 없는 전체 폭 말풍선 카드. 큰 글자 크기(accessibility1 이상)에서 지도 아래 고정 영역에 둔다 (home-map.md 5.1).
struct GiriBubbleCard: View {
    let text: String

    var body: some View {
        BubbleLabel(text: text, maxLines: nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.outline, lineWidth: AppStyle.outlineWidth)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(GiriBubbleText.attributed(text)))
            .accessibilityAddTraits(.isStaticText)
    }
}

/// S의 아래 고정 영역: 기리 줄(96pt) + 주 버튼 (giri-companion.md 3.3). 홈은 지도로 바뀌어 쓰지 않는다 (home-map.md 5.3).
/// 위 8 + 기리 줄 96 + 간격 8 + 주 버튼 + 아래 8 = 176pt. 바탕을 칠해 목록이 비쳐 보이지 않게 한다.
/// 말풍선은 최대 3줄. 큰 글자 크기(xLarge ~ xxxLarge)에서 3줄이 96pt를 넘으면 줄 높이가 늘고, 넘치는 문구는 잘린다 (6.2).
/// 큰 글자 크기에서는 기리 줄을 빼고(목록 맨 위 `GiriListBubble`로 옮김) 주 버튼만 남는다 (6.2).
struct GiriBottomDock<Button: View>: View {
    let text: String
    var breathes = true
    @ViewBuilder let button: () -> Button

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 8) {
            if !typeSize.isAccessibilitySize {
                GiriSpeechRow(pose: .talk, text: text, size: 96, maxLines: 3, breathes: breathes)
            }
            button()
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(SkinColor.background)
        .skinFixedBottom()
    }
}

/// 큰 글자 크기의 S: 목록 맨 위 섹션에 두는 말풍선 카드 (giri-companion.md 6.2). 홈(지도)은 `GiriBubbleCard`를 쓴다.
/// 보통 크기에서는 아무것도 그리지 않는다.
struct GiriListBubble: View {
    let text: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            Section {
                GiriSpeechRow(pose: .talk, text: text, breathes: false)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
            }
        }
    }
}
