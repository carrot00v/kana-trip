import SwiftUI
import UIKit

/// 지도 위 덮개 층: 지금 칸 오른쪽 옆의 기리 72pt와 그 위 한 줄 말풍선 (home-map.md "2026-11-21 재구성안" R2.3).
/// 구간들 위에 콘텐츠 전체 크기로 얹고, 기리·말풍선만 절대 좌표로 놓는다. 누르는 대상이 아니다.
struct MapGiriLayer: View {
    let metrics: MapMetrics
    let width: CGFloat
    let height: CGFloat
    /// 기리 가운데가 밟는 자리들(콘텐츠 좌표). 하나면 서 있다.
    let giriCenters: [CGPoint]
    let progress: Double
    let pose: GiriPose
    /// 칸 이동 깡충(`hop_move`)·착지(`lower`) 요청 (giri-companion.md 5.8).
    let motion: GiriMotionRequest?
    let opacity: Double
    let isHopping: Bool
    /// 서 있는 자리의 말풍선. nil이면 그리지 않는다(깡충 중, 큰 글자 크기).
    let bubble: Bubble?

    struct Bubble: Equatable {
        let text: String
        /// 말하는 기리의 가운데.
        let giriCenter: CGPoint
    }

    @Environment(ProgressStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            figure
            if let bubble {
                bubbleView(bubble)
                    .id(bubble.text)
                    .transition(reduceMotion ? .identity : .asymmetric(
                        insertion: .scale(scale: 0.92, anchor: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var figure: some View {
        // 숨쉬기(`idle_*`)는 연출하는 동안 멈춘다 (giri-companion.md 5.2).
        GiriView(pose: pose, outfit: store.giriOutfit, side: metrics.giri, breathes: !isHopping, motion: motion)
            .frame(width: metrics.giri, height: metrics.giri)
            .modifier(MapHopEffect(progress: progress, points: giriCenters, lift: metrics.hopLift))
            .opacity(opacity)
            .accessibilityHidden(true)
    }

    // MARK: 한 줄 말풍선 (R2.3)

    /// 몸통 아래 끝 = 기리 위 끝 − bubbleAboveGiri. 가로는 기리 가운데에 맞춘 뒤 16 ~ W−16 안으로 민다.
    /// 최대 폭 W−32, 넘치면 말줄임표(전체 문구는 VoiceOver).
    private func bubbleView(_ bubble: Bubble) -> some View {
        let layout = MapLineBubble.layout(text: bubble.text, giriCenter: bubble.giriCenter, width: width, metrics: metrics)
        return MapLineBubble(text: bubble.text, tailX: layout.tailX, metrics: metrics)
            .frame(width: layout.frame.width, height: layout.frame.height)
            .position(x: layout.frame.midX, y: layout.frame.midY)
            .accessibilitySortPriority(3)
    }
}

/// 꼬리가 아래 변에서 기리 머리를 가리키는 한 줄 말풍선 (R2.3).
struct MapLineBubble: View {
    let text: String
    /// 말풍선 왼쪽 변에서 꼬리 끝까지.
    let tailX: CGFloat
    let metrics: MapMetrics

    static let font = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))

    /// 말풍선 몸통 + 꼬리의 콘텐츠 사각형과 꼬리 x. 큰 글자 크기는 아래 고정 영역 카드로 옮기므로 기본 크기로 잰다.
    static func layout(text: String, giriCenter: CGPoint, width: CGFloat, metrics: MapMetrics) -> (frame: CGRect, tailX: CGFloat) {
        let margin = MapShape.screenMargin
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        let w = min(textWidth + MapShape.bubblePadding * 2, width - margin * 2)
        let x = min(max(giriCenter.x - w / 2, margin), width - margin - w)
        let bodyBottom = giriCenter.y - metrics.giri / 2 - metrics.bubbleAboveGiri
        let top = bodyBottom - metrics.bubbleHeight
        let half = MapShape.bubbleTailBase / 2
        let tail = min(max(giriCenter.x - x, MapShape.bubbleCorner + half), w - MapShape.bubbleCorner - half)
        return (CGRect(x: x, y: top, width: w, height: metrics.bubbleHeight + MapShape.bubbleTailLength), tail)
    }

    var body: some View {
        let shape = MapLineBubbleShape(bodyHeight: metrics.bubbleHeight, tailX: tailX)
        Text(text)
            .font(Font(Self.font))
            .foregroundStyle(MapPalette.ink)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, MapShape.bubblePadding)
            .frame(maxWidth: .infinity, maxHeight: metrics.bubbleHeight)
            .frame(maxHeight: .infinity, alignment: .top)
            .background {
                shape.fill(MapPalette.card)
                shape.stroke(MapPalette.outline, style: StrokeStyle(lineWidth: MapShape.outlineWidth, lineJoin: .round))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// 둥근 몸통(높이 bodyHeight) 아래 변에 꼬리(밑변 14, 길이 8)가 붙은 한 덩어리 윤곽.
struct MapLineBubbleShape: Shape {
    let bodyHeight: CGFloat
    let tailX: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = MapShape.bubbleCorner
        let half = MapShape.bubbleTailBase / 2
        let bottom = rect.minY + bodyHeight
        let tip = CGPoint(x: rect.minX + tailX, y: bottom + MapShape.bubbleTailLength)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: bottom), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: bottom), tangent2End: CGPoint(x: rect.minX, y: bottom), radius: r)
        p.addLine(to: CGPoint(x: tip.x + half, y: bottom))
        p.addLine(to: tip)
        p.addLine(to: CGPoint(x: tip.x - half, y: bottom))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: bottom), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: r)
        p.closeSubpath()
        return p
    }
}
