import Foundation

// 홈 바탕(장면 풍경)의 데이터 (docs/design/home-backdrop.md 3번, 6.1, 6.2). SwiftUI에 의존하지 않는다.
// 값은 번들의 `backdrops.json`에서 읽는다. 화면 쪽은 Home/Map/MapBackdrop.swift.

/// 풍경을 여는 규칙 (home-backdrop.md 0.2의 D1). backdrops.json의 `unlock` 한 값으로 바꾼다.
enum BackdropUnlock: String, Sendable {
    /// D1 가(추천, 결정 전 임시 동작): 장면을 처음 끝내면 그 장면 풍경이 열린다.
    case sceneComplete
    /// D1 나: 처음부터 모두 열림.
    case all
}

/// 풍경 하나 (`backdrops[]` 한 칸).
struct Backdrop: Identifiable, Equatable, Sendable {
    let id: String
    let sceneID: String
    let opacityLight: Double
    let opacityDark: Double

    /// 에셋 이름 (6.3).
    var stripAssetName: String { "Backdrop-\(id)" }
    var thumbAssetName: String { "BackdropThumb-\(id)" }

    func opacity(_ mode: SkinMode) -> Double {
        mode == .dark ? opacityDark : opacityLight
    }
}

/// 손으로 쓰는 배치 값 (6.1 `layout`). pt.
struct BackdropLayout: Equatable, Sendable {
    var stripAspect = 2.0
    var fadeTop = 16.0
    var haloWidth = 2.0
    var artMatInset = 4.0
    var artMatCorner = 16.0
    var dotHaloDiameter = 8.0
}

/// 합성 결과의 기준 (2.3, 6.1 `limits`).
struct BackdropLimits: Equatable, Sendable {
    var lightMinLuminance = 0.55
    var lightPercentile = 0.1
    var darkMaxLuminance = 0.045
    var darkPercentile = 99.9
    var lightOpacity: ClosedRange<Double> = 0.20...0.40
    var darkOpacity: ClosedRange<Double> = 0.06...0.25
}

/// 합성 식 (2.3). sRGB 부호화 값에서 채널마다. tools/make_backdrop_art.py와 같은 식이다.
enum BackdropBlend {
    /// 라이트 곱하기: C = B × (1 − o·a·(1 − A)).
    static func multiply(_ base: SkinRGB, _ art: SkinRGB, alpha: Double, opacity: Double) -> SkinRGB {
        let k = opacity * alpha
        return SkinRGB(red: base.red * (1 - k * (1 - art.red)),
                       green: base.green * (1 - k * (1 - art.green)),
                       blue: base.blue * (1 - k * (1 - art.blue)))
    }

    /// 다크 스크린: C = B + o·a·A·(1 − B).
    static func screen(_ base: SkinRGB, _ art: SkinRGB, alpha: Double, opacity: Double) -> SkinRGB {
        let k = opacity * alpha
        return SkinRGB(red: base.red + k * art.red * (1 - base.red),
                       green: base.green + k * art.green * (1 - base.green),
                       blue: base.blue + k * art.blue * (1 - base.blue))
    }

    static func compose(_ mode: SkinMode, _ base: SkinRGB, _ art: SkinRGB, alpha: Double, opacity: Double) -> SkinRGB {
        mode == .dark ? screen(base, art, alpha: alpha, opacity: opacity) : multiply(base, art, alpha: alpha, opacity: opacity)
    }
}

/// `backdrops.json` 전체 (6.1).
struct BackdropCatalog: Sendable {
    static let supportedSchemaVersion = 1

    let unlock: BackdropUnlock
    let layout: BackdropLayout
    let limits: BackdropLimits
    /// 칸을 만드는 풍경만. 데이터 순서 = 장면 순서 = K 칸 순서. `opacity`가 0이거나 에셋이 없는 항목은 뺐다(6.1).
    let backdrops: [Backdrop]

    var isEmpty: Bool { backdrops.isEmpty }

    func backdrop(id: String) -> Backdrop? { backdrops.first { $0.id == id } }

    func backdrop(forScene sceneID: String) -> Backdrop? { backdrops.first { $0.sceneID == sceneID } }

    /// 열렸는지 (3번). 판단은 `paid`의 `scene/{장면 id}`(종합 퀴즈를 처음 통과하면 들어감, 진도 초기화에도 남음).
    func isUnlocked(_ backdrop: Backdrop, rewards: RewardState) -> Bool {
        switch unlock {
        case .all: true
        case .sceneComplete: rewards.paid.contains(RewardRules.sceneUnlockKey(backdrop.sceneID))
        }
    }

    /// 홈에 깔 풍경 (6.2). 저장 값이 목록에 없거나 잠겼으면 nil(값은 지우지 않는다).
    func current(for rewards: RewardState) -> Backdrop? {
        guard let id = rewards.backdrop, let backdrop = backdrop(id: id), isUnlocked(backdrop, rewards: rewards) else { return nil }
        return backdrop
    }

    /// 이번에 장면을 처음 끝내 새로 열린 풍경 (C2 알림, 5.2). 모두 처음부터 열려 있으면 알릴 것이 없다.
    func newlyUnlocked(bySceneCompletion sceneID: String) -> Backdrop? {
        unlock == .sceneComplete ? backdrop(forScene: sceneID) : nil
    }

    // MARK: - 읽기

    static let empty = BackdropCatalog(unlock: .sceneComplete, layout: BackdropLayout(), limits: BackdropLimits(), backdrops: [])

    init(unlock: BackdropUnlock, layout: BackdropLayout, limits: BackdropLimits, backdrops: [Backdrop]) {
        self.unlock = unlock
        self.layout = layout
        self.limits = limits
        self.backdrops = backdrops
    }

    /// 버전이 1이 아니면 nil(파일 전체를 버리고 풍경 없음, 6.1). 모르는 키는 무시한다.
    /// - Parameter hasAsset: 에셋 이름이 번들에 있는지. 없으면 그 항목은 칸을 만들지 않는다.
    init?(data: Data, hasAsset: (String) -> Bool) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let version = root["schemaVersion"] as? Int, version == Self.supportedSchemaVersion,
              let list = root["backdrops"] as? [[String: Any]]
        else { return nil }
        unlock = (root["unlock"] as? String).flatMap(BackdropUnlock.init(rawValue:)) ?? .sceneComplete

        var layout = BackdropLayout()
        if let l = root["layout"] as? [String: Any] {
            func num(_ key: String, _ fallback: Double) -> Double { (l[key] as? NSNumber)?.doubleValue ?? fallback }
            layout.stripAspect = num("stripAspect", layout.stripAspect)
            layout.fadeTop = num("fadeTop", layout.fadeTop)
            layout.haloWidth = num("haloWidth", layout.haloWidth)
            layout.artMatInset = num("artMatInset", layout.artMatInset)
            layout.artMatCorner = num("artMatCorner", layout.artMatCorner)
            layout.dotHaloDiameter = num("dotHaloDiameter", layout.dotHaloDiameter)
        }
        self.layout = layout

        var limits = BackdropLimits()
        if let l = root["limits"] as? [String: Any] {
            func num(_ key: String, _ fallback: Double) -> Double { (l[key] as? NSNumber)?.doubleValue ?? fallback }
            func range(_ key: String, _ fallback: ClosedRange<Double>) -> ClosedRange<Double> {
                guard let r = l[key] as? [String: Any], let lo = (r["min"] as? NSNumber)?.doubleValue,
                      let hi = (r["max"] as? NSNumber)?.doubleValue, lo <= hi else { return fallback }
                return lo...hi
            }
            limits.lightMinLuminance = num("lightMinLuminance", limits.lightMinLuminance)
            limits.lightPercentile = num("lightPercentile", limits.lightPercentile)
            limits.darkMaxLuminance = num("darkMaxLuminance", limits.darkMaxLuminance)
            limits.darkPercentile = num("darkPercentile", limits.darkPercentile)
            limits.lightOpacity = range("lightOpacity", limits.lightOpacity)
            limits.darkOpacity = range("darkOpacity", limits.darkOpacity)
        }
        self.limits = limits

        var backdrops: [Backdrop] = []
        for object in list {
            guard let id = object["id"] as? String, !id.isEmpty,
                  let opacity = object["opacity"] as? [String: Any],
                  let light = (opacity["light"] as? NSNumber)?.doubleValue,
                  let dark = (opacity["dark"] as? NSNumber)?.doubleValue,
                  light > 0, dark > 0,
                  !backdrops.contains(where: { $0.id == id })
            else { continue }
            let backdrop = Backdrop(id: id, sceneID: object["sceneID"] as? String ?? id, opacityLight: light, opacityDark: dark)
            guard hasAsset(backdrop.stripAssetName), hasAsset(backdrop.thumbAssetName) else { continue }
            backdrops.append(backdrop)
        }
        self.backdrops = backdrops
    }
}

#if DEBUG
/// `-backdropDebug <id>`: 저장·열림과 상관없이 그 풍경을 홈에 깐다 (6.3).
/// `-backdropUnlockAll`: 열림 규칙을 "모두 열림"으로 (K 칸 확인용). DEBUG 빌드 전용.
enum BackdropDebug {
    static var backdropID: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let at = args.firstIndex(of: "-backdropDebug"), at + 1 < args.count else { return nil }
        return args[at + 1]
    }

    static var unlockAll: Bool { ProcessInfo.processInfo.arguments.contains("-backdropUnlockAll") }
}
#endif
