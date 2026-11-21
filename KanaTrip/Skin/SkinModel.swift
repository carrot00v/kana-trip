import Foundation

// 앱 스킨의 데이터 (docs/design/app-skin.md 2번, 7번). SwiftUI에 의존하지 않는다.
// 값은 번들의 `skins.json`에서 읽는다. 화면 쪽(색 스타일, 바탕)은 SkinStyle.swift.

/// 사용자 확인을 기다리는 권장안(app-skin.md 9.2)을 한곳에 둔다. 결정이 바뀌면 여기만 고친다.
enum SkinPolicy {
    /// 9.2의 1: "기본 차림으로"가 스킨을 되돌리지 않는다(5.5).
    static let resetOutfitKeepsSkin = true
    /// 9.2의 2: 학습·퀴즈 화면(L1, L2, W, QA, QD, QC)의 스킨 강도(4.1).
    static let learningLevel: SkinLevel = .quiet
    /// 9.2의 5: 스킨을 저장하는 슬롯. 저장 키는 `background` 그대로다(8.1).
    static let slot: RewardSlot = .background
    // 9.2의 3(스킨 수)은 skins.json, 6(값 300엔)은 rewards.json, 4(스킨별 앱 아이콘 없음)는 코드가 없다.
}

/// 화면의 스킨 강도 (app-skin.md 4.1).
enum SkinLevel: String, CaseIterable, Sendable {
    /// H, K, C2. `AppBackground`.
    case strong
    /// S, C1, QI, I. `AppBackground`. 무늬가 빠져(2026-11-21) 강과 같지만, B(배경 활용안)를 위해 나눠 둔다(4.1).
    case medium
    /// L1, L2, W, QA, QD, QC. 옅은 바탕 `AppBackgroundQuiet`.
    case quiet
    /// `.sheet`. 바탕 단색.
    case sheet
}

/// 스킨이 채우는 색 토큰 (2.1).
enum SkinToken: String, CaseIterable, Sendable {
    case appBackground = "AppBackground"
    case appBackgroundQuiet = "AppBackgroundQuiet"
    case accentColor = "AccentColor"
    case accentForeground = "AccentForeground"
    /// 강조 글자·선(진행 막대, 보조 버튼, 글자 버튼, 링크, 번호 원 등). 면은 `accentColor` (1.1).
    case accentText = "AccentText"
    case pathEdge = "PathEdge"
}

/// 모든 스킨이 같이 쓰는 고정 토큰 (2.2).
enum SkinBaseToken: String, CaseIterable, Sendable {
    case cardBackground = "CardBackground"
    case ink = "Ink"
    case inkSecondary = "InkSecondary"
    case outline = "Outline"
    case highlight = "Highlight"
    case highlightStrong = "HighlightStrong"
    case onHighlight = "OnHighlight"
    case correct = "Correct"
    case wrong = "Wrong"
}

enum SkinMode: String, CaseIterable, Sendable {
    case light, dark
}

/// sRGB 색 하나(0...1). 대비와 CIELAB 계산을 함께 둔다(2.4, tools/check_skin_contrast.py와 같은 식).
struct SkinRGB: Equatable, Hashable, Sendable, CustomStringConvertible {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// "#RRGGBB".
    init?(hex: String) {
        var text = hex
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    var description: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    private static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// 상대 휘도 (WCAG).
    var luminance: Double {
        0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
    }

    func contrast(_ other: SkinRGB) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// sRGB 값에서 섞는다(SwiftUI·Compose의 기본 합성과 같다).
    func mixed(with top: SkinRGB, amount: Double) -> SkinRGB {
        SkinRGB(red: red * (1 - amount) + top.red * amount,
                green: green * (1 - amount) + top.green * amount,
                blue: blue * (1 - amount) + top.blue * amount)
    }

    /// CIELAB (D65).
    var lab: (l: Double, a: Double, b: Double) {
        let r = Self.linear(red), g = Self.linear(green), b = Self.linear(blue)
        let x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
        let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
        let z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b
        func f(_ t: Double) -> Double {
            let d = 6.0 / 29.0
            return t > d * d * d ? cbrt(t) : t / (3 * d * d) + 4.0 / 29.0
        }
        let fx = f(x / 0.95047), fy = f(y), fz = f(z / 1.08883)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    func deltaE(_ other: SkinRGB) -> Double {
        let p = lab, q = other.lab
        return ((p.l - q.l) * (p.l - q.l) + (p.a - q.a) * (p.a - q.a) + (p.b - q.b) * (p.b - q.b)).squareRoot()
    }

    var chroma: Double { let p = lab; return (p.a * p.a + p.b * p.b).squareRoot() }

    /// CIELAB 색상각(도).
    var hueAngle: Double {
        let p = lab
        let h = atan2(p.b, p.a) * 180 / .pi
        return h < 0 ? h + 360 : h
    }

    func hueDifference(_ other: SkinRGB) -> Double {
        let d = abs(hueAngle - other.hueAngle).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }

    /// HSV (색상 도, 채도 0...1, 명도 0...1).
    var hsv: (h: Double, s: Double, v: Double) {
        let mx = max(red, green, blue), mn = min(red, green, blue), d = mx - mn
        var h = 0.0
        if d > 0 {
            if mx == red { h = (60 * ((green - blue) / d)).truncatingRemainder(dividingBy: 360) }
            else if mx == green { h = 60 * ((blue - red) / d) + 120 }
            else { h = 60 * ((red - green) / d) + 240 }
            if h < 0 { h += 360 }
        }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }
}

/// 라이트·다크 한 쌍. 고정 토큰은 대비 증가 값을 가질 수 있다.
struct SkinColorPair: Equatable, Sendable {
    let light: SkinRGB
    let dark: SkinRGB
    var highContrastLight: SkinRGB?
    var highContrastDark: SkinRGB?

    func value(_ mode: SkinMode, highContrast: Bool = false) -> SkinRGB {
        switch mode {
        case .light: highContrast ? (highContrastLight ?? light) : light
        case .dark: highContrast ? (highContrastDark ?? dark) : dark
        }
    }
}

/// 스킨 하나 (7.2의 `skins[]` 한 칸).
struct Skin: Identifiable, Equatable, Sendable {
    static let defaultID = "default"

    let id: String
    /// 이 스킨을 여는 리워드 아이템 id. 기본 스킨은 nil.
    let itemID: String?
    /// 화면에 쓰는 색 이름(기본, 파랑, 청록, 주황, 보라. 3.1).
    let nameKo: String
    let colors: [SkinToken: SkinColorPair]

    var isDefault: Bool { id == Self.defaultID }

    func color(_ token: SkinToken, _ mode: SkinMode) -> SkinRGB? {
        colors[token]?.value(mode)
    }

    /// 단계에 맞는 바탕 토큰 (4.1). 대비 증가면 강·중 화면도 `AppBackgroundQuiet`(2.5).
    static func backgroundToken(_ level: SkinLevel, highContrast: Bool) -> SkinToken {
        switch level {
        case .strong, .medium: highContrast ? .appBackgroundQuiet : .appBackground
        case .quiet: .appBackgroundQuiet
        case .sheet: .appBackground
        }
    }
}

/// `skins.json` 전체 (7.2, 7.3).
struct SkinCatalog: Sendable {
    /// 앱이 아는 스키마 버전.
    static let supportedSchemaVersion = 2

    let schemaVersion: Int
    /// 스킨을 바꿀 때의 교차 페이드(초).
    let skinCrossfade: Double
    let base: [SkinBaseToken: SkinColorPair]
    /// 데이터 순서 그대로. 첫 번째가 기본 스킨이다.
    let skins: [Skin]
    /// 읽다가 버린 스킨 id와 이유(테스트·디버그용).
    let dropped: [String]

    var defaultSkin: Skin { skins.first { $0.isDefault } ?? Self.fallbackDefault }

    func skin(id: String) -> Skin? { skins.first { $0.id == id } }

    /// 색 id 또는 아이템 id로 찾는다(`-skinDebug orange`와 `-skinDebug torii`가 같다, 8.3).
    func skin(idOrItemID key: String) -> Skin? {
        skin(id: key) ?? skins.first { $0.itemID == key }
    }

    /// 아이템 id로 찾는다. 없거나 nil이면 기본 스킨.
    func skin(itemID: String?) -> Skin {
        guard let itemID else { return defaultSkin }
        return skins.first { $0.itemID == itemID } ?? defaultSkin
    }

    /// 저장 상태가 쓰는 스킨 (8.2). 슬롯 키가 없으면 기본 스킨.
    func skin(for rewards: RewardState) -> Skin {
        skin(itemID: rewards.equippedID(SkinPolicy.slot))
    }

    /// 견본 순서: 기본 → 장면 순서 (3.1, 5.2). 데이터 순서가 그 순서다.
    var orderedSkins: [Skin] { skins }

    // MARK: - 읽기

    static let shared: SkinCatalog = bundled()

    static func bundled(bundle: Bundle = .main) -> SkinCatalog {
        guard let url = bundle.url(forResource: "skins", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = SkinCatalog(data: data)
        else {
            #if DEBUG
            if !Self.isRunningTests { assertionFailure("skins.json을 읽지 못함") }
            #endif
            return fallback
        }
        return catalog
    }

    private static var isRunningTests: Bool { NSClassFromString("XCTestCase") != nil }

    /// 파일 전체를 못 쓰면 nil (스키마 버전이 2가 아니거나, 기본 스킨이 없거나, 고정 토큰이 빠짐. 7.3).
    init?(data: Data) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let version = root["schemaVersion"] as? Int, version == Self.supportedSchemaVersion,
              let baseObject = root["base"] as? [String: Any],
              let skinArray = root["skins"] as? [[String: Any]]
        else { return nil }

        var base: [SkinBaseToken: SkinColorPair] = [:]
        for token in SkinBaseToken.allCases {
            guard let pair = Self.pair(baseObject[token.rawValue]) else { return nil }
            base[token] = pair
        }

        let crossfade = ((root["motion"] as? [String: Any])?["skinCrossfade"] as? Double) ?? 0.3

        var skins: [Skin] = []
        var dropped: [String] = []
        for object in skinArray {
            if let skin = Self.skin(object) {
                if !skins.contains(where: { $0.id == skin.id }) { skins.append(skin) }
            } else {
                dropped.append(object["id"] as? String ?? "?")
            }
        }
        // 기본 스킨은 꼭 첫 번째에 있어야 한다 (7.3).
        guard skins.first?.isDefault == true else { return nil }

        self.schemaVersion = version
        self.skinCrossfade = crossfade
        self.base = base
        self.skins = skins
        self.dropped = dropped
    }

    init(schemaVersion: Int, skinCrossfade: Double,
         base: [SkinBaseToken: SkinColorPair], skins: [Skin], dropped: [String] = []) {
        self.schemaVersion = schemaVersion
        self.skinCrossfade = skinCrossfade
        self.base = base
        self.skins = skins
        self.dropped = dropped
    }

    private static func rgb(_ value: Any?) -> SkinRGB? {
        (value as? String).flatMap(SkinRGB.init(hex:))
    }

    private static func pair(_ value: Any?) -> SkinColorPair? {
        guard let object = value as? [String: Any],
              let light = rgb(object["light"]), let dark = rgb(object["dark"]) else { return nil }
        var pair = SkinColorPair(light: light, dark: dark)
        if let hc = object["highContrast"] as? [String: Any] {
            pair.highContrastLight = rgb(hc["light"])
            pair.highContrastDark = rgb(hc["dark"])
        }
        return pair
    }

    /// 스킨 하나. 필수 값(`id`, `nameKo`, 여섯 토큰의 light·dark)이 빠졌으면 nil (7.3). 모르는 키는 무시한다.
    private static func skin(_ object: [String: Any]) -> Skin? {
        guard let id = object["id"] as? String, !id.isEmpty,
              let nameKo = object["nameKo"] as? String, !nameKo.isEmpty,
              let colorObject = object["colors"] as? [String: Any]
        else { return nil }
        var colors: [SkinToken: SkinColorPair] = [:]
        for token in SkinToken.allCases {
            guard let pair = pair(colorObject[token.rawValue]) else { return nil }
            colors[token] = pair
        }
        return Skin(id: id, itemID: object["itemID"] as? String, nameKo: nameKo, colors: colors)
    }

    // MARK: - 파일을 못 읽을 때 (에셋 카탈로그의 Color Set과 같은 값)

    private static func hex(_ light: String, _ dark: String) -> SkinColorPair {
        SkinColorPair(light: SkinRGB(hex: light)!, dark: SkinRGB(hex: dark)!)
    }

    static let fallbackDefault = Skin(
        id: Skin.defaultID,
        itemID: nil,
        nameKo: "기본",
        colors: [
            .appBackground: hex("#FDF5E6", "#1F1714"),
            .appBackgroundQuiet: hex("#FBF2E1", "#1F1714"),
            .accentColor: hex("#4A2219", "#F7EEDF"),
            .accentForeground: hex("#FFFDF7", "#1F1714"),
            .accentText: hex("#4A2219", "#F7EEDF"),
            .pathEdge: hex("#E6D6BC", "#4A3A32"),
        ]
    )

    static let fallback = SkinCatalog(
        schemaVersion: supportedSchemaVersion,
        skinCrossfade: 0.3,
        base: [:],
        skins: [fallbackDefault]
    )
}
