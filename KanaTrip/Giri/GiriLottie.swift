import Lottie
import SwiftUI
import UIKit

// 기리 Lottie 재생 (docs/design/giri-companion.md 5번).
// 파일 `giri.lottie.json` 하나를 마커로 재생하고, 표정·밥·반짝임은 값 공급자로, 머리·속재료는 이미지 공급자로 바꿔 끼운다 (5.7).
// 파일은 tools/build_giri_lottie.py가 tools/make_onigiri_svg.py의 부위 함수로 만든다.

/// 기리 마커 (5.2). 오른팔 자세가 구워져 있어 같은 움직임이 팔마다 둘인 것이 있다(`_down`, `_up`).
enum GiriMarker: String {
    case stillDown = "still_down", stillUp = "still_up"
    case idleDown = "idle_down", idleUp = "idle_up"
    case reactDown = "react_down", reactUp = "react_up"
    case raise, lower, hop
    case hopMove = "hop_move"
    case appear, dress

    static func still(armUp: Bool) -> GiriMarker { armUp ? .stillUp : .stillDown }
    static func idle(armUp: Bool) -> GiriMarker { armUp ? .idleUp : .idleDown }
    static func react(armUp: Bool) -> GiriMarker { armUp ? .reactUp : .reactDown }

    /// 한 번 마커가 끝난 뒤의 오른팔. nil이면 시작 자세 그대로.
    var endsArmUp: Bool? {
        switch self {
        case .stillUp, .idleUp, .reactUp, .raise, .hop, .hopMove, .appear: true
        case .stillDown, .idleDown, .reactDown, .lower, .dress: false
        }
    }

    /// 시작 자세가 정해진 마커의 시작 오른팔.
    var startsArmUp: Bool? {
        switch self {
        case .raise, .hop, .hopMove, .appear, .dress: false
        case .lower: true
        default: endsArmUp
        }
    }
}

/// 화면이 바깥에서 거는 한 번 움직임 (지도의 칸 이동 깡충, 착지의 팔 내리기). `token`이 바뀔 때마다 한 번 재생한다.
struct GiriMotionRequest: Equatable {
    enum Motion: Equatable {
        /// 칸 이동 깡충. 장면을 넘는 0.3초 깡충은 속도 0.35 ÷ 0.3 (home-map.md 4.3, giri-companion.md 5.2).
        case hopMove(duration: Double)
        /// 팔 내리기 (지도 착지).
        case lower
    }

    var motion: Motion
    var token: Int
}

/// 번들의 기리 Lottie와 파일 안 "kt" 키의 앱용 값 (5.6). 한 번만 읽는다.
@MainActor
final class GiriLottieAsset {
    static let shared = GiriLottieAsset()

    let animation: LottieAnimation?
    /// 밥 id → (밥 색, 볼 색).
    let rices: [String: (rice: LottieColor, cheek: LottieColor)]
    let faces: [String]

    private struct Meta: Decodable {
        struct KT: Decodable {
            struct Rice: Decodable { let rice: String; let cheek: String }
            let rices: [String: Rice]
            let faces: [String]
        }
        let kt: KT
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "giri.lottie", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            animation = nil
            rices = [:]
            faces = []
            return
        }
        animation = try? LottieAnimation.from(data: data)
        let meta = try? JSONDecoder().decode(Meta.self, from: data)
        rices = (meta?.kt.rices ?? [:]).mapValues { (Self.color($0.rice), Self.color($0.cheek)) }
        faces = meta?.kt.faces ?? []
    }

    static func color(_ hex: String) -> LottieColor {
        let value = Int(hex.dropFirst(), radix: 16) ?? 0
        return LottieColor(r: Double((value >> 16) & 0xFF) / 255, g: Double((value >> 8) & 0xFF) / 255,
                           b: Double(value & 0xFF) / 255, a: 1)
    }

    /// 마커 길이(초). 없으면 0.
    func duration(_ marker: GiriMarker) -> Double {
        guard let animation, let frames = animation.durationFrameTime(forMarker: marker.rawValue) else { return 0 }
        return frames / animation.framerate
    }
}

/// 기리에 꽂는 머리·속재료 그림. 아이템 그림 에셋(`Item-{id}`)을 1080px 정사각형(360 좌표 × 3)으로 한 번 그려 기억한다 (5.7).
/// 그림이 없는 아이템은 임시 표시(`ItemPlaceholderMark`)를 같은 정사각형의 지금 자리에 그린다.
@MainActor
enum GiriItemImages {
    static let side: CGFloat = 1080
    private static var cache: [String: CGImage] = [:]

    static func image(id: String, slot: RewardSlot, label: String?) -> CGImage? {
        let key = "\(id)|\(label ?? "")"
        if let cached = cache[key] { return cached }
        let image: CGImage?
        if let item = UIImage(named: RewardArt.layerAsset(id)) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
                item.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
            }.cgImage
        } else {
            let anchor = RewardArt.placeholderAnchor(slot)
            let diameter = side * RewardArt.placeholderScale(slot)
            let mark = ItemPlaceholderMark(label: label ?? "?", diameter: diameter)
                .position(x: (anchor.x + 30) / 360 * side, y: anchor.y / 360 * side)
                .frame(width: side, height: side)
            let renderer = ImageRenderer(content: mark)
            renderer.scale = 1
            renderer.isOpaque = false
            image = renderer.cgImage
        }
        cache[key] = image
        return image
    }
}

/// 이미지 슬롯 id(`top`, `filling_back`, `filling_front`) → 그림.
private final class GiriSlotImages: AnimationImageProvider {
    let images: [String: CGImage]

    init(_ images: [String: CGImage]) { self.images = images }

    func imageForAsset(asset: ImageAsset) -> CGImage? { images[asset.id] ?? Self.clear }

    var cacheEligible: Bool { false }

    private static let clear: CGImage? = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in }.cgImage
    }()
}

/// 기리가 지금 입고 짓는 것. 마커의 첫 프레임에 한꺼번에 넣는다 (5.8).
struct GiriLook: Equatable {
    var pose: GiriPose
    var top: String?
    var filling: String?
    var fillingLayer: FillingLayer
    var rice: String
    var labels: [String: String]

    init(pose: GiriPose, outfit: GiriOutfit) {
        self.pose = pose
        top = outfit.top
        filling = outfit.filling
        fillingLayer = outfit.fillingLayer
        rice = outfit.rice
        labels = outfit.labels
    }

    /// 차림(머리·속재료·밥)만 비교한다. 배경(스킨)은 Lottie 밖이다.
    func sameOutfit(_ other: GiriLook) -> Bool {
        top == other.top && filling == other.filling && fillingLayer == other.fillingLayer && rice == other.rice
    }
}

/// SwiftUI가 넘기는 재생 입력.
struct GiriPlayback: Equatable {
    var look: GiriLook
    /// 숨쉬기 반복(`idle_*`)을 켤지.
    var loops: Bool
    /// 처음 나타날 때 `appear`로 나올지 (C1, C2).
    var entrance: Bool
    var request: GiriMotionRequest?
    var reduceMotion: Bool
    /// 반복을 잠시 멈춤 (말풍선 뜨기 0.25초 동안, 5.8).
    var holdsIdle: Bool
}

/// lottie-ios 렌더링 엔진 (giri-companion.md 5.7 끝 줄). 2026-11-21 iPhone 17 Pro 시뮬레이터(iOS 26.5, lottie-ios 4.6.1)에서
/// 자동 엔진이 Core Animation을 고르고, 표정·무늬·반짝임 불투명도, 밥·볼 색, 이미지 슬롯이 재생 중 바꿔도 반영되는 것을
/// `-debugGiri` 화면으로 확인했다. 그래서 `.mainThread`로 내리지 않는다.
enum GiriRendering {
    static let engine: RenderingEngineOption = .automatic
    /// 마지막으로 만든 기리 뷰가 실제로 쓰는 엔진 (디버그 확인용).
    @MainActor static var engineLabel = "?"
    #if DEBUG
    /// `-debugGiriSlow N`: 한 번 마커를 N배 느리게 재생한다(중간 프레임 확인용).
    static let slow: Double = {
        let args = ProcessInfo.processInfo.arguments
        guard let at = args.firstIndex(of: "-debugGiriSlow"), at + 1 < args.count else { return 1 }
        return Double(args[at + 1]) ?? 1
    }()
    #else
    static let slow: Double = 1
    #endif
}

/// 기리 Lottie 뷰 하나와 재생 규칙 (5.8).
/// - 한 번 마커는 하나씩만 재생한다. 재생 중에 다른 한 번 마커가 오면 기다리는 것 하나만 두고(마지막 것으로 바꿈) 끝난 뒤 재생한다.
/// - 한 번 마커가 끝나면 반복 화면은 끝 자세의 `idle_*`를 처음부터, 아니면 끝 자세의 `still_*`에 멈춘다.
/// - 동작 줄이기: 마커를 재생하지 않고 `still_*`에 멈춘다. 표정·차림은 바로 바뀐다.
@MainActor
final class GiriPlayerView: UIView {
    private let animationView: LottieAnimationView
    private let asset = GiriLottieAsset.shared

    private var playback: GiriPlayback?
    /// 마지막으로 넣은 모습.
    private var applied: GiriLook?
    private var appliedProviders: [String: CGFloat] = [:]
    private var appliedRice: String?
    private var appliedImages: [String: String] = [:]
    /// 지금(또는 마지막 한 번 마커 끝)의 오른팔.
    private var armUp = false
    private var oneShot: GiriMarker?
    private var pending: (marker: GiriMarker, look: GiriLook, speed: Double)?
    private var generation = 0
    private var lowerTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    override init(frame: CGRect) {
        animationView = LottieAnimationView(animation: GiriLottieAsset.shared.animation,
                                            configuration: LottieConfiguration(renderingEngine: GiriRendering.engine))
        super.init(frame: frame)
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pause
        animationView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: trailingAnchor),
            animationView.topAnchor.constraint(equalTo: topAnchor),
            animationView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isUserInteractionEnabled = false
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.enterBackground() }
        })
        observers.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.settle() }
        })
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: 입력

    func update(_ next: GiriPlayback) {
        defer {
            GiriRendering.engineLabel = "\(GiriRendering.engine) → \(animationView.currentRenderingEngine.map { "\($0)" } ?? "?")"
        }
        let previous = playback
        playback = next
        guard let previous else {
            start(next)
            return
        }
        if next.reduceMotion {
            if !previous.reduceMotion || next.look != previous.look { rest(next.look) }
            return
        }
        if previous.reduceMotion {
            rest(next.look)
            settle()
            return
        }
        if let request = next.request, request != previous.request {
            lowerTask?.cancel()
            switch request.motion {
            case .hopMove(let duration):
                // 팔을 든 채 이어 뛰는 깡충(장면을 넘는 두 번째 깡충, 칸을 여럿 넘을 때)은 마커가 내림에서 시작해
                // 팔이 튀므로 Lottie는 건드리지 않는다. 자리 이동은 SwiftUI 포물선이 맡는다.
                let up = oneShot?.endsArmUp ?? armUp
                if !up {
                    let base = asset.duration(.hopMove)
                    enqueue(.hopMove, look: next.look, speed: duration > 0 && base > 0 ? base / duration : 1)
                } else if next.look != applied {
                    apply(next.look)
                }
            case .lower:
                enqueue(.lower, look: next.look, speed: 1)
            }
        } else if next.look.pose != previous.look.pose {
            poseChanged(from: previous.look.pose, to: next.look)
        } else if !next.look.sameOutfit(previous.look) {
            // 차림 바꾸기 (K, 5.2.8). 연달아 바뀌면 그때마다 처음부터 다시 재생한다. 팔을 든 자세에는 `dress`가 없어 바로 바꾼다.
            if oneShot == .dress || (oneShot == nil && !armUp) {
                play(.dress, look: next.look, speed: 1)
            } else if oneShot != nil {
                if let waiting = pending { pending = (waiting.marker, next.look, waiting.speed) } else { pendingLookOnly = next.look }
            } else {
                apply(next.look)
            }
        } else if next.look != previous.look {
            apply(next.look)
        }
        if next.loops != previous.loops || next.holdsIdle != previous.holdsIdle {
            if oneShot == nil { settle() }
        }
    }

    /// 한 번 마커 재생 중에 바뀐 차림(표정은 그대로). 마커가 끝나면 넣는다.
    private var pendingLookOnly: GiriLook?

    private func start(_ playback: GiriPlayback) {
        armUp = playback.look.pose.armRaised
        if playback.entrance, !playback.reduceMotion {
            armUp = false
            enqueue(.appear, look: playback.look, speed: 1)
            return
        }
        apply(playback.look)
        settle()
    }

    private func poseChanged(from old: GiriPose, to look: GiriLook) {
        lowerTask?.cancel()
        let fromUp = oneShot?.endsArmUp ?? armUp
        let toUp = look.pose.armRaised
        switch (fromUp, toUp) {
        case (false, true):
            enqueue(look.pose == .happy ? .hop : .raise, look: look, speed: 1)
        case (true, false):
            // 내용이 바뀌는 전환: 0.2초 내용 페이드 동안 표정만 바로 바꾸고, 페이드가 끝나면 팔을 내린다 (5.8).
            if oneShot == nil { apply(look) } else { pendingLookOnly = look }
            lowerTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self, let current = self.playback?.look,
                      !current.pose.armRaised else { return }
                self.enqueue(.lower, look: current, speed: 1)
            }
        default:
            enqueue(.react(armUp: toUp), look: look, speed: 1)
        }
    }

    // MARK: 재생

    private func enqueue(_ marker: GiriMarker, look: GiriLook, speed: Double) {
        if oneShot != nil {
            pending = (marker, look, speed)
            pendingLookOnly = nil
            return
        }
        play(marker, look: look, speed: speed)
    }

    private func play(_ marker: GiriMarker, look: GiriLook, speed: Double) {
        generation += 1
        let token = generation
        oneShot = marker
        pendingLookOnly = nil
        apply(look)
        animationView.animationSpeed = speed / GiriRendering.slow
        animationView.play(marker: marker.rawValue, loopMode: .playOnce) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                self.oneShotEnded(marker)
            }
        }
    }

    private func oneShotEnded(_ marker: GiriMarker) {
        oneShot = nil
        if let end = marker.endsArmUp { armUp = end }
        animationView.animationSpeed = 1
        if let next = pending {
            pending = nil
            if next.marker.startsArmUp == nil || next.marker.startsArmUp == armUp || next.marker == .appear {
                play(next.marker, look: next.look, speed: next.speed)
                return
            }
            // 시작 자세가 맞지 않는 마커(예: 팔을 든 뒤에 온 깡충)는 팔이 튀므로 모습만 넣는다.
            apply(next.look)
        }
        if let look = pendingLookOnly {
            pendingLookOnly = nil
            apply(look)
        }
        settle()
    }

    /// 쉼: 반복 화면이면 끝 자세의 `idle_*`를 처음부터, 아니면 `still_*`.
    private func settle() {
        guard oneShot == nil, let playback else { return }
        generation += 1
        animationView.animationSpeed = 1
        if playback.loops, !playback.reduceMotion {
            if playback.holdsIdle {
                animationView.pause()
                return
            }
            let idle = GiriMarker.idle(armUp: armUp)
            // 말풍선 뜨기로 멈췄던 반복은 그 자리에서 이어 간다.
            if let range = markerRange(idle), animationView.currentFrame > range.lowerBound,
               animationView.currentFrame < range.upperBound, !animationView.isAnimationPlaying {
                animationView.play(fromFrame: animationView.currentFrame, toFrame: range.upperBound, loopMode: .playOnce) {
                    [weak self, generation] finished in
                    MainActor.assumeIsolated {
                        guard finished, let self, self.generation == generation else { return }
                        self.animationView.play(marker: idle.rawValue, loopMode: .loop)
                    }
                }
                return
            }
            animationView.play(marker: idle.rawValue, loopMode: .loop)
        } else {
            showStill()
        }
    }

    private func markerRange(_ marker: GiriMarker) -> ClosedRange<AnimationFrameTime>? {
        guard let start = animationView.frameTime(forMarker: marker.rawValue),
              let duration = animationView.durationFrameTime(forMarker: marker.rawValue) else { return nil }
        return start...(start + duration)
    }

    private func showStill() {
        animationView.stop()
        if let frame = animationView.frameTime(forMarker: GiriMarker.still(armUp: armUp).rawValue) {
            animationView.currentFrame = frame
        }
    }

    /// 움직임 없이 그 모습의 정지 자세로 (동작 줄이기).
    private func rest(_ look: GiriLook) {
        lowerTask?.cancel()
        generation += 1
        oneShot = nil
        pending = nil
        pendingLookOnly = nil
        armUp = look.pose.armRaised
        apply(look)
        showStill()
    }

    private func enterBackground() {
        // 한 번 마커가 도중에 끊기면 끝 자세의 still로 둔다 (5.8).
        guard let marker = oneShot else { return }
        generation += 1
        oneShot = nil
        if let end = marker.endsArmUp { armUp = end }
        if let next = pending {
            pending = nil
            apply(next.look)
            if let end = next.marker.endsArmUp { armUp = end }
        }
        showStill()
    }

    // MARK: 바꿔 끼우기 (5.7)

    private func apply(_ look: GiriLook) {
        applied = look
        var opacities: [String: CGFloat] = [:]
        for face in asset.faces {
            opacities["face_\(face)"] = face == look.pose.faceLayer ? 100 : 0
        }
        opacities["sparkles"] = look.pose.hasSparkles ? 100 : 0
        for rice in asset.rices.keys {
            opacities["pattern_\(rice)"] = rice == look.rice ? 100 : 0
        }
        let back = look.fillingLayer == .back ? look.filling : nil
        let front = look.fillingLayer == .front ? look.filling : nil
        let slots: [String: (String?, RewardSlot)] = ["top": (look.top, .top), "filling_back": (back, .filling),
                                                     "filling_front": (front, .filling)]
        for (slot, (id, _)) in slots {
            opacities[slot] = id == nil ? 0 : 100
        }
        for (layer, value) in opacities where appliedProviders[layer] != value {
            animationView.setValueProvider(FloatValueProvider(value),
                                           keypath: AnimationKeypath(keypath: "\(layer).Transform.Opacity"))
            appliedProviders[layer] = value
        }
        if appliedRice != look.rice, let colors = asset.rices[look.rice] ?? asset.rices[RewardSlot.rice.defaultItemID ?? ""] {
            animationView.setValueProvider(ColorValueProvider(colors.rice), keypath: AnimationKeypath(keypath: "**.rice.Color"))
            animationView.setValueProvider(ColorValueProvider(colors.cheek), keypath: AnimationKeypath(keypath: "**.cheek.Color"))
            appliedRice = look.rice
        }
        var keys: [String: String] = [:]
        for (slot, (id, kind)) in slots {
            if let id { keys[slot] = "\(id)|\(kind.rawValue)|\(look.labels[id] ?? "")" }
        }
        if keys != appliedImages {
            var images: [String: CGImage] = [:]
            for (slot, (id, kind)) in slots {
                if let id, let image = GiriItemImages.image(id: id, slot: kind, label: look.labels[id]) {
                    images[slot] = image
                }
            }
            animationView.imageProvider = GiriSlotImages(images)
            appliedImages = keys
        }
    }
}

/// SwiftUI에서 쓰는 기리 Lottie 뷰. 크기는 바깥 프레임이 정한다(420 × 432 비율).
struct GiriLottieView: UIViewRepresentable {
    let playback: GiriPlayback

    func makeUIView(context: Context) -> GiriPlayerView {
        GiriPlayerView(frame: .zero)
    }

    func updateUIView(_ view: GiriPlayerView, context: Context) {
        view.update(playback)
    }
}
