import Foundation
import Testing
import UIKit
@testable import KanaTrip

// 홈 바탕 (docs/design/home-backdrop.md): 데이터 읽기, 열림 규칙, 저장, 합성 휘도 기준.
// 합성 기준은 tools/make_backdrop_art.py verify와 같은 식으로 에셋 픽셀을 다시 계산한다.

private let appBundle = Bundle(for: ProgressStore.self)

private func data(_ backdrops: String, version: Int = 1, unlock: String? = nil) -> Data {
    let unlockJSON = unlock.map { "\"unlock\": \"\($0)\"," } ?? ""
    return Data("""
    {"schemaVersion": \(version), \(unlockJSON) "futureKey": [1, 2],
     "layout": {"stripAspect": 2.0, "fadeTop": 16, "haloWidth": 2, "artMatInset": 4, "artMatCorner": 16, "dotHaloDiameter": 8},
     "limits": {"lightMinLuminance": 0.55, "lightPercentile": 0.1, "darkMaxLuminance": 0.06, "darkPercentile": 99.9,
                "lightOpacity": {"min": 0.2, "max": 0.4}, "darkOpacity": {"min": 0.06, "max": 0.25}},
     "backdrops": [\(backdrops)]}
    """.utf8)
}

private func entry(_ id: String, light: Double = 0.3, dark: Double = 0.1) -> String {
    "{\"id\": \"\(id)\", \"sceneID\": \"\(id)\", \"opacity\": {\"light\": \(light), \"dark\": \(dark)}, \"extra\": true}"
}

private final class BackdropTestStorage: ProgressStorage {
    var raw: Data?
    var saved: ProgressState?
    func load() -> ProgressState? {
        if let saved { return saved }
        return raw.flatMap { try? JSONDecoder().decode(ProgressState.self, from: $0) }
    }
    func save(_ state: ProgressState) { saved = state }
}

@Suite("홈 바탕 데이터")
struct BackdropCatalogTests {
    @Test func readsEntriesSkipsZeroOpacityAndMissingAssets() throws {
        let raw = data([entry("a"), entry("b", light: 0, dark: 0), entry("c"), entry("a")].joined(separator: ","))
        let catalog = try #require(BackdropCatalog(data: raw, hasAsset: { !$0.hasSuffix("-c") }))
        // 0인 항목(그림 없음)과 에셋 없는 항목은 칸을 만들지 않는다. 같은 id는 처음 것만.
        #expect(catalog.backdrops.map(\.id) == ["a"])
        #expect(catalog.unlock == .sceneComplete)
        #expect(catalog.layout.haloWidth == 2)
        #expect(catalog.limits.lightOpacity == 0.2...0.4)
        #expect(catalog.backdrop(id: "a")?.opacity(.light) == 0.3)
        #expect(catalog.backdrop(id: "a")?.opacity(.dark) == 0.1)
    }

    @Test func otherSchemaVersionIsRejected() {
        #expect(BackdropCatalog(data: data(entry("a"), version: 2), hasAsset: { _ in true }) == nil)
        #expect(BackdropCatalog(data: Data("nope".utf8), hasAsset: { _ in true }) == nil)
    }

    @Test func unlockValueSwitchesRule() throws {
        let all = try #require(BackdropCatalog(data: data(entry("a"), unlock: "all"), hasAsset: { _ in true }))
        #expect(all.unlock == .all)
        let unknown = try #require(BackdropCatalog(data: data(entry("a"), unlock: "someday"), hasAsset: { _ in true }))
        #expect(unknown.unlock == .sceneComplete)
    }

    /// 번들 파일: 장면 순서 그대로 8칸, 그림이 있는 항목의 불투명도는 limits 안이고 에셋이 있다.
    @Test func bundledFileFollowsSceneOrderAndLimits() throws {
        let url = try #require(appBundle.url(forResource: "backdrops", withExtension: "json"))
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let list = try #require(root["backdrops"] as? [[String: Any]])
        #expect(list.compactMap { $0["id"] as? String } == ContentLibrary.shared.scenes.map(\.id))
        #expect(list.compactMap { $0["sceneID"] as? String } == ContentLibrary.shared.scenes.map(\.id))
        let catalog = BackdropCatalog.bundled(bundle: appBundle)
        for backdrop in catalog.backdrops {
            #expect(catalog.limits.lightOpacity.contains(backdrop.opacityLight), "\(backdrop.id)")
            #expect(catalog.limits.darkOpacity.contains(backdrop.opacityDark), "\(backdrop.id)")
            #expect(UIImage(named: backdrop.stripAssetName, in: appBundle, compatibleWith: nil) != nil)
            #expect(UIImage(named: backdrop.thumbAssetName, in: appBundle, compatibleWith: nil) != nil)
        }
    }
}

@Suite("홈 바탕 열림과 저장")
struct BackdropRulesTests {
    let catalog = BackdropCatalog(unlock: .sceneComplete, layout: BackdropLayout(), limits: BackdropLimits(), backdrops: [
        Backdrop(id: "sushi", sceneID: "sushi", opacityLight: 0.3, opacityDark: 0.1),
        Backdrop(id: "tonkatsu", sceneID: "tonkatsu", opacityLight: 0.3, opacityDark: 0.1),
    ])

    @Test func sceneCompletionUnlocksThatSceneOnly() throws {
        var rewards = RewardState()
        let sushi = try #require(catalog.backdrop(id: "sushi")), tonkatsu = try #require(catalog.backdrop(id: "tonkatsu"))
        #expect(!catalog.isUnlocked(sushi, rewards: rewards))
        rewards.paid = ["sushi-a", "sushi-b", "sushi-quiz", RewardRules.sceneUnlockKey("sushi")]
        #expect(catalog.isUnlocked(sushi, rewards: rewards))
        #expect(!catalog.isUnlocked(tonkatsu, rewards: rewards))
        // C2 알림: 장면 완료로 열리는 규칙에서만.
        #expect(catalog.newlyUnlocked(bySceneCompletion: "sushi") == sushi)
        #expect(catalog.newlyUnlocked(bySceneCompletion: "station") == nil)
    }

    /// D1 나("모두 열림")는 backdrops.json의 값 하나로 바뀐다. 그때 C2는 알릴 것이 없다.
    @Test func unlockAllOpensEverything() throws {
        let all = BackdropCatalog(unlock: .all, layout: catalog.layout, limits: catalog.limits, backdrops: catalog.backdrops)
        let tonkatsu = try #require(all.backdrop(id: "tonkatsu"))
        #expect(all.isUnlocked(tonkatsu, rewards: RewardState()))
        #expect(all.newlyUnlocked(bySceneCompletion: "tonkatsu") == nil)
    }

    /// 열리지 않았거나 목록에 없는 저장 값은 없음으로 그리되 지우지 않는다 (6.2).
    @Test func lockedOrUnknownValueDrawsNothingButIsKept() {
        var rewards = RewardState()
        rewards.backdrop = "tonkatsu"
        #expect(catalog.current(for: rewards) == nil)
        rewards.paid = [RewardRules.sceneUnlockKey("tonkatsu")]
        #expect(catalog.current(for: rewards)?.id == "tonkatsu")
        rewards.backdrop = "ghost"
        #expect(catalog.current(for: rewards) == nil)
        #expect(rewards.backdrop == "ghost")
    }

    /// 저장: 키가 없던 옛 파일도 읽고(없음), 쓴 값은 다시 읽어도 남는다. 기본 차림으로는 건드리지 않는다.
    @Test func backdropIsSavedAndSurvivesResetOutfit() throws {
        let storage = BackdropTestStorage()
        storage.raw = Data("""
        {"version": \(ProgressState.currentVersion), "sessions": {},
         "rewards": {"version": 2, "coins": 0, "paid": ["scene/sushi"], "owned": ["tamago"],
                     "equipped": {"top": "tamago", "rice": "plain_rice"}}}
        """.utf8)
        let store = ProgressStore(storage: storage)
        #expect(store.rewards.backdrop == nil)
        store.setBackdrop("sushi")
        #expect(storage.saved?.rewards.backdrop == "sushi")
        store.resetOutfit()
        #expect(store.rewards.backdrop == "sushi")
        #expect(store.rewards.equippedID(.top) == "chef_hat")
        #expect(store.rewards.isDefaultOutfit)
        let json = String(decoding: try JSONEncoder().encode(try #require(storage.saved)), as: UTF8.self)
        #expect(json.contains("\"backdrop\":\"sushi\""))
        let reloaded = ProgressStore(storage: storage)
        #expect(reloaded.rewards.backdrop == "sushi")
        reloaded.setBackdrop(nil)
        #expect(storage.saved?.rewards.backdrop == nil)
        #expect(!String(decoding: try JSONEncoder().encode(try #require(storage.saved)), as: UTF8.self).contains("backdrop"))
    }

    /// 지금 풍경: 저장 값과 열림을 함께 보고, 디버그 값은 열림과 상관없이 앞선다.
    @Test func skinStoreBackdropFollowsSavedValue() {
        let storage = BackdropTestStorage()
        storage.raw = Data("""
        {"version": \(ProgressState.currentVersion), "sessions": {},
         "rewards": {"version": 2, "paid": ["scene/sushi"], "backdrop": "sushi"}}
        """.utf8)
        let skins = SkinStore(catalog: .shared, backdrops: catalog)
        #expect(skins.backdrop == nil)
        skins.progress = ProgressStore(storage: storage)
        #expect(skins.backdrop?.id == "sushi")
        skins.progress?.setBackdrop("tonkatsu")
        #expect(skins.backdrop == nil)
        skins.debugBackdropID = "tonkatsu"
        #expect(skins.backdrop?.id == "tonkatsu")
    }
}

// MARK: - 합성 휘도 (2.3, 6.4 V1·V2)

/// 에셋 PNG(@3x)의 픽셀을 (r, g, b, a) 0~1, 알파를 뺀 값으로 센다. 같은 색은 개수로 묶는다.
private func artPixels(_ name: String) throws -> [(rgb: SkinRGB, alpha: Double, count: Int)] {
    let traits = UITraitCollection(displayScale: 3)
    let image = try #require(UIImage(named: name, in: appBundle, compatibleWith: traits)?.cgImage)
    let w = image.width, h = image.height
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = try #require(CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var counts: [UInt32: Int] = [:]
    for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] > 0 {
        let key = UInt32(bytes[i]) << 24 | UInt32(bytes[i + 1]) << 16 | UInt32(bytes[i + 2]) << 8 | UInt32(bytes[i + 3])
        counts[key, default: 0] += 1
    }
    return counts.map { key, n in
        let a = Double(key & 0xFF) / 255
        func un(_ shift: UInt32) -> Double { min(1, Double((key >> shift) & 0xFF) / 255 / a) }
        return (SkinRGB(red: un(24), green: un(16), blue: un(8)), a, n)
    }
}

private func percentile(_ values: [(Double, Int)], _ q: Double) -> Double {
    let sorted = values.sorted { $0.0 < $1.0 }
    let total = sorted.reduce(0) { $0 + $1.1 }
    let rank = max(1, Int((q / 100 * Double(total)).rounded(.up)))
    var acc = 0
    for (v, n) in sorted {
        acc += n
        if acc >= rank { return v }
    }
    return sorted.last?.0 ?? 0
}

@Suite("홈 바탕 합성")
struct BackdropBlendTests {
    @Test func formulasMatchDesign() {
        let base = SkinRGB(red: 0.9, green: 0.8, blue: 0.7)
        let art = SkinRGB(red: 0.2, green: 0.5, blue: 1)
        // 알파 0, 흰 그림(곱하기), 검은 그림(스크린)은 바탕을 바꾸지 않는다.
        #expect(BackdropBlend.multiply(base, art, alpha: 0, opacity: 0.4) == base)
        #expect(BackdropBlend.multiply(base, SkinRGB(red: 1, green: 1, blue: 1), alpha: 1, opacity: 0.4) == base)
        #expect(BackdropBlend.screen(base, SkinRGB(red: 0, green: 0, blue: 0), alpha: 1, opacity: 0.4) == base)
        let m = BackdropBlend.multiply(base, art, alpha: 1, opacity: 0.5)
        #expect(abs(m.red - 0.9 * (1 - 0.5 * 0.8)) < 1e-9)
        let s = BackdropBlend.screen(base, art, alpha: 0.5, opacity: 0.2)
        #expect(abs(s.blue - (0.7 + 0.1 * 1 * 0.3)) < 1e-9)
    }

    /// 풍경 × 5색 × {라이트, 다크}: 라이트 0.1백분위 ≥ 0.55, 다크 99.9백분위 ≤ 0.06 (2.3).
    /// PNG를 다시 읽으며 생기는 반올림만큼(휘도 0.003) 너그럽다.
    @Test func everyBackdropMeetsLuminanceLimitsOnEveryColor() throws {
        let backdrops = BackdropCatalog.bundled(bundle: appBundle)
        let skins = SkinCatalog.bundled(bundle: appBundle)
        let limits = backdrops.limits
        #expect(skins.skins.count == 5)
        for backdrop in backdrops.backdrops {
            let pixels = try artPixels(backdrop.stripAssetName)
            #expect(!pixels.isEmpty)
            for skin in skins.skins {
                for mode in SkinMode.allCases {
                    let base = skin.rgb(.appBackground, mode: mode)
                    let lums = pixels.map { p in
                        (BackdropBlend.compose(mode, base, p.rgb, alpha: p.alpha, opacity: backdrop.opacity(mode)).luminance, p.count)
                    }
                    if mode == .light {
                        let low = percentile(lums, limits.lightPercentile)
                        #expect(low >= limits.lightMinLuminance - 0.003, "\(backdrop.id) \(skin.id) light \(low)")
                    } else {
                        let high = percentile(lums, limits.darkPercentile)
                        #expect(high <= limits.darkMaxLuminance + 0.003, "\(backdrop.id) \(skin.id) dark \(high)")
                    }
                }
            }
        }
    }
}
