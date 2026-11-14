import Lottie
import SwiftUI

/// 시제품: 장면 그림 Lottie 파일 하나(정지 그림 + 움직이는 김)를 둥근 카드에 반복 재생한다.
///
/// 파일은 `tools/build_scene_lottie.py`가 만든다. 그림은 정사각이라 카드 좌우는 파일의
/// `kt.background`(그림 가장자리와 같은 바탕색)로 채운다. 동작 줄이기가 켜지면 마커 "still"에 멈춘다.
struct SteamingSceneArt: View {
    var height: CGFloat = 180

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let art = SceneArt.eaterySign {
            ZStack {
                art.background
                LottieView(animation: art.animation)
                    .playbackMode(reduceMotion
                        ? .paused(at: .marker(SceneArt.stillMarker))
                        : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)))
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityHidden(true)
        }
    }
}

/// 번들의 장면 Lottie 파일과, 파일 안 "kt" 키에 적힌 앱용 값.
private struct SceneArt {
    static let stillMarker = "still"
    static let eaterySign = SceneArt(resource: "scene_eatery_sign.lottie")

    let animation: LottieAnimation
    let background: Color

    private struct Meta: Decodable {
        struct KT: Decodable { let background: String }
        let kt: KT
    }

    private init?(resource: String) {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let animation = try? LottieAnimation.from(data: data),
              let meta = try? JSONDecoder().decode(Meta.self, from: data),
              let rgb = UInt32(meta.kt.background.trimmingCharacters(in: ["#"]), radix: 16)
        else { return nil }
        self.animation = animation
        background = Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#Preview {
    SteamingSceneArt()
        .padding()
}
