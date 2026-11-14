import Lottie
import SwiftUI

/// W 단어 읽기의 단어 그림 (docs/design/word-art.md).
///
/// 에셋 판정 순서 (4.2): Lottie 파일 `word_{art}.lottie.json` → 이미지 에셋 `WordArt-{art}` → 아무것도 그리지 않음.
/// 어느 경우에도 자리(바깥에서 준 프레임)는 그대로라 그림이 있든 없든 위 요소가 움직이지 않는다.
/// "읽기 확인" 뒤에만 보이고(불투명도는 `revealed`를 같은 애니메이션 트랜잭션으로 따른다), Lottie는 확인 0.25초 뒤 재생한다.
/// 장식이라 VoiceOver에서 읽지 않는다 (8번).
struct WordArtView: View {
    let art: String?
    let revealed: Bool
    /// 그림 한 변. nil이면 그리지 않는다(자리가 96pt보다 작음).
    let side: CGFloat?

    /// 그림 한 변의 최대값 (2.2).
    static let maxSide: CGFloat = 176
    /// 이보다 작으면 그리지 않는다 (2.2).
    static let minSide: CGFloat = 96
    /// 그림 영역의 위(기리 줄 아래)·아래(주 버튼 위) 여백 (2.1).
    static let areaMargin: CGFloat = 16

    /// 남는 높이(기리 줄 아래 끝 ~ 아래 버튼 영역 위 끝)에서 그림 한 변을 정한다 (2.2, 2.4).
    static func side(forArea height: CGFloat) -> CGFloat? {
        let side = min(maxSide, height - 2 * areaMargin)
        return side >= minSide ? side : nil
    }

    var body: some View {
        Group {
            if let art, let side {
                if let lottie = WordLottie.load(art: art) {
                    WordLottieView(lottie: lottie, revealed: revealed)
                        .frame(width: side, height: side)
                } else if let image = UIImage(named: "WordArt-\(art)") {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: side, height: side)
                }
            }
        }
        .opacity(revealed ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIgnoresInvertColors(true)
    }
}

/// 단어 Lottie 재생. 확인 전에는 `still`에 멈춰 있고(보이지 않는 동안 돌리지 않는다), 확인 0.25초 뒤 재생한다 (6.6).
/// 동작 줄이기에서는 `still`에 멈춘다(재생 도중 켜져도 그 자리에서 옮긴다, 6.5).
/// 이름이 `ink`인 레이어의 색은 지금 모드의 `Ink` 토큰을 따른다 (6.1, 6.2).
private struct WordLottieView: View {
    let lottie: WordLottie
    let revealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var playing = false

    var body: some View {
        LottieView(animation: lottie.animation)
            .playbackMode(playing && !reduceMotion
                ? .playing(.fromProgress(0, toProgress: 1, loopMode: lottie.loops ? .loop : .playOnce))
                : .paused(at: .marker(WordLottie.stillMarker)))
            .valueProvider(ColorValueProvider(Self.ink(colorScheme)), for: AnimationKeypath(keypath: "ink.**.Color"))
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .task(id: revealed) {
                guard revealed else {
                    playing = false
                    return
                }
                // 말풍선 뜨기(0.25초)가 끝난 뒤 시작해 동시에 움직이는 것이 셋이 되지 않게 한다 (3.2).
                try? await Task.sleep(for: .milliseconds(250))
                if !Task.isCancelled { playing = true }
            }
    }

    private static func ink(_ scheme: ColorScheme) -> LottieColor {
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        let color = (UIColor(named: "Ink") ?? .label).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return LottieColor(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
    }
}

/// 번들의 단어 Lottie 파일과 파일 안 "kt" 키의 앱용 값. 한 번 읽은 파일은 기억해 둔다.
/// 읽지 못하면(없음, 손상, 디코딩 실패) nil이라 정지 그림으로 내려간다 (4.2).
struct WordLottie {
    static let stillMarker = "still"

    @MainActor private static var cache: [String: WordLottie?] = [:]

    @MainActor static func load(art: String) -> WordLottie? {
        if let cached = cache[art] { return cached }
        let lottie = WordLottie(resource: "word_\(art).lottie")
        cache[art] = lottie
        return lottie
    }

    let animation: LottieAnimation
    /// 반복하는지. 동전처럼 한 번 재생하는 파일은 false이고 마지막 프레임이 `still`이다 (6.2).
    let loops: Bool

    private struct Meta: Decodable {
        struct KT: Decodable { let loop: Bool? }
        let kt: KT?
    }

    private init?(resource: String) {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let animation = try? LottieAnimation.from(data: data),
              animation.progressTime(forMarker: Self.stillMarker) != nil
        else { return nil }
        self.animation = animation
        loops = (try? JSONDecoder().decode(Meta.self, from: data))?.kt?.loop ?? true
    }
}
