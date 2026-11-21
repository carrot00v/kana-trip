import SwiftUI

// 홈 바탕(장면 풍경)을 지도 뒤에 까는 층과 지도 요소의 바탕색 테 (docs/design/home-backdrop.md 2번).

extension EnvironmentValues {
    /// 지도 요소가 풍경과 떨어지도록 바탕색 테를 그릴지 (2.4). 풍경을 쓰는 동안에만 true.
    @Entry var mapHalo: Bool = false
}

/// 지도 뒤 층 (2.1의 1~3): 화면 바탕색, 뷰포트 위 끝에 고정된 풍경 띠(W × W/2), 위 씻김 16pt.
/// 풍경이 없으면 지금과 같은 바탕색 한 장이다(픽셀 단위로 같다).
struct MapBackdropLayer: View {
    let backdrop: Backdrop?

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var layout: BackdropLayout { SkinStore.shared.backdrops.layout }

    var body: some View {
        if let backdrop, contrast != .increased {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    // 바탕색과 풍경만 서로 섞이게 묶는다(곱하기·스크린, 2.3). 지도 내용은 보통으로 그 위에 얹힌다.
                    ZStack(alignment: .top) {
                        MapPalette.groundLayer
                        Image(backdrop.stripAssetName)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(layout.stripAspect, contentMode: .fit)
                            .frame(width: geo.size.width)
                            .blendMode(scheme == .dark ? .screen : .multiply)
                            .opacity(backdrop.opacity(SkinMode(scheme)))
                    }
                    .compositingGroup()
                    // 위 씻김: 풍경이 바 아래 끝에서 칼로 자른 듯 끊기지 않게 (2.1의 3).
                    LinearGradient(colors: [MapPalette.ground, MapPalette.ground.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: layout.fadeTop)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .accessibilityHidden(true)
        } else {
            MapPalette.groundLayer
        }
    }
}

/// 면이 없는 글자·아이콘 둘레의 바탕색 테 (2.4 "글자 테"): 같은 모양을 바탕색으로 8방향(가로·세로 ±w, 대각 ±0.7w)에 밀어 그린다.
struct MapHalo: ViewModifier {
    @Environment(\.mapHalo) private var on

    func body(content: Content) -> some View {
        if on {
            let w = SkinStore.shared.backdrops.layout.haloWidth
            let d = w * 0.7
            let offsets: [CGSize] = [
                CGSize(width: w, height: 0), CGSize(width: -w, height: 0), CGSize(width: 0, height: w), CGSize(width: 0, height: -w),
                CGSize(width: d, height: d), CGSize(width: -d, height: d), CGSize(width: d, height: -d), CGSize(width: -d, height: -d),
            ]
            content.background {
                ZStack {
                    ForEach(offsets.indices, id: \.self) { i in
                        MapPalette.ground.mask { content }.offset(offsets[i])
                    }
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
        } else {
            content
        }
    }
}

extension View {
    func mapHalo() -> some View { modifier(MapHalo()) }
}
