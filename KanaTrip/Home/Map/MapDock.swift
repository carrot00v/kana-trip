import SwiftUI
import UIKit

/// 지도 아래 고정 영역 72pt: [꾸미기 입구 56×56] 8pt [시작 버튼] (docs/design/home-map.md 5.1).
/// 큰 글자 크기(accessibility1 이상)에서는 위에 말풍선 카드를 두고 꾸미기 입구는 아이콘만.
struct MapDock: View {
    let metrics: MapMetrics
    /// 시작 버튼의 긴 문구. nil이면 버튼을 숨긴다(다음 장면 준비 중, 모두 끝냄).
    let longTitle: String?
    /// 긴 문구가 0.85배로도 안 들어갈 때 쓰는 짧은 문구.
    let shortTitle: String?
    /// 큰 글자 크기에서 아래 고정 영역에 두는 말풍선.
    let bubbleCard: String?
    let coins: Int
    let canBuy: Bool
    let onCustomize: () -> Void
    let onStart: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var buttonWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: metrics.dockGap) {
            if typeSize.isAccessibilitySize, let bubbleCard {
                GiriBubbleCard(text: bubbleCard)
                    .accessibilitySortPriority(3)
            }
            HStack(spacing: metrics.dockGap) {
                customizeButton
                    .accessibilitySortPriority(1)
                if let longTitle {
                    PrimaryButton(title: fittedTitle(long: longTitle, short: shortTitle ?? longTitle), action: onStart)
                        .contentTransition(.opacity)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { buttonWidth = $0 }
                        .accessibilityLabel(longTitle)
                        .accessibilitySortPriority(2)
                } else {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, MapShape.screenMargin)
        .padding(.vertical, (metrics.dock - metrics.dockCustomize) / 2)
        .frame(maxWidth: .infinity)
        .background(MapPalette.ground)
    }

    /// 긴 문구가 0.85배로 한 줄에 들어가면 긴 문구, 아니면 짧은 문구 (5.1).
    private func fittedTitle(long: String, short: String) -> String {
        guard buttonWidth > 0 else { return long }
        let available = buttonWidth - 32
        return Self.headlineWidth(long, typeSize: typeSize) * 0.85 <= available ? long : short
    }

    /// 주 버튼 글꼴(.headline, 둥근 굵게)로 잰 한 줄 폭.
    static func headlineWidth(_ text: String, typeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(typeSize))
        let base = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: traits)
        let bold = UIFont.systemFont(ofSize: base.pointSize, weight: .semibold)
        let font = bold.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: base.pointSize) } ?? bold
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private var customizeButton: some View {
        let side = metrics.dockCustomize
        let shape = RoundedRectangle(cornerRadius: MapShape.customizeCorner, style: .continuous)
        return Button(action: onCustomize) {
            VStack(spacing: 2) {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: typeSize.isAccessibilitySize ? 24 : 20, weight: .bold))
                if !typeSize.isAccessibilitySize {
                    Text(L.customizeShort)
                        .font(.caption2.weight(.bold))
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(Color.accent)
            .frame(width: side, height: side)
            .background(Color.accent.opacity(0.12), in: shape)
            .contentShape(shape)
        }
        .buttonStyle(MapPressStyle())
        .overlay(alignment: .topTrailing) {
            if canBuy {
                Image(systemName: "yensign.circle.fill")
                    .font(.system(size: MapShape.yenBadge))
                    .foregroundStyle(MapPalette.yenBadge)
                    .background(Circle().fill(MapPalette.card).padding(-2))
                    // 원의 중심을 입구 오른쪽 위 꼭짓점에서 왼쪽·아래로 6pt.
                    .offset(x: MapShape.yenBadge / 2 - MapShape.yenBadgeInset, y: MapShape.yenBadgeInset - MapShape.yenBadge / 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.customizeRowLabel(balance: coins, canBuy: canBuy))
        .accessibilityAddTraits(.isButton)
    }
}
