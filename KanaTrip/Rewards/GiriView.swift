import SwiftUI
import UIKit

// 기리 그리기와 아이템 그림 (docs/design/reward-flow.md 7번, 8번).
// 기리는 360 좌표계(viewBox -30 0 360 360) 레이어 에셋을 겹쳐 그린다.
// 아이템 그림 에셋(`Item-{id}`, `Item-{id}-{표정}`, `ItemThumb-{id}`)이 있으면 그것을 쓰고,
// 아직 없는 아이템(히라가나 16개 모두, PLAN.md 8번)은 SF Symbol 임시 표시로 그린다.
// 그림 에셋을 넣으면 코드를 고치지 않아도 임시 표시가 그림으로 바뀐다.

enum GiriFace {
    /// 기본 표정. 홈의 기리 행, 꾸미기 화면.
    case normal
    /// 웃는 표정. 세션·장면 완료.
    case happy

    var assetSuffix: String {
        switch self {
        case .normal: "Default"
        case .happy: "Happy"
        }
    }

    /// 손 아이템 파일 이름의 표정 부분 (`Item-{id}-default`).
    var fileKey: String {
        switch self {
        case .normal: "default"
        case .happy: "happy"
        }
    }
}

enum RewardArt {
    /// 아이템 그림이 아직 없을 때 쓰는 임시 SF Symbol. 그림 에셋이 들어오면 쓰지 않는다.
    static let placeholderSymbols: [String: String] = [
        "chef_hat": "hat.widebrim.fill",
        "red_scarf": "line.diagonal",
        "noren": "storefront.fill",
        "sushi": "fish.fill",
        "eki": "tram.fill",
        "kippu": "ticket.fill",
        "machi": "building.2.fill",
        "kasa": "umbrella.fill",
        "torii": "building.columns.fill",
        "omamori": "seal.fill",
        "omen": "theatermasks.fill",
        "tasuki": "line.diagonal",
        "hachimaki": "wind",
        "maekake": "rectangle.portrait.fill",
        "yu": "drop.fill",
        "tenugui": "rectangle.stack.fill",
        "furoshiki": "gift.fill",
        "youkan": "cup.and.saucer.fill",
    ]

    static func placeholderSymbol(_ id: String) -> String {
        placeholderSymbols[id] ?? "questionmark.square.dashed"
    }

    /// 기리 위에 겹치는 레이어 에셋 이름. 손 아이템은 표정마다 옮겨 놓은 파일이 따로 있다 (8.1).
    static func layerAsset(_ id: String, slot: RewardSlot, face: GiriFace) -> String {
        slot == .hand ? "Item-\(id)-\(face.fileKey)" : "Item-\(id)"
    }

    static func thumbnailAsset(_ id: String) -> String { "ItemThumb-\(id)" }

    static func hasAsset(_ name: String) -> Bool {
        UIImage(named: name) != nil
    }

    /// 임시 표시를 놓는 자리 (360 좌표계, reward-flow.md 8.2).
    static func placeholderAnchor(_ slot: RewardSlot, face: GiriFace) -> CGPoint {
        switch slot {
        case .hat: CGPoint(x: 150, y: 74)
        case .scarf: CGPoint(x: 150, y: 244)
        case .hand: face == .normal ? CGPoint(x: 278, y: 262) : CGPoint(x: 290, y: 142)
        case .background: CGPoint(x: 15, y: 60)
        }
    }
}

/// 입은 아이템을 겹친 기리. H(64pt), C1·C2(120pt), K 미리보기(200~260pt)가 함께 쓴다.
/// 장식이라 VoiceOver에서 읽지 않는다. 꾸미기 화면은 바깥에서 따로 레이블을 붙인다.
struct GiriView: View {
    let face: GiriFace
    /// 슬롯(RewardSlot.rawValue) → 아이템 id.
    let outfit: [String: String]
    let side: CGFloat
    /// 배경 슬롯은 꾸미기 화면에서만 그린다 (reward-flow.md 7번).
    var showsBackground = false

    var body: some View {
        let hand = outfit[RewardSlot.hand.rawValue]
        ZStack {
            if showsBackground, let id = outfit[RewardSlot.background.rawValue] {
                item(id, slot: .background)
            }
            layer("GiriBase\(face.assetSuffix)")
            if let id = outfit[RewardSlot.scarf.rawValue] { item(id, slot: .scarf) }
            if let id = outfit[RewardSlot.hat.rawValue] { item(id, slot: .hat) }
            layer("GiriFace\(face.assetSuffix)")
            if face == .happy {
                // 손 아이템이 있으면 반짝임을 왼쪽으로 뒤집어 그린다 (reward-flow.md 7번).
                layer(hand == nil ? "GiriSparkles" : "GiriSparklesLeft")
            }
            if let hand { item(hand, slot: .hand) }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    private func layer(_ name: String) -> some View {
        Image(name).resizable().frame(width: side, height: side)
    }

    @ViewBuilder
    private func item(_ id: String, slot: RewardSlot) -> some View {
        let asset = RewardArt.layerAsset(id, slot: slot, face: face)
        if RewardArt.hasAsset(asset) {
            layer(asset)
        } else if slot == .background {
            placeholderBackground(id)
        } else {
            placeholderMark(id, slot: slot)
        }
    }

    // MARK: - 임시 표시

    /// 360 좌표계의 점을 이 뷰의 점으로 옮긴다.
    private func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x + 30) / 360 * side, y: p.y / 360 * side)
    }

    private func placeholderMark(_ id: String, slot: RewardSlot) -> some View {
        let d = side * 0.24
        return Image(systemName: RewardArt.placeholderSymbol(id))
            .resizable()
            .scaledToFit()
            .padding(d * 0.2)
            .frame(width: d, height: d)
            .foregroundStyle(Color.ink)
            .background(Color.highlight, in: Circle())
            .overlay(Circle().strokeBorder(Color.ink, lineWidth: max(1, side / 120)))
            .position(point(RewardArt.placeholderAnchor(slot, face: face)))
            .frame(width: side, height: side)
    }

    private func placeholderBackground(_ id: String) -> some View {
        let d = side * 0.2
        return ZStack {
            Color.highlight.opacity(0.35)
            Image(systemName: RewardArt.placeholderSymbol(id))
                .resizable()
                .scaledToFit()
                .frame(width: d, height: d)
                .foregroundStyle(Color.inkSecondary)
                .position(point(RewardArt.placeholderAnchor(.background, face: face)))
        }
        .frame(width: side, height: side)
    }
}

/// 아이템 썸네일. 아이템만 그리고 기리는 넣지 않는다 (reward-system.md 5.2).
/// 잠긴 아이템은 같은 그림의 실루엣으로 그린다 (reward-flow.md 8.4).
struct ItemThumbnail: View {
    let item: RewardItem
    let size: CGFloat
    var silhouette = false

    var body: some View {
        let asset = RewardArt.thumbnailAsset(item.id)
        Group {
            if RewardArt.hasAsset(asset) {
                if silhouette {
                    Image(asset).resizable().renderingMode(.template)
                        .foregroundStyle(Color.inkSecondary.opacity(0.3))
                } else {
                    Image(asset).resizable()
                }
            } else {
                Image(systemName: RewardArt.placeholderSymbol(item.id))
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
                    .foregroundStyle(silhouette ? Color.inkSecondary.opacity(0.3) : Color.ink)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 아이템의 가나 이름과, 배우지 않은 글자·탁음·작은 글자 위의 발음 표기 (reward-flow.md 3.5).
/// 기본 차림 아이템은 가나 이름이 없어 한국어 이름을 쓴다.
struct ItemNameRuby: View {
    let item: RewardItem
    /// 배운 글자. 지금까지 끝낸 장면들의 글자.
    let learned: Set<String>
    var kanaSize: CGFloat = 15

    var body: some View {
        if item.units.isEmpty {
            VStack(spacing: 0) {
                Color.clear.frame(height: 12)
                Text(item.nameKo)
                    .font(.system(size: kanaSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: 20)
            }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(item.units.enumerated()), id: \.offset) { _, unit in
                    VStack(spacing: 0) {
                        Text(learned.contains(unit.kana) ? " " : unit.romaji)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.inkSecondary)
                            .frame(height: 12)
                            .fixedSize()
                        KanaText(text: unit.kana, size: kanaSize)
                            .frame(height: 20)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }
}

/// C1·C2의 받은 엔 줄 (reward-flow.md 5번). 넘치면 "가진 엔"을 다음 줄로 내린다.
struct CoinsReceivedLine: View {
    let received: Int
    let balance: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                received_
                Text("· \(L.coinsBalance(balance))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.inkSecondary)
            }
            VStack(spacing: 2) {
                received_
                Text(L.coinsBalance(balance))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.coinsLineLabel(received: received, balance: balance))
    }

    private var received_: some View {
        HStack(spacing: 4) {
            Image(systemName: "yensign.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.highlightStrong)
            Text(L.coinsReceived(received))
                .font(.headline)
                .foregroundStyle(Color.ink)
        }
        .fixedSize()
    }
}
