import SwiftUI

/// 지도 위 덮개 층: 지금 칸 위의 기리 96pt와 옆 말풍선 (docs/design/home-map.md 2.4).
/// 구간들 위에 콘텐츠 전체 크기로 얹고, 기리·말풍선만 절대 좌표로 놓는다. 누르는 대상이 아니다.
struct MapGiriLayer: View {
    let metrics: MapMetrics
    let width: CGFloat
    let height: CGFloat
    /// 기리가 밟는 칸 가운데들(콘텐츠 좌표). 하나면 서 있다.
    let nodeCenters: [CGPoint]
    let progress: Double
    let pose: GiriPose
    let opacity: Double
    let isHopping: Bool
    /// 서 있는 칸의 말풍선. nil이면 그리지 않는다(깡충 중, 큰 글자 크기).
    let bubble: Bubble?

    struct Bubble: Equatable {
        let text: String
        let side: MapNode.BubbleSide
        let nodeCenter: CGPoint
    }

    @Environment(ProgressStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    /// 기리 가운데 = 칸 가운데에서 (아래 끝이 칸 가운데 아래 giriFootBelowNode가 되게) (2.4).
    private func giriCenter(_ node: CGPoint) -> CGPoint {
        CGPoint(x: node.x, y: node.y + metrics.giriFootBelowNode - metrics.giri / 2)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let bubble {
                bubbleView(bubble)
                    .id(bubble.text)
                    .transition(reduceMotion ? .identity : .asymmetric(
                        insertion: .scale(scale: 0.92, anchor: bubble.side == .right ? .leading : .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            figure
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
        .onAppear { updateBreathing() }
        .onChange(of: isHopping) { _, _ in updateBreathing() }
        .onChange(of: reduceMotion) { _, _ in updateBreathing() }
    }

    private var figure: some View {
        GiriView(pose: pose, outfit: store.giriOutfit, side: metrics.giri)
            // 숨쉬기: 진폭 1.5pt (giri-companion.md 5.2). 깡충하는 동안 멈춘다.
            .animation(breathing ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : .default) { content in
                content.scaleEffect(x: 1, y: breathing ? 1 + 1.5 / metrics.giri : 1, anchor: .bottom)
            }
            .frame(width: metrics.giri, height: metrics.giri)
            .modifier(MapHopEffect(progress: progress, points: nodeCenters.map(giriCenter), lift: metrics.hopLift))
            .opacity(opacity)
            .accessibilityHidden(true)
    }

    private func updateBreathing() {
        breathing = !isHopping && !reduceMotion
    }

    // MARK: 말풍선 (2.4)

    private func bubbleView(_ bubble: Bubble) -> some View {
        let tail = GiriSideBubble.tailWidth
        let cy = bubble.nodeCenter.y
        let giriHalf = metrics.giri / 2
        // 꼬리 끝은 기리 변에서 4pt, 몸통은 12pt(꼬리 포함 간격). 반대쪽은 화면 여백 16pt.
        let tailTipGap = MapShape.bubbleGap - tail
        let rangeMin: CGFloat
        let rangeMax: CGFloat
        if bubble.side == .right {
            rangeMin = bubble.nodeCenter.x + giriHalf + tailTipGap
            rangeMax = width - MapShape.screenMargin
        } else {
            rangeMin = MapShape.screenMargin
            rangeMax = bubble.nodeCenter.x - giriHalf - tailTipGap
        }
        let rangeWidth = max(88 + tail, rangeMax - rangeMin)
        let textWidth = rangeWidth - tail - 24
        let lines = min(3, max(1, GiriSpeechRow.lineCount(bubble.text, width: textWidth, typeSize: typeSize)))
        let h = GiriSpeechRow.bubbleHeight(lines: lines, typeSize: typeSize)
        let mouth = cy - MapShape.mouthAboveNode
        // 가운데를 기리 입 높이에 맞춘 뒤 띠 cy − 56 ~ cy + 48 안으로 밀어 넣는다.
        let top = min(max(mouth - h / 2, cy - metrics.bubbleBandAbove), cy + metrics.bubbleBandBelow - h)
        return GiriSideBubble(text: bubble.text, tailOnRight: bubble.side == .left, tailFromTop: mouth - top)
            .frame(width: rangeWidth, height: h, alignment: bubble.side == .right ? .leading : .trailing)
            .position(x: rangeMin + rangeWidth / 2, y: top + h / 2)
            .accessibilitySortPriority(3)
    }
}
