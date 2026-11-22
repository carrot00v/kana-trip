import SwiftUI
import UIKit

// 기리 그리기와 아이템 그림 (docs/design/reward-flow.md 7번, 8번, docs/design/giri-companion.md 4.4, 5번).
// 기리는 Lottie 파일 `giri.lottie.json` 하나다(2026-11-21). 표정·밥·반짝임은 부위 레이어를 켜고 끄거나 색을 바꾸고,
// 머리·속재료 아이템(`Item-{id}`)은 이미지 슬롯에 꽂는다 (GiriLottie.swift).
// 겹치는 순서(아래 → 위): 배경 → 속재료(뒤) → 본체(밥, 볼, 빨간 두건) → 속재료(앞) → 머리 → 얼굴 → 반짝임 (8.1).
// 아이템 그림 에셋이 없는 아이템(로컬 이미지 모델 작업이 보류된 아이템, docs/schedule.md)은 가나 이름 첫 칸을 넣은
// 노랑 동그라미로 임시 표시한다. 그림 에셋을 넣으면 코드를 고치지 않아도 임시 표시가 그림으로 바뀐다.

/// 기리의 표정과 팔 자세 (docs/design/giri-companion.md 4.1). 얼굴 레이어 5개 가운데 하나와 오른팔(내림, 듦).
enum GiriPose: Hashable {
    /// 기본. 말없이 있을 때, 꾸미기 화면.
    case normal
    /// 웃음 (오른팔 듦, 반짝임). 정답, 글자 완성, 완료 화면.
    case happy
    /// 말하기. 말풍선으로 알려 주거나 권할 때.
    case talk
    /// 손 들기 (말하기 얼굴 + 오른팔 듦). 위의 글자·단어를 두고 설명할 때.
    case point
    /// 생각. 같이 읽는 중, 답을 기다릴 때.
    case think
    /// 아쉬움 ("앗차"). 퀴즈 오답.
    case sorry

    /// Lottie 얼굴 레이어 이름의 끝 (`face_{…}`, 4.4.1).
    var faceLayer: String {
        switch self {
        case .normal: "default"
        case .happy: "happy"
        case .talk, .point: "talk"
        case .think: "think"
        case .sorry: "sorry"
        }
    }

    /// 오른팔을 든 자세인지. 마커 접미사 `_down`/`_up`을 고른다 (5.9.3).
    var armRaised: Bool { self == .happy || self == .point }

    var hasSparkles: Bool { self == .happy }
}

enum RewardArt {
    /// 기리 위에 겹치는 머리·속재료·배경 그림. 표정과 상관없이 한 장이다.
    static func layerAsset(_ id: String) -> String { "Item-\(id)" }

    static func thumbnailAsset(_ id: String) -> String { "ItemThumb-\(id)" }

    static func hasAsset(_ name: String) -> Bool {
        UIImage(named: name) != nil
    }

    /// 임시 표시를 놓는 자리 (360 좌표계, reward-flow.md 8.2): 머리는 기준점 P (150, 110) 위, 속재료는 왼쪽 옆구리 E (54, 189) 바깥.
    static func placeholderAnchor(_ slot: RewardSlot) -> CGPoint {
        switch slot {
        case .top: CGPoint(x: 150, y: 80)
        case .filling: CGPoint(x: 30, y: 178)
        case .rice, .background: CGPoint(x: 15, y: 60)
        }
    }

    /// 임시 표시 동그라미의 지름 (기리 크기에 대한 비율).
    static func placeholderScale(_ slot: RewardSlot) -> CGFloat {
        slot == .filling ? 0.16 : 0.22
    }
}

/// 그림이 아직 없는 아이템의 임시 표시: 가나 이름 첫 칸을 넣은 노랑 동그라미.
/// 잠긴 칸의 실루엣이면 이름을 숨기고 옅은 동그라미만 그린다 (reward-flow.md 3.5).
struct ItemPlaceholderMark: View {
    let label: String
    let diameter: CGFloat
    var silhouette = false

    var body: some View {
        ZStack {
            Circle().fill(silhouette ? Color.inkSecondary.opacity(0.3) : Color.highlight)
            if !silhouette {
                Circle().strokeBorder(Color.ink, lineWidth: max(1, diameter / 24))
                KanaText(text: label, size: diameter * 0.5, weight: .semibold)
                    .foregroundStyle(Color.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(diameter * 0.12)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    static func label(for item: RewardItem?) -> String {
        item?.placeholderLabel ?? "?"
    }
}

/// 입은 아이템을 단 기리. 말풍선 줄(80·96·120pt), 지도(96pt), C1·C2(120pt), K 미리보기(200~260pt)가 함께 쓴다.
/// 장식이라 VoiceOver에서 읽지 않는다. 꾸미기 화면은 바깥에서 따로 레이블을 붙인다.
///
/// 자리는 지금처럼 G × G이고, Lottie 뷰는 가로 7/6 G, 세로 6/5 G로 아래 끝·가로 가운데를 맞춰 겹친다(배치에 영향 없음).
/// 깡충·머리 아이템이 위로 넘쳐 그린다 (giri-companion.md 5.6).
/// 움직임 (5.2, 5.8): 표정이 바뀌면 마커를 고른다(내림 → 웃음 `hop`, 내림 → 손 들기 `raise`, 듦 → 내림은 0.2초 뒤 `lower`,
/// 팔이 그대로면 `react_*`). 차림이 바뀌면 `dress`. 동작 줄이기면 정지 마커에 멈추고 모습만 바로 바뀐다.
struct GiriView: View {
    let pose: GiriPose
    let outfit: GiriOutfit
    let side: CGFloat
    /// 배경 슬롯은 꾸미기 화면에서만 그린다 (reward-flow.md 7번).
    var showsBackground = false
    /// 숨쉬기 반복(`idle_*`). 쓰기 화면, 단어 읽기, 움직이는 장면 그림이 있는 화면, K, C1·C2에서는 끈다 (5.2, 5.3).
    var breathes = false
    /// 처음 나타날 때 `appear`로 나온다 (C1, C2, 5.2.7). 불투명도는 바깥에서 건다.
    var entrance = false
    /// 바깥에서 거는 한 번 움직임 (지도의 칸 이동 깡충·착지).
    var motion: GiriMotionRequest? = nil
    /// 반복을 잠시 멈춘다 (말풍선 뜨기 동안).
    var holdsIdle = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if showsBackground, let id = outfit.background {
                background(id)
                    .id("background-\(id)")
                    .transition(.opacity)
            }
        }
        .frame(width: side, height: side)
        .overlay(alignment: .bottom) {
            GiriLottieView(playback: GiriPlayback(look: GiriLook(pose: pose, outfit: outfit), loops: breathes,
                                                  entrance: entrance, request: motion, reduceMotion: reduceMotion,
                                                  holdsIdle: holdsIdle))
                .frame(width: side * 7 / 6, height: side * 6 / 5)
                .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    // MARK: - 배경 (K에서만)

    @ViewBuilder
    private func background(_ id: String) -> some View {
        let asset = RewardArt.layerAsset(id)
        if RewardArt.hasAsset(asset) {
            Image(asset).resizable().frame(width: side, height: side)
        } else {
            placeholderBackground(id)
        }
    }

    /// 360 좌표계의 점을 이 뷰의 점으로 옮긴다.
    private func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x + 30) / 360 * side, y: p.y / 360 * side)
    }

    private func placeholderBackground(_ id: String) -> some View {
        ZStack {
            Color.highlight.opacity(0.35)
            ItemPlaceholderMark(label: outfit.labels[id] ?? "?",
                                diameter: side * 0.2)
                .position(point(RewardArt.placeholderAnchor(.background)))
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
                ItemPlaceholderMark(label: ItemPlaceholderMark.label(for: item), diameter: size * 0.7,
                                    silhouette: silhouette)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 아이템의 가나 이름과, 배우지 않은 글자·탁음·작은 글자·한자 위의 발음 표기 (reward-flow.md 3.5).
/// 요음(しゃ)은 한 칸이고 앞 글자를 배웠으면 표기하지 않는다 (PLAN.md 8번 임시 규칙, `RewardItem.Unit.isReadable`).
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
                        Text(unit.isReadable(learned: learned) ? " " : unit.romaji)
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
