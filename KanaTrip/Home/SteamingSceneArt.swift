import SwiftUI
import UIKit

/// 시제품: 정지 그림 위에 코드로 김 세 줄을 그려 움직인다.
///
/// 그림은 `tools/prep_steam_layer.py`가 김을 지운 PNG다. 김 선의 위치와 굵기는
/// 그 스크립트가 출력한 값(그림 변 길이에 대한 0~1 비율)을 옮겨 적었다.
/// 그릇은 움직이지 않고, 동작 줄이기가 켜지면 김도 원래 그림 자리에 멈춘다.
struct SteamingSceneArt: View {
    var height: CGFloat = 180

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Self.background
            if let image = UIImage(named: Self.imageName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay { steam }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityHidden(true)
    }

    private var steam: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let side = min(size.width, size.height)
                let time = timeline.date.timeIntervalSinceReferenceDate
                for (index, line) in Self.lines.enumerated() {
                    let state = reduceMotion
                        ? SteamState.still
                        : SteamState(time: time, index: index, count: Self.lines.count)
                    var layer = context
                    layer.opacity = state.opacity
                    layer.stroke(
                        line.path(side: side, rise: state.rise, sway: state.sway),
                        with: .color(Self.lineColor),
                        style: StrokeStyle(lineWidth: Self.strokeWidth * side, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
    }

    // MARK: - 그림 데이터 (prep_steam_layer.py 출력에서)

    private static let imageName = "scene_eatery_sign_steamless"
    /// 그림 바탕색. 카드에서 그림 좌우의 빈 곳을 같은 색으로 채운다.
    private static let background = Color(red: 0xBF / 255, green: 0xE9 / 255, blue: 0xFC / 255)
    /// 그림의 외곽선 색 #4A2219.
    private static let lineColor = Color(red: 0x4A / 255, green: 0x22 / 255, blue: 0x19 / 255)
    private static let strokeWidth: CGFloat = 0.0195

    /// 김 선의 중심선 끝(위·아래)은 경계 상자에서 굵기 절반만큼 안쪽이다.
    private static let lines: [SteamLine] = [
        SteamLine(centerX: 0.395, top: 0.176, bottom: 0.306, amplitude: 0.017),
        SteamLine(centerX: 0.497, top: 0.137, bottom: 0.302, amplitude: 0.021),
        SteamLine(centerX: 0.599, top: 0.181, bottom: 0.310, amplitude: 0.017),
    ]
}

/// 김 한 줄. 아래에서 위로 한 번 출렁이는 S자.
private struct SteamLine {
    let centerX: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    let amplitude: CGFloat

    /// 원래 그림의 선은 아래 끝에서 오른쪽으로 나갔다가 왼쪽으로 돌아 위에서 다시 오른쪽으로 간다.
    private static let basePhase: CGFloat = 0.35

    func path(side: CGFloat, rise: CGFloat, sway: CGFloat) -> Path {
        var path = Path()
        let steps = 24
        for step in 0...steps {
            let s = CGFloat(step) / CGFloat(steps)  // 0 = 아래 끝, 1 = 위 끝
            let y = bottom + (top - bottom) * s - rise
            let x = centerX + amplitude * sin(2 * .pi * s + Self.basePhase + sway)
            let point = CGPoint(x: x * side, y: y * side)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// 한 순간의 김 상태: 얼마나 올라갔나, 얼마나 흔들렸나, 얼마나 보이나.
private struct SteamState {
    let rise: CGFloat
    let sway: CGFloat
    let opacity: Double

    /// 한 주기(초). 나타나 오르며 옅어지기까지.
    static let period: Double = 2.6
    /// 한 주기 동안 오르는 거리(그림 변에 대한 비율).
    static let riseDistance: CGFloat = 0.05
    /// 원래 그림 자리에 오는 주기 위치. 이때 가장 진하다.
    static let restingProgress: Double = 0.4

    static let still = SteamState(rise: 0, sway: 0, opacity: 1)

    init(rise: CGFloat, sway: CGFloat, opacity: Double) {
        self.rise = rise
        self.sway = sway
        self.opacity = opacity
    }

    init(time: Double, index: Int, count: Int) {
        let offset = Double(index) / Double(count)
        let progress = (time / Self.period + offset).truncatingRemainder(dividingBy: 1)
        rise = Self.riseDistance * CGFloat(progress - Self.restingProgress)
        // 오르는 동안 S자의 굽이가 조금씩 옮겨 가며 흔들린다.
        sway = 0.6 * CGFloat(sin(2 * .pi * (time / (Self.period * 1.7) + offset)))
        let fadeIn = Self.smoothstep(0, 0.25, progress)
        let fadeOut = 1 - Self.smoothstep(0.6, 1, progress)
        opacity = fadeIn * fadeOut
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

#Preview {
    SteamingSceneArt()
        .padding()
}
