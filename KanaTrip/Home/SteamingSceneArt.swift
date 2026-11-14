import Lottie
import SwiftUI

/// 장면 진입 화면 맨 위의 장면 그림. Lottie 파일 하나(정지 그림 + 움직이는 김)를 둥근 카드에 반복 재생한다.
/// 그림에 김이 있는 장면(돈카츠집의 가츠동, 온천의 나무통)에만 파일 `scene_{장면 id}.lottie.json`이 있다.
///
/// 파일은 `tools/build_scene_lottie.py`가 홈 장면 그림과 같은 칸색으로 칠한 원본에서 만든다. 그림은 정사각이라
/// 카드 좌우는 파일의 `kt.background`(칸색)로 채운다. 동작 줄이기가 켜지면 마커 "still"에 멈춘 정지 그림이 나온다.
struct SteamingSceneArt: View {
    let sceneID: String
    var height: CGFloat = 180

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func isAvailable(sceneID: String) -> Bool {
        SceneArt.load(sceneID: sceneID) != nil
    }

    var body: some View {
        if let art = SceneArt.load(sceneID: sceneID) {
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

/// 번들의 장면 Lottie 파일과, 파일 안 "kt" 키에 적힌 앱용 값. 한 번 읽은 파일은 기억해 둔다.
private struct SceneArt {
    static let stillMarker = "still"

    @MainActor private static var cache: [String: SceneArt?] = [:]

    @MainActor static func load(sceneID: String) -> SceneArt? {
        if let cached = cache[sceneID] { return cached }
        let art = SceneArt(resource: "scene_\(sceneID).lottie")
        cache[sceneID] = art
        return art
    }

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
    SteamingSceneArt(sceneID: "tonkatsu")
        .padding()
}
