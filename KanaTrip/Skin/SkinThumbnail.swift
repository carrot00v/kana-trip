import SwiftUI

/// 스킨 썸네일 (app-skin.md 5.2). 파일 없이 겹쳐 그린다.
/// 위: 기리 뒤 그림 썸네일(`ItemThumb-{id}`, 위 정렬로 잘라 냄). 기본 스킨은 `CardBackground` 단색.
/// 아래 띠: 그 스킨의 `AppBackground` + 무늬(불투명도 × 1, 타일 × 0.5) + 가운데 `AccentColor` 캡슐.
/// 띠는 화면이 미리 보는 스킨과 상관없이 늘 이 칸의 스킨 값으로 그린다.
struct SkinThumbnail: View {
    let skin: Skin
    /// 60(K) 또는 44(C2).
    let size: CGFloat
    /// 잠긴 칸: 썸네일 전체를 실루엣 색으로. 스킨 색을 미리 보여 주지 않는다.
    var silhouette = false

    private var isSmall: Bool { size < 60 }
    private var bandHeight: CGFloat { isSmall ? 15 : 20 }
    private var capsule: CGSize { isSmall ? CGSize(width: 18, height: 6) : CGSize(width: 24, height: 8) }
    private static let corner: CGFloat = 10
    private static let silhouetteColor = Color.inkSecondary.opacity(0.3)

    var body: some View {
        VStack(spacing: 0) {
            top
                .frame(width: size, height: size - bandHeight, alignment: .top)
                .clipped()
            band
                .frame(width: size, height: bandHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
        .environment(\.skin, skin)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var top: some View {
        let asset = skin.itemID.map(RewardArt.thumbnailAsset)
        if let asset, RewardArt.hasAsset(asset) {
            if silhouette {
                Image(asset).resizable().renderingMode(.template).scaledToFill()
                    .foregroundStyle(Self.silhouetteColor)
                    .frame(width: size, height: size - bandHeight, alignment: .top)
            } else {
                Image(asset).resizable().scaledToFill()
                    .frame(width: size, height: size - bandHeight, alignment: .top)
            }
        } else {
            Rectangle().fill(silhouette ? Self.silhouetteColor : Color.cardBackground)
        }
    }

    @ViewBuilder
    private var band: some View {
        if silhouette {
            Rectangle().fill(Self.silhouetteColor)
        } else {
            ZStack {
                SkinBackdrop(level: .strong, tileScale: 0.5)
                Capsule()
                    .fill(SkinColor.accent)
                    .frame(width: capsule.width, height: capsule.height)
            }
        }
    }
}
