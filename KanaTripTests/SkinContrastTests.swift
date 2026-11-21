import Foundation
import Testing
import UIKit
@testable import KanaTrip

// app-skin.md 2.4의 대비·색 거리 검사. tools/check_skin_contrast.py와 같은 식과 같은 예외 목록이다.
// skins.json을 고치고 검사를 잊지 않게 xcodebuild test에 묻어 간다.

private enum Rule {
    static let luminanceLightMin = 0.72
    static let luminanceDarkMax = 0.029
    static let cardQuietMin: [SkinMode: Double] = [.light: 1.07, .dark: 1.16]
    static let text = 4.5
    static let nonText = 3.0
    static let secondaryMix = 0.15
    static let verdictDeltaE = 30.0
    static let verdictHue = 30.0
    static let verdictChromaForHue = 30.0
    static let hintDeltaE = 20.0
    static let fixedOnBackground: [(SkinBaseToken, Double)] = [
        (.ink, text), (.inkSecondary, text), (.correct, nonText), (.wrong, nonText), (.highlightStrong, nonText), (.outline, nonText),
    ]
    /// tools/check_skin_contrast.py의 KNOWN_EXCEPTIONS와 같다 (app-skin.md 3.7 구현 메모).
    static let knownExceptions: Set<String> = [
        "default/light/CardBackground / Quiet",
        "noren/dark/CardBackground / Quiet",
        "eki/dark/CardBackground / Quiet",
    ]
}

private struct Failure: CustomStringConvertible {
    let skin: String, mode: String, what: String, value: Double, rule: String
    var description: String { "\(skin) \(mode) \(what) = \(String(format: "%.3f", value)) (기준 \(rule))" }
}

/// 2.4 표를 스킨 × 모드 × (보통 / 대비 증가)마다 계산해 못 넘은 것을 낸다. 알려진 예외는 빼고 따로 돌려준다.
private func checkAll(_ catalog: SkinCatalog) -> (failures: [Failure], exceptions: [Failure]) {
    var failures: [Failure] = [], exceptions: [Failure] = []
    for skin in catalog.skins {
        for mode in SkinMode.allCases {
            for hc in [false, true] {
                let label = mode.rawValue + (hc ? "-hc" : "")
                func check(_ what: String, _ value: Double, _ ok: Bool, _ rule: String) {
                    guard !ok else { return }
                    let failure = Failure(skin: skin.id, mode: label, what: what, value: value, rule: rule)
                    if Rule.knownExceptions.contains("\(skin.id)/\(mode.rawValue)/\(what)") {
                        exceptions.append(failure)
                    } else {
                        failures.append(failure)
                    }
                }
                func base(_ token: SkinBaseToken) -> SkinRGB { catalog.base[token]!.value(mode, highContrast: hc) }
                let bg = skin.rgb(.appBackground, mode: mode)
                let quiet = skin.rgb(.appBackgroundQuiet, mode: mode)
                let accent = skin.rgb(.accentColor, mode: mode)
                let accentFg = skin.rgb(.accentForeground, mode: mode)
                let card = base(.cardBackground)
                var screens: [(String, SkinRGB)] = [("Quiet", quiet)]
                if !hc {
                    screens.insert(("AppBackground", bg), at: 0)
                    if skin.pattern != nil, let ink = skin.color(.patternInk, mode), skin.patternOpacity(mode) > 0 {
                        screens.append(("무늬 픽셀", bg.mixed(with: ink, amount: skin.patternOpacity(mode))))
                    }
                }
                for (name, color) in screens {
                    let l = color.luminance
                    if mode == .light {
                        check("\(name) 휘도", l, l >= Rule.luminanceLightMin, ">= 0.72")
                    } else {
                        check("\(name) 휘도", l, l <= Rule.luminanceDarkMax, "<= 0.029")
                    }
                }
                let cq = card.contrast(quiet)
                check("CardBackground / Quiet", cq, cq >= Rule.cardQuietMin[mode]!, ">= \(Rule.cardQuietMin[mode]!)")
                let fg = accentFg.contrast(accent)
                check("AccentForeground / AccentColor", fg, fg >= Rule.text, ">= 4.5")
                for (name, color) in screens + [("CardBackground", card)] {
                    let r = accent.contrast(color)
                    check("AccentColor / \(name)", r, r >= Rule.nonText, ">= 3")
                }
                for (name, color) in screens where name != "무늬 픽셀" {
                    let r = accent.contrast(color.mixed(with: accent, amount: Rule.secondaryMix))
                    check("AccentColor / 보조 버튼 바탕(\(name))", r, r >= Rule.text, ">= 4.5")
                }
                for (token, minimum) in Rule.fixedOnBackground {
                    for (name, color) in screens {
                        let r = base(token).contrast(color)
                        check("\(token.rawValue) / \(name)", r, r >= minimum, ">= \(minimum)")
                    }
                }
                for token in [SkinBaseToken.wrong, .correct] {
                    let de = accent.deltaE(base(token))
                    check("AccentColor ΔE \(token.rawValue)", de, de >= Rule.verdictDeltaE, ">= 30")
                    if accent.chroma >= Rule.verdictChromaForHue {
                        let dh = accent.hueDifference(base(token))
                        check("AccentColor 색상각 차 \(token.rawValue)", dh, dh >= Rule.verdictHue, ">= 30°")
                    }
                }
                for token in [SkinBaseToken.highlightStrong, .highlight] {
                    let de = accent.deltaE(base(token))
                    check("AccentColor ΔE \(token.rawValue)", de, de >= Rule.hintDeltaE, ">= 20")
                }
                if !hc {
                    for token in [SkinToken.appBackground, .appBackgroundQuiet, .patternInk] {
                        guard let color = skin.color(token, mode) else { continue }
                        let (h, sat, _) = color.hsv
                        let banned = sat > 0 && ((125...160).contains(h) && sat >= 0.25 || (330..<360).contains(h))
                        check("\(token.rawValue) HSV 색상", h, !banned, "금지 범위 밖")
                    }
                }
            }
        }
    }
    return (failures, exceptions)
}

/// 에셋 카탈로그 Color Set의 sRGB 값.
private func assetRGB(_ name: String, _ mode: SkinMode, highContrast: Bool = false) -> SkinRGB? {
    let traits = UITraitCollection(traitsFrom: [
        UITraitCollection(userInterfaceStyle: mode == .dark ? .dark : .light),
        UITraitCollection(accessibilityContrast: highContrast ? .high : .normal),
    ])
    guard let named = UIColor(named: name, in: Bundle(for: ProgressStore.self), compatibleWith: traits) else { return nil }
    let color = named.resolvedColor(with: traits)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    return SkinRGB(red: Double(r), green: Double(g), blue: Double(b))
}

private func sameByte(_ a: SkinRGB, _ b: SkinRGB) -> Bool { a.description == b.description }

@Suite("앱 스킨 대비")
struct SkinContrastTests {
    let catalog = SkinCatalog.bundled(bundle: Bundle(for: ProgressStore.self))

    @Test func bundledFileHasFiveSkinsInOrder() {
        #expect(catalog.schemaVersion == 1)
        #expect(catalog.skins.map(\.id) == ["default", "noren", "eki", "torii", "yu"])
        #expect(catalog.dropped.isEmpty)
        #expect(catalog.skins.map(\.itemID) == [nil, "noren", "eki", "torii", "yu"])
        #expect(catalog.patternScale(.strong) == 1)
        #expect(catalog.patternScale(.medium) == 0.5)
        #expect(catalog.patternScale(.quiet) == 0)
        #expect(catalog.patternScale(.sheet) == 0)
        #expect(catalog.skinCrossfade == 0.3)
        #expect(catalog.defaultSkin.pattern == nil)
        #expect(catalog.skins.dropFirst().allSatisfy { $0.pattern != nil && $0.giriBackdrop == "Item-\($0.itemID ?? "")" })
    }

    /// 무늬 타일과 기리 뒤 그림 에셋이 번들에 있다 (3.4). 무늬 타일은 tools/make_skin_patterns.py가 만든다.
    @Test func skinImagesExistInBundle() {
        let bundle = Bundle(for: ProgressStore.self)
        for skin in catalog.skins {
            for name in [skin.pattern, skin.giriBackdrop].compactMap({ $0 }) {
                #expect(UIImage(named: name, in: bundle, compatibleWith: nil) != nil, "\(name)")
            }
        }
    }

    /// 스킨 아이템은 rewards.json의 배경 슬롯 아이템과 하나씩 맞는다 (3.1).
    @Test func everySkinItemIsABackgroundRewardItem() {
        let rewards = ProgressStore(storage: SkinTestStorage()).rewardCatalog
        let backgroundIDs = rewards.items(in: .background).map(\.id)
        #expect(catalog.skins.compactMap(\.itemID) == backgroundIDs)
        #expect(rewards.items(in: .background).allSatisfy { $0.price == 300 })
    }

    @Test func allSkinsPassContrastAndDistanceRules() {
        let result = checkAll(catalog)
        #expect(result.failures.isEmpty, "\(result.failures)")
        // 예외 목록이 낡지 않게: 예외로 둔 조합은 지금도 실제로 기준을 못 넘는 것이어야 한다.
        let seen = Set(result.exceptions.map { "\($0.skin)/\($0.mode.replacingOccurrences(of: "-hc", with: ""))/\($0.what)" })
        #expect(seen == Rule.knownExceptions)
    }

    /// 이슈 #7에서 정한 두 조합 (3.6): とりい 주황과 오답 빨강, えき 청록과 맞음 초록.
    @Test func toriiOrangeAndEkiTealKeepDistanceFromVerdictColors() throws {
        let torii = try #require(catalog.skin(id: "torii")), eki = try #require(catalog.skin(id: "eki"))
        let wrong = try #require(catalog.base[.wrong]), correct = try #require(catalog.base[.correct])
        for mode in SkinMode.allCases {
            let orange = torii.rgb(.accentColor, mode: mode)
            #expect(orange.deltaE(wrong.value(mode)) >= 30)
            #expect(orange.hueDifference(wrong.value(mode)) >= 30)
            let teal = eki.rgb(.accentColor, mode: mode)
            #expect(teal.deltaE(correct.value(mode)) >= 30)
            // 노랑-파랑 축(b*)의 부호가 반대다 (3.6).
            #expect(teal.lab.b < 0 && correct.value(mode).lab.b > 0)
        }
        #expect(abs(torii.rgb(.accentColor, mode: .light).deltaE(wrong.light) - 38.1) < 0.2)
        #expect(abs(eki.rgb(.accentColor, mode: .light).deltaE(correct.light) - 43.0) < 0.2)
    }

    /// 에셋 카탈로그의 Color Set은 기본 스킨 값과 고정 토큰 값이어야 한다 (7.3).
    @Test func assetColorSetsMatchDefaultSkinAndBase() throws {
        let skin = catalog.defaultSkin
        for token in [SkinToken.appBackground, .accentColor, .accentForeground, .pathEdge] {
            for mode in SkinMode.allCases {
                let asset = try #require(assetRGB(token.rawValue, mode))
                #expect(sameByte(asset, skin.rgb(token, mode: mode)), "\(token.rawValue) \(mode)")
            }
        }
        for token in SkinBaseToken.allCases {
            let pair = try #require(catalog.base[token])
            for mode in SkinMode.allCases {
                for hc in [false, true] {
                    let asset = try #require(assetRGB(token.rawValue, mode, highContrast: hc))
                    #expect(sameByte(asset, pair.value(mode, highContrast: hc)), "\(token.rawValue) \(mode) hc=\(hc)")
                }
            }
        }
    }

    /// 강도 단계와 대비 증가의 바탕·무늬 (4.1, 2.5).
    @Test func levelsPickBackgroundAndPatternOpacity() throws {
        let noren = try #require(catalog.skin(id: "noren"))
        #expect(Skin.backgroundToken(.strong, highContrast: false) == .appBackground)
        #expect(Skin.backgroundToken(.medium, highContrast: false) == .appBackground)
        #expect(Skin.backgroundToken(.quiet, highContrast: false) == .appBackgroundQuiet)
        #expect(Skin.backgroundToken(.sheet, highContrast: false) == .appBackground)
        #expect(Skin.backgroundToken(.strong, highContrast: true) == .appBackgroundQuiet)
        #expect(Skin.backgroundToken(.medium, highContrast: true) == .appBackgroundQuiet)
        #expect(noren.patternOpacity(.light, level: .strong, highContrast: false, catalog: catalog) == 0.06)
        #expect(noren.patternOpacity(.light, level: .medium, highContrast: false, catalog: catalog) == 0.03)
        #expect(noren.patternOpacity(.dark, level: .strong, highContrast: false, catalog: catalog) == 0.05)
        #expect(noren.patternOpacity(.light, level: .quiet, highContrast: false, catalog: catalog) == 0)
        #expect(noren.patternOpacity(.light, level: .sheet, highContrast: false, catalog: catalog) == 0)
        #expect(noren.patternOpacity(.light, level: .strong, highContrast: true, catalog: catalog) == 0)
        #expect(catalog.defaultSkin.patternOpacity(.light, level: .strong, highContrast: false, catalog: catalog) == 0)
    }

    /// 강조색 밖의 고정 토큰은 모든 스킨에서 같다: 스킨은 고정 토큰을 갖지 않는다 (1.2).
    @Test func skinsCarryOnlySkinTokens() {
        for skin in catalog.skins {
            #expect(Set(skin.colors.keys).isSubset(of: Set(SkinToken.allCases)))
        }
        #expect(Set(catalog.base.keys) == Set(SkinBaseToken.allCases))
    }
}

// MARK: - 읽기 규칙 (7.3)

private func json(_ skins: String, version: Int = 1, base: String? = nil) -> Data {
    let baseJSON = base ?? SkinBaseToken.allCases.map { "\"\($0.rawValue)\": {\"light\": \"#FFFFFF\", \"dark\": \"#000000\"}" }
        .joined(separator: ", ")
    return Data("""
    {"schemaVersion": \(version), "levels": {"strong": {"patternScale": 1.0}, "medium": {"patternScale": 0.5},
     "quiet": {"patternScale": 0.0}, "sheet": {"patternScale": 0.0}}, "motion": {"skinCrossfade": 0.3},
     "base": {\(baseJSON)}, "skins": [\(skins)], "futureKey": 1}
    """.utf8)
}

private func skinJSON(_ id: String, itemID: String? = nil, pattern: String? = "p", dropKey: String? = nil, patternInk: String = "{\"light\": \"#112233\", \"dark\": \"#445566\"}") -> String {
    var colors = [
        "\"AppBackground\": {\"light\": \"#FDF5E6\", \"dark\": \"#1F1714\"}",
        "\"AppBackgroundQuiet\": {\"light\": \"#FDF5E6\", \"dark\": \"#1F1714\"}",
        "\"AccentColor\": {\"light\": \"#4A2219\", \"dark\": \"#F7EEDF\"}",
        "\"AccentForeground\": {\"light\": \"#FFFDF7\", \"dark\": \"#1F1714\"}",
        "\"PatternInk\": \(patternInk)",
        "\"PathEdge\": {\"light\": \"#E6D6BC\", \"dark\": \"#4A3A32\"}",
    ]
    if let dropKey { colors.removeAll { $0.hasPrefix("\"\(dropKey)\"") } }
    let item = itemID.map { "\"\($0)\"" } ?? "null"
    let p = pattern.map { "\"\($0)\"" } ?? "null"
    return """
    {"id": "\(id)", "itemID": \(item), "nameKo": "\(id)", "colors": {\(colors.joined(separator: ", "))},
     "patternOpacity": {"light": 0.06, "dark": 0.05}, "images": {"pattern": \(p), "giriBackdrop": null}, "unknown": true}
    """
}

@Suite("앱 스킨 읽기 규칙")
struct SkinCatalogReadingTests {
    @Test func skinMissingRequiredValueIsDroppedOthersKept() throws {
        let data = json([
            skinJSON("default", pattern: nil, patternInk: "null"),
            skinJSON("a", itemID: "a"),
            skinJSON("b", itemID: "b", dropKey: "PathEdge"),
            skinJSON("c", itemID: "c", patternInk: "{\"light\": \"#112233\"}"),
            skinJSON("d", itemID: "d", patternInk: "null"),
        ].joined(separator: ","))
        let catalog = try #require(SkinCatalog(data: data))
        #expect(catalog.skins.map(\.id) == ["default", "a"])
        #expect(catalog.dropped == ["b", "c", "d"])
        // 버린 스킨의 아이템을 입은 사용자는 기본 스킨으로 그린다.
        #expect(catalog.skin(itemID: "b").isDefault)
        #expect(catalog.skin(itemID: "a").id == "a")
    }

    @Test func newerSchemaOrMissingDefaultIsRejected() {
        #expect(SkinCatalog(data: json(skinJSON("default", pattern: nil, patternInk: "null"), version: 2)) == nil)
        #expect(SkinCatalog(data: json(skinJSON("a", itemID: "a"))) == nil)
        // 기본 스킨은 꼭 첫 번째에 있어야 한다.
        #expect(SkinCatalog(data: json([skinJSON("a", itemID: "a"), skinJSON("default", pattern: nil, patternInk: "null")]
            .joined(separator: ","))) == nil)
        #expect(SkinCatalog(data: Data("not json".utf8)) == nil)
    }

    @Test func missingFileFallsBackToAssetValues() {
        let fallback = SkinCatalog.bundled(bundle: Bundle(for: SkinTestStorage.self))
        #expect(fallback.skins.map(\.id) == ["default"])
        #expect(fallback.defaultSkin.rgb(.accentColor, mode: .light).description == "#4A2219")
    }
}

// MARK: - 저장 상태에서 스킨 (8.2)

private final class SkinTestStorage: ProgressStorage {
    var raw: Data?
    var saved: ProgressState?
    func load() -> ProgressState? {
        if let saved { return saved }
        return raw.flatMap { try? JSONDecoder().decode(ProgressState.self, from: $0) }
    }
    func save(_ state: ProgressState) { saved = state }
}

private let done = #"{"completed": true, "learnDone": [], "wordsDone": [], "quizWrong": []}"#

@Suite("앱 스킨 저장 상태")
struct SkinStoreTests {
    let catalog = SkinCatalog.bundled(bundle: Bundle(for: ProgressStore.self))

    private func store(rewards: String, sessions: String = "") -> ProgressStore {
        let storage = SkinTestStorage()
        storage.raw = Data("""
        {"version": \(ProgressState.currentVersion), "sessions": {\(sessions)}, "rewards": \(rewards)}
        """.utf8)
        return ProgressStore(storage: storage)
    }

    private func skin(_ store: ProgressStore) -> Skin {
        let skins = SkinStore(catalog: catalog)
        skins.progress = store
        return skins.current
    }

    @Test func newUserHasDefaultSkin() {
        let s = ProgressStore(storage: SkinTestStorage())
        #expect(skin(s).isDefault)
    }

    /// 배경 아이템을 사서 쓰던 사용자(리워드 버전 2)는 업데이트 뒤 그 스킨이다. 저장 형식 이행은 없다.
    @Test func existingBackgroundUserGetsThatSkin() {
        let s = store(rewards: """
        {"version": 2, "coins": 0, "paid": ["scene/sushi"], "owned": ["noren"],
         "equipped": {"top": "chef_hat", "rice": "plain_rice", "background": "noren"}}
        """)
        #expect(s.rewards.equippedID(.background) == "noren")
        #expect(skin(s).id == "noren")
        #expect(s.rewards.version == RewardState.currentVersion)
    }

    /// 꾸미기 개편 전 저장(리워드 버전 없음 = 1)에서 배경을 쓰던 사용자도 그 스킨으로 이어진다.
    @Test func oldVersionBackgroundUserGetsThatSkin() {
        let s = store(rewards: """
        {"coins": 0, "paid": ["scene/shrine"], "owned": ["torii"],
         "equipped": {"hat": "chef_hat", "scarf": "red_scarf", "background": "torii"}}
        """)
        #expect(skin(s).id == "torii")
    }

    /// 산 뒤 쓰지 않는 사용자, 갖지 않은 아이템을 입은 저장, 목록에 없는 id는 기본 스킨.
    @Test func notWearingOrInvalidMeansDefault() {
        let owned = store(rewards: """
        {"version": 2, "owned": ["eki"], "equipped": {"top": "chef_hat", "rice": "plain_rice"}}
        """)
        #expect(skin(owned).isDefault)
        let notOwned = store(rewards: """
        {"version": 2, "owned": [], "equipped": {"top": "chef_hat", "rice": "plain_rice", "background": "yu"}}
        """)
        #expect(skin(notOwned).isDefault)
        let unknown = store(rewards: """
        {"version": 2, "owned": ["ghost"], "equipped": {"background": "ghost"}}
        """)
        #expect(skin(unknown).isDefault)
    }

    /// 쓰는 스킨을 바꾸면 곧바로 그 스킨이고, 기본 칸(슬롯 비우기)은 키를 지운다 (5.3).
    @Test func equipAndClearChangeSkin() throws {
        let s = store(rewards: """
        {"version": 2, "owned": ["noren", "eki"], "equipped": {"top": "chef_hat", "rice": "plain_rice", "background": "noren"}}
        """)
        let skins = SkinStore(catalog: catalog)
        skins.progress = s
        #expect(skins.current.id == "noren")
        s.equip(try #require(s.rewardCatalog.item(id: "eki")))
        #expect(skins.current.id == "eki")
        s.clearSlot(.background)
        #expect(s.rewards.equipped["background"] == nil)
        #expect(skins.current.isDefault)
    }

    /// "기본 차림으로"는 스킨을 건드리지 않고, 스킨만 바뀐 상태는 기본 차림이다 (5.5, 권장안).
    @Test func resetOutfitKeepsSkin() {
        let s = store(rewards: """
        {"version": 2, "owned": ["noren", "tamago"], "equipped": {"top": "tamago", "rice": "plain_rice", "background": "noren"}}
        """, sessions: "\"sushi-a\": \(done), \"sushi-b\": \(done), \"sushi-quiz\": \(done)")
        #expect(!s.rewards.isDefaultOutfit)
        s.resetOutfit()
        #expect(s.rewards.equippedID(.top) == "chef_hat")
        #expect(s.rewards.isDefaultOutfit == SkinPolicy.resetOutfitKeepsSkin)
        #expect((s.rewards.equippedID(.background) == "noren") == SkinPolicy.resetOutfitKeepsSkin)
        #expect(skin(s).id == (SkinPolicy.resetOutfitKeepsSkin ? "noren" : "default"))
    }

    /// 디버그 스킨은 저장 상태보다 앞선다(메모리에서만, 8.3).
    @Test func debugSkinOverridesWithoutSaving() {
        let s = ProgressStore(storage: SkinTestStorage())
        let skins = SkinStore(catalog: catalog)
        skins.progress = s
        skins.debugSkinID = "yu"
        #expect(skins.current.id == "yu")
        #expect(s.rewards.equipped["background"] == nil)
        skins.debugSkinID = "nope"
        #expect(skins.current.isDefault)
    }
}
