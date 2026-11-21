import Foundation
import Testing
import UIKit
@testable import KanaTrip

// app-skin.md 2.4의 대비·색 거리 검사. tools/check_skin_contrast.py와 같은 식과 같은 예외 목록(비어 있음)이다.
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
    /// tools/check_skin_contrast.py의 KNOWN_EXCEPTIONS와 같다. 2026-11-21 색상 선택 개정에서 비웠다(app-skin.md 3.5).
    static let knownExceptions: Set<String> = []
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
                let accentText = skin.rgb(.accentText, mode: mode)
                let card = base(.cardBackground)
                // 대비 증가: 바탕 단계 화면도 Quiet (2.5)
                var screens: [(String, SkinRGB)] = [("Quiet", quiet)]
                if !hc { screens.insert(("AppBackground", bg), at: 0) }
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
                // 강조 글자·선 (2.4의 4, 5)
                for (name, color) in screens + [("CardBackground", card)] {
                    let r = accentText.contrast(color)
                    check("AccentText / \(name)", r, r >= Rule.text, ">= 4.5")
                }
                for (name, color) in screens {
                    let r = accentText.contrast(color.mixed(with: accentText, amount: Rule.secondaryMix))
                    check("AccentText / 보조 버튼 바탕(\(name))", r, r >= Rule.text, ">= 4.5")
                }
                for (token, minimum) in Rule.fixedOnBackground {
                    for (name, color) in screens {
                        let r = base(token).contrast(color)
                        check("\(token.rawValue) / \(name)", r, r >= minimum, ">= \(minimum)")
                    }
                }
                // 면·글자 둘 다 판정색·힌트색과 거리 (2.4의 7, 8). 값이 같으면 한 번.
                var accents: [(String, SkinRGB)] = [("AccentColor", accent)]
                if accentText != accent { accents.append(("AccentText", accentText)) }
                for (aname, a) in accents {
                    for token in [SkinBaseToken.wrong, .correct] {
                        let de = a.deltaE(base(token))
                        check("\(aname) ΔE \(token.rawValue)", de, de >= Rule.verdictDeltaE, ">= 30")
                        if a.chroma >= Rule.verdictChromaForHue {
                            let dh = a.hueDifference(base(token))
                            check("\(aname) 색상각 차 \(token.rawValue)", dh, dh >= Rule.verdictHue, ">= 30°")
                        }
                    }
                    for token in [SkinBaseToken.highlightStrong, .highlight] {
                        let de = a.deltaE(base(token))
                        check("\(aname) ΔE \(token.rawValue)", de, de >= Rule.hintDeltaE, ">= 20")
                    }
                }
                if !hc {
                    for token in [SkinToken.appBackground, .appBackgroundQuiet] {
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

    @Test func bundledFileHasFiveColorsInOrder() {
        #expect(catalog.schemaVersion == 2)
        #expect(catalog.skins.map(\.id) == ["default", "blue", "teal", "orange", "purple"])
        #expect(catalog.skins.map(\.nameKo) == ["기본", "파랑", "청록", "주황", "보라"])
        #expect(catalog.dropped.isEmpty)
        #expect(catalog.skins.map(\.itemID) == [nil, "noren", "eki", "torii", "yu"])
        #expect(catalog.skinCrossfade == 0.3)
    }

    /// 면(AccentColor)과 글자·선(AccentText)은 주황 라이트만 다르다. 다크는 글자 = 면, 면 위 글자 = 바탕 (2.1, 2.3).
    @Test func accentTextSplitsOnlyForOrangeLight() throws {
        for skin in catalog.skins {
            let sameLight = skin.rgb(.accentText, mode: .light) == skin.rgb(.accentColor, mode: .light)
            #expect(sameLight == (skin.id != "orange"), "\(skin.id)")
            #expect(skin.rgb(.accentText, mode: .dark) == skin.rgb(.accentColor, mode: .dark), "\(skin.id)")
            #expect(skin.rgb(.accentForeground, mode: .dark) == skin.rgb(.appBackground, mode: .dark), "\(skin.id)")
        }
        let orange = try #require(catalog.skin(id: "orange"))
        #expect(orange.rgb(.accentColor, mode: .light).description == "#F57F20")
        #expect(orange.rgb(.accentForeground, mode: .light).description == "#4A2219")
        #expect(orange.rgb(.accentText, mode: .light).description == "#8A4208")
    }

    /// 무늬 타일은 지웠고(개정 2, 6번), 기리 뒤 그림 4장은 Q1이 정해질 때까지 번들에 남긴다.
    @Test func patternTilesRemovedItemArtKeptUntilQ1() {
        let bundle = Bundle(for: ProgressStore.self)
        for name in ["seigaiha", "tenji", "asanoha", "tatewaku"].map({ "skin-pattern-\($0)" }) {
            #expect(UIImage(named: name, in: bundle, compatibleWith: nil) == nil, "\(name)")
        }
        for name in ["noren", "eki", "torii", "yu"].map({ "Item-\($0)" }) {
            #expect(UIImage(named: name, in: bundle, compatibleWith: nil) != nil, "\(name)")
        }
    }

    /// `itemID`는 옛 저장을 옮길 때만 읽는다. rewards.json의 배경 슬롯 아이템과 하나씩 맞는다 (개정 2, 7번).
    @Test func everySkinItemIDIsABackgroundRewardItem() {
        let rewards = ProgressStore(storage: SkinTestStorage()).rewardCatalog
        let backgroundIDs = rewards.items.filter { $0.slot == .background }.map(\.id)
        #expect(catalog.skins.compactMap(\.itemID) == backgroundIDs)
    }

    @Test func allSkinsPassContrastAndDistanceRules() {
        let result = checkAll(catalog)
        #expect(result.failures.isEmpty, "\(result.failures)")
        // 예외 목록이 낡지 않게: 예외로 둔 조합은 지금도 실제로 기준을 못 넘는 것이어야 한다.
        let seen = Set(result.exceptions.map { "\($0.skin)/\($0.mode.replacingOccurrences(of: "-hc", with: ""))/\($0.what)" })
        #expect(seen == Rule.knownExceptions)
    }

    /// 이슈 #7에서 정한 두 조합 (3.3, 3.4): 주황과 오답 빨강, 청록과 맞음 초록.
    @Test func orangeAndTealKeepDistanceFromVerdictColors() throws {
        let orange = try #require(catalog.skin(id: "orange")), teal = try #require(catalog.skin(id: "teal"))
        let wrong = try #require(catalog.base[.wrong]), correct = try #require(catalog.base[.correct])
        for mode in SkinMode.allCases {
            for token in [SkinToken.accentColor, .accentText] {
                let o = orange.rgb(token, mode: mode)
                #expect(o.deltaE(wrong.value(mode)) >= 30)
                #expect(o.hueDifference(wrong.value(mode)) >= 30)
                let t = teal.rgb(token, mode: mode)
                #expect(t.deltaE(correct.value(mode)) >= 30)
                // 노랑-파랑 축(b*)의 부호가 반대다 (3.4).
                #expect(t.lab.b < 0 && correct.value(mode).lab.b > 0)
            }
        }
        // 설계 문서의 손 계산 값 (3.3, 3.4)
        #expect(abs(orange.rgb(.accentColor, mode: .light).deltaE(wrong.light) - 53.3) < 0.5)
        #expect(abs(orange.rgb(.accentText, mode: .light).deltaE(wrong.light) - 38.2) < 0.5)
        #expect(abs(teal.rgb(.accentColor, mode: .light).deltaE(correct.light) - 43.0) < 0.2)
        #expect(abs(teal.rgb(.accentColor, mode: .dark).deltaE(correct.dark) - 42.1) < 0.5)
    }

    /// 에셋 카탈로그의 Color Set은 기본 스킨 값과 고정 토큰 값이어야 한다 (7.3).
    @Test func assetColorSetsMatchDefaultSkinAndBase() throws {
        let skin = catalog.defaultSkin
        for token in SkinToken.allCases {
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

    /// 강도 단계와 대비 증가의 바탕 (4.1, 2.5).
    @Test func levelsPickBackground() {
        #expect(Skin.backgroundToken(.strong, highContrast: false) == .appBackground)
        #expect(Skin.backgroundToken(.medium, highContrast: false) == .appBackground)
        #expect(Skin.backgroundToken(.quiet, highContrast: false) == .appBackgroundQuiet)
        #expect(Skin.backgroundToken(.sheet, highContrast: false) == .appBackground)
        #expect(Skin.backgroundToken(.strong, highContrast: true) == .appBackgroundQuiet)
        #expect(Skin.backgroundToken(.medium, highContrast: true) == .appBackgroundQuiet)
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

private func json(_ skins: String, version: Int = 2, base: String? = nil) -> Data {
    let baseJSON = base ?? SkinBaseToken.allCases.map { "\"\($0.rawValue)\": {\"light\": \"#FFFFFF\", \"dark\": \"#000000\"}" }
        .joined(separator: ", ")
    return Data("""
    {"schemaVersion": \(version), "levels": {"strong": {"background": "AppBackground"}},
     "motion": {"skinCrossfade": 0.3}, "base": {\(baseJSON)}, "skins": [\(skins)], "futureKey": 1}
    """.utf8)
}

private func skinJSON(_ id: String, itemID: String? = nil, dropKey: String? = nil, accentText: String = "{\"light\": \"#4A2219\", \"dark\": \"#F7EEDF\"}", nameKo: String? = nil) -> String {
    var colors = [
        "\"AppBackground\": {\"light\": \"#FDF5E6\", \"dark\": \"#1F1714\"}",
        "\"AppBackgroundQuiet\": {\"light\": \"#FBF2E1\", \"dark\": \"#1F1714\"}",
        "\"AccentColor\": {\"light\": \"#4A2219\", \"dark\": \"#F7EEDF\"}",
        "\"AccentForeground\": {\"light\": \"#FFFDF7\", \"dark\": \"#1F1714\"}",
        "\"AccentText\": \(accentText)",
        "\"PathEdge\": {\"light\": \"#E6D6BC\", \"dark\": \"#4A3A32\"}",
    ]
    if let dropKey { colors.removeAll { $0.hasPrefix("\"\(dropKey)\"") } }
    let item = itemID.map { "\"\($0)\"" } ?? "null"
    return """
    {"id": "\(id)", "itemID": \(item), "nameKo": "\(nameKo ?? id)", "colors": {\(colors.joined(separator: ", "))},
     "unknown": true, "images": {"pattern": "old"}}
    """
}

@Suite("앱 스킨 읽기 규칙")
struct SkinCatalogReadingTests {
    @Test func skinMissingRequiredValueIsDroppedOthersKept() throws {
        let data = json([
            skinJSON("default"),
            skinJSON("a", itemID: "a"),
            skinJSON("b", itemID: "b", dropKey: "PathEdge"),
            skinJSON("c", itemID: "c", accentText: "{\"light\": \"#112233\"}"),
            skinJSON("d", itemID: "d", dropKey: "AccentText"),
            skinJSON("e", itemID: "e", nameKo: ""),
        ].joined(separator: ","))
        let catalog = try #require(SkinCatalog(data: data))
        #expect(catalog.skins.map(\.id) == ["default", "a"])
        #expect(catalog.dropped == ["b", "c", "d", "e"])
        // 버린 색의 아이템을 쓰던 사용자는 기본 색으로 그린다.
        #expect(catalog.skin(itemID: "b").isDefault)
        #expect(catalog.skin(itemID: "a").id == "a")
    }

    /// 앱이 아는 버전은 2뿐이다. 1(옛 무늬 스킨)과 3 이상은 파일 전체를 버린다 (7.3).
    @Test func otherSchemaOrMissingDefaultIsRejected() {
        #expect(SkinCatalog(data: json(skinJSON("default"))) != nil)
        #expect(SkinCatalog(data: json(skinJSON("default"), version: 1)) == nil)
        #expect(SkinCatalog(data: json(skinJSON("default"), version: 3)) == nil)
        #expect(SkinCatalog(data: json(skinJSON("a", itemID: "a"))) == nil)
        // 기본 스킨은 꼭 첫 번째에 있어야 한다.
        #expect(SkinCatalog(data: json([skinJSON("a", itemID: "a"), skinJSON("default")].joined(separator: ","))) == nil)
        #expect(SkinCatalog(data: Data("not json".utf8)) == nil)
    }

    @Test func missingFileFallsBackToAssetValues() {
        let fallback = SkinCatalog.bundled(bundle: Bundle(for: SkinTestStorage.self))
        #expect(fallback.skins.map(\.id) == ["default"])
        #expect(fallback.defaultSkin.rgb(.accentColor, mode: .light).description == "#4A2219")
        #expect(fallback.defaultSkin.rgb(.accentText, mode: .light).description == "#4A2219")
        #expect(fallback.defaultSkin.rgb(.appBackgroundQuiet, mode: .light).description == "#FBF2E1")
        // 대체 값은 번들 파일의 기본 색과 같다.
        let bundled = SkinCatalog.bundled(bundle: Bundle(for: ProgressStore.self)).defaultSkin
        for token in SkinToken.allCases {
            for mode in SkinMode.allCases {
                #expect(fallback.defaultSkin.rgb(token, mode: mode) == bundled.rgb(token, mode: mode), "\(token) \(mode)")
            }
        }
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

    /// 옛 저장(배경 아이템을 쓰던 사용자, 리워드 버전 2)을 읽으면 그 색이고, 다시 저장하면 `skin`에 색 id가 있다 (개정 2 저장 이전).
    @Test func existingBackgroundUserIsMigratedToSkinID() throws {
        let storage = SkinTestStorage()
        storage.raw = Data("""
        {"version": \(ProgressState.currentVersion), "sessions": {},
         "rewards": {"version": 2, "coins": 0, "paid": ["scene/shrine"], "owned": ["torii"],
                     "equipped": {"top": "chef_hat", "rice": "plain_rice", "background": "torii"}}}
        """.utf8)
        let s = ProgressStore(storage: storage)
        #expect(skin(s).id == "orange")
        #expect(s.rewards.skin == "orange")
        // 색은 아이템 슬롯이 아니다. owned와 엔은 그대로 (Q2).
        #expect(s.rewards.equipped["background"] == nil)
        #expect(s.rewards.owned == ["torii"])
        let saved = try #require(storage.saved)
        #expect(saved.rewards.skin == "orange")
        let data = try JSONEncoder().encode(saved)
        #expect(String(decoding: data, as: UTF8.self).contains("\"skin\":\"orange\""))
        // 다시 읽어도 같다.
        #expect(skin(ProgressStore(storage: storage)).id == "orange")
    }

    /// 꾸미기 개편 전 저장(리워드 버전 없음 = 1)에서 배경을 쓰던 사용자도 그 색으로 옮긴다.
    @Test func oldVersionBackgroundUserGetsThatSkin() {
        let s = store(rewards: """
        {"coins": 0, "paid": ["scene/shrine"], "owned": ["torii"],
         "equipped": {"hat": "chef_hat", "scarf": "red_scarf", "background": "torii"}}
        """)
        #expect(skin(s).id == "orange")
    }

    /// `skin` 키가 있으면 옛 값보다 앞선다. 목록에 없는 색 id는 기본으로 그리되 지우지 않는다.
    @Test func skinKeyWinsAndUnknownIsKept() {
        let both = store(rewards: """
        {"version": 2, "skin": "purple", "owned": [], "equipped": {"top": "chef_hat", "rice": "plain_rice", "background": "noren"}}
        """)
        #expect(skin(both).id == "purple")
        let unknown = store(rewards: """
        {"version": 2, "skin": "ghost", "owned": []}
        """)
        #expect(skin(unknown).isDefault)
        #expect(unknown.rewards.skin == "ghost")
        let unknownItem = store(rewards: """
        {"version": 2, "owned": ["ghost"], "equipped": {"background": "ghost"}}
        """)
        #expect(skin(unknownItem).isDefault)
        #expect(unknownItem.rewards.skin == nil)
    }

    /// 새 사용자도 아무 장면 없이 다섯 색을 모두 쓸 수 있다. 기본을 고르면 키를 지운다 (5.3).
    @Test func anyColorCanBeUsedWithoutScenes() {
        let s = ProgressStore(storage: SkinTestStorage())
        let skins = SkinStore(catalog: catalog)
        skins.progress = s
        for color in catalog.orderedSkins {
            s.setSkin(color.isDefault ? nil : color.id)
            #expect(skins.current.id == color.id)
        }
        s.setSkin("blue")
        s.setSkin(Skin.defaultID)
        #expect(s.rewards.skin == nil)
        #expect(skins.current.isDefault)
        #expect(s.rewards.coins == 0)
    }

    /// 색 아이템은 팔지 않는다(Q1 결정 전 임시 동작): 장면 1을 끝내도 열린 아이템·살 수 있음에 색이 없다.
    @Test func colorItemsAreNotSoldBeforeQ1() {
        let s = store(rewards: """
        {"version": 2, "coins": 900, "paid": [], "owned": []}
        """, sessions: "\"sushi-a\": \(done), \"sushi-b\": \(done), \"sushi-quiz\": \(done)")
        #expect(!SkinPolicy.sellsColorItems)
        let catalog = s.rewardCatalog
        #expect(catalog.items(forScene: "sushi").allSatisfy { $0.slot != .background })
        #expect(catalog.items(in: .background).isEmpty)
        #expect(RewardRules.buyableItems(state: s.rewards, catalog: catalog).allSatisfy { $0.slot != .background })
        // 데이터에는 남아 있다(옛 owned를 지우지 않으려고).
        #expect(catalog.item(id: "noren") != nil)
    }

    /// "기본 차림으로"는 색을 건드리지 않고, 색만 바뀐 상태는 기본 차림이다 (5.5, 권장안).
    @Test func resetOutfitKeepsSkin() {
        let s = store(rewards: """
        {"version": 2, "skin": "blue", "owned": ["tamago"], "equipped": {"top": "tamago", "rice": "plain_rice"}}
        """, sessions: "\"sushi-a\": \(done), \"sushi-b\": \(done), \"sushi-quiz\": \(done)")
        #expect(!s.rewards.isDefaultOutfit)
        s.resetOutfit()
        #expect(s.rewards.equippedID(.top) == "chef_hat")
        #expect(s.rewards.isDefaultOutfit)
        #expect(skin(s).id == "blue")
    }

    /// 디버그 스킨은 저장 상태보다 앞선다(메모리에서만, 8.3).
    @Test func debugSkinOverridesWithoutSaving() {
        let s = ProgressStore(storage: SkinTestStorage())
        let skins = SkinStore(catalog: catalog)
        skins.progress = s
        skins.debugSkinID = "purple"
        #expect(skins.current.id == "purple")
        #expect(s.rewards.skin == nil)
        // 아이템 id도 받는다(`-skinDebug torii` = `-skinDebug orange`, 8.3).
        skins.debugSkinID = "torii"
        #expect(skins.current.id == "orange")
        skins.debugSkinID = "nope"
        #expect(skins.current.isDefault)
    }
}
