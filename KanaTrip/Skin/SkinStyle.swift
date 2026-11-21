import SwiftUI
import UIKit

// 스킨을 화면에 거는 곳 (docs/design/app-skin.md 4.1, 8.3).
// - 환경값 `\.skin`(지금 스킨)과 `\.skinLevel`(화면 강도)
// - `SkinColor`: 환경값을 보고 색을 고르는 ShapeStyle. 강조색과 바탕은 코드에서 이것만 쓴다.
// - `.skinBackground(_:)`: 화면 뿌리에 하나 붙여 바탕색·무늬·강도를 맡긴다.
// - `SkinStore`: 저장된 착용 상태(`RewardState`)에서 지금 스킨을 낸다. K의 미리 보기는 K 뿌리의 환경값만 덮는다(5.3).

extension EnvironmentValues {
    /// 지금 화면이 입은 스킨. 앱 루트에서 저장된 스킨을, K에서는 미리 보는 스킨을 넣는다.
    @Entry var skin: Skin = SkinCatalog.shared.defaultSkin
    /// 지금 화면의 스킨 강도. `.skinBackground(_:)`가 내려 준다.
    @Entry var skinLevel: SkinLevel = .strong
}

extension SkinMode {
    init(_ scheme: ColorScheme) { self = scheme == .dark ? .dark : .light }
}

extension SkinRGB {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
}

extension SkinToken {
    /// 같은 값을 가진 에셋 카탈로그 Color Set (기본 스킨 값, 7.3). `AppBackgroundQuiet`는 기본 스킨에서 `AppBackground`와 같다.
    var assetName: String? {
        switch self {
        case .appBackground, .appBackgroundQuiet: "AppBackground"
        case .accentColor: "AccentColor"
        case .accentForeground: "AccentForeground"
        case .pathEdge: "PathEdge"
        case .patternInk: nil
        }
    }
}

extension Skin {
    /// 화면에 칠할 Color. 기본 스킨은 에셋 카탈로그의 Color Set을 그대로 쓴다.
    /// 값은 같지만(SkinContrastTests가 비교) 툴바 같은 곳에서 sRGB 성분으로 만든 Color가 1~10 단위 다르게 합성되는 것을 봤다.
    /// 기본 스킨에서 스킨 도입 전과 픽셀이 같도록 에셋을 쓴다 (app-skin.md 8.4의 3).
    func paint(_ token: SkinToken, mode: SkinMode) -> Color {
        if isDefault, let name = token.assetName { return Color(name) }
        return rgb(token, mode: mode).color
    }

    /// 단계와 화면 설정에 맞는 토큰 값. `.appBackground` 자리에 단계 바탕을 쓰려면 `background(level:…)`.
    func rgb(_ token: SkinToken, mode: SkinMode) -> SkinRGB {
        color(token, mode) ?? SkinCatalog.fallbackDefault.color(token, mode) ?? SkinRGB(red: 0, green: 0, blue: 0)
    }

    func background(level: SkinLevel, mode: SkinMode, highContrast: Bool) -> SkinRGB {
        rgb(Skin.backgroundToken(level, highContrast: highContrast), mode: mode)
    }

    /// 화면 설정(다크, 대비 증가)을 따라 바뀌는 Color. 환경값이 닿지 않는 곳(지도 팔레트)에 쓴다.
    func dynamicColor(_ token: SkinToken) -> Color {
        if isDefault, let name = token.assetName { return Color(name) }
        let light = rgb(token, mode: .light).uiColor, dark = rgb(token, mode: .dark).uiColor
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// 단계 바탕의 Color. 대비 증가면 강·중 단계도 `AppBackgroundQuiet`.
    func dynamicBackground(level: SkinLevel) -> Color {
        if isDefault { return Color("AppBackground") }
        func pick(_ traits: UITraitCollection) -> UIColor {
            let mode: SkinMode = traits.userInterfaceStyle == .dark ? .dark : .light
            return background(level: level, mode: mode, highContrast: traits.accessibilityContrast == .high).uiColor
        }
        return Color(uiColor: UIColor { pick($0) })
    }
}

/// 스킨 색. 환경값(스킨, 강도, 다크, 대비 증가)을 보고 고른다.
struct SkinColor: ShapeStyle {
    enum Role: Sendable {
        /// 화면 강도에 맞는 바탕(강·중·시트 `AppBackground`, 약 `AppBackgroundQuiet`).
        case background
        case accent
        case accentForeground
        case patternInk
        case pathEdge
    }

    let role: Role

    static let background = SkinColor(role: .background)
    static let accent = SkinColor(role: .accent)
    static let accentForeground = SkinColor(role: .accentForeground)
    static let patternInk = SkinColor(role: .patternInk)
    static let pathEdge = SkinColor(role: .pathEdge)

    func resolve(in environment: EnvironmentValues) -> Color {
        let skin = environment.skin
        return skin.paint(token(in: environment), mode: SkinMode(environment.colorScheme))
    }

    private func token(in environment: EnvironmentValues) -> SkinToken {
        switch role {
        case .background:
            Skin.backgroundToken(environment.skinLevel, highContrast: environment.colorSchemeContrast == .increased)
        case .accent: .accentColor
        case .accentForeground: .accentForeground
        case .patternInk: .patternInk
        case .pathEdge: .pathEdge
        }
    }
}

// MARK: - 저장된 스킨

/// 저장된 착용 상태에서 지금 스킨을 낸다 (8.2). 앱 시작 때 `progress`를 넣는다.
/// `@Observable`이라 `current`를 읽은 화면은 착용 상태가 바뀌면 다시 그려진다.
@Observable
final class SkinStore {
    static let shared = SkinStore()

    var progress: ProgressStore?
    /// `-skinDebug <id>`: 저장 상태와 상관없이 메모리에서만 쓰는 스킨 (8.3). DEBUG 빌드 전용.
    var debugSkinID: String?

    @ObservationIgnored let catalog: SkinCatalog

    init(catalog: SkinCatalog = .shared) {
        self.catalog = catalog
    }

    var current: Skin {
        if let id = debugSkinID, let skin = catalog.skin(id: id) { return skin }
        guard let rewards = progress?.rewards else { return catalog.defaultSkin }
        return catalog.skin(for: rewards)
    }
}

#if DEBUG
/// `-skinDebug <id>`: 스크린샷용 (app-skin.md 8.7). 진도를 메모리에만 두는 실행(`-mapDebugCompleted`)에서는
/// 그 스킨 아이템을 메모리 상태에 사서 입히고, 아니면 저장 상태를 건드리지 않고 화면에만 쓴다.
enum SkinDebug {
    static var skinID: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let at = args.firstIndex(of: "-skinDebug"), at + 1 < args.count else { return nil }
        return args[at + 1]
    }
}
#endif

// MARK: - 바탕

extension View {
    /// 화면 뿌리에 붙인다: 단계 바탕색, 무늬(강·중), `skinLevel` 내려 주기 (4.1).
    func skinBackground(_ level: SkinLevel) -> some View {
        modifier(SkinBackgroundModifier(level: level))
    }

    /// 강·중 화면의 아래 고정 영역 (1.3): 무늬를 가리는 단색 바탕과 위 16pt 그라데이션.
    /// 무늬가 보이지 않는 화면(기본 스킨, 약 단계, 대비 증가)에서는 아무것도 그리지 않는다.
    func skinFixedBottom() -> some View {
        modifier(SkinFixedBottomModifier())
    }

    /// 앱 루트: 저장된 스킨을 환경값으로 내리고 강조색을 `tint`로 건다 (8.3).
    func skinRoot() -> some View {
        modifier(SkinRootModifier())
    }
}

private struct SkinRootModifier: ViewModifier {
    func body(content: Content) -> some View {
        let skin = SkinStore.shared.current
        // tint는 Color로 준다. 툴바(UIKit 바 버튼)가 사용자 ShapeStyle tint를 다르게 합성했다.
        content
            .environment(\.skin, skin)
            .tint(skin.dynamicColor(.accentColor))
    }
}

private struct SkinBackgroundModifier: ViewModifier {
    let level: SkinLevel

    func body(content: Content) -> some View {
        content
            .environment(\.skinLevel, level)
            .background {
                SkinBackdrop(level: level)
                    .ignoresSafeArea()
            }
    }
}

/// 바탕색 + 무늬 층. 무늬는 화면에 고정되고 내용과 함께 스크롤되지 않는다.
struct SkinBackdrop: View {
    let level: SkinLevel
    /// 무늬 타일 크기 배율 (스킨 썸네일 띠는 0.5, 5.2).
    var tileScale: CGFloat = 1

    @Environment(\.skin) private var skin
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let mode = SkinMode(scheme)
        let highContrast = contrast == .increased
        let opacity = skin.patternOpacity(mode, level: level, highContrast: highContrast, catalog: SkinCatalog.shared)
        ZStack(alignment: .topLeading) {
            Rectangle().fill(skin.paint(Skin.backgroundToken(level, highContrast: highContrast), mode: mode))
            if opacity > 0, let pattern = skin.pattern {
                SkinPatternLayer(asset: pattern, ink: skin.rgb(.patternInk, mode: mode).color, tileScale: tileScale)
                    .opacity(opacity)
                    .id(skin.id)
                    .transition(.opacity)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 이어 붙는 무늬 타일 (6.3). 타일 원점은 이 층의 왼쪽 위다.
struct SkinPatternLayer: View {
    let asset: String
    let ink: Color
    var tileScale: CGFloat = 1

    var body: some View {
        if UIImage(named: asset) != nil, tileScale > 0 {
            GeometryReader { geo in
                Image(asset)
                    .renderingMode(.template)
                    .resizable(resizingMode: .tile)
                    .foregroundStyle(ink)
                    .frame(width: geo.size.width / tileScale, height: geo.size.height / tileScale, alignment: .topLeading)
                    .scaleEffect(tileScale, anchor: .topLeading)
            }
            .allowsHitTesting(false)
        }
    }
}

private struct SkinFixedBottomModifier: ViewModifier {
    @Environment(\.skin) private var skin
    @Environment(\.skinLevel) private var level
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    /// 무늬에서 단색으로 이어지는 높이 (1.3).
    static let fade: CGFloat = 16

    func body(content: Content) -> some View {
        let opacity = skin.patternOpacity(SkinMode(scheme), level: level, highContrast: contrast == .increased,
                                          catalog: SkinCatalog.shared)
        content.background(alignment: .top) {
            if opacity > 0 {
                Rectangle()
                    .fill(SkinColor.background)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(SkinColor.background)
                            .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                            .frame(height: Self.fade)
                            .offset(y: -Self.fade)
                    }
            }
        }
    }
}
