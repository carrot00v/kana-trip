import SwiftUI

/// 칸 하나를 그릴 때 필요한 것. 상태와 문구는 지도 화면이 진도에서 계산해 넘긴다.
struct MapNodeInfo {
    var state: MapNodeState = .locked
    /// 단계 칸의 글자.
    var kana: [String] = []
    /// 종합 퀴즈 칸의 복습 글자 수(VoiceOver에만 쓴다. 지도에는 적지 않는다, 1.2).
    var review = 0
    var accessibilityLabel = AttributedString()
}

struct MapBandInfo {
    var state: MapBandState = .locked
    var order = 0
    var name = ""
    /// 장면의 새 글자 전부.
    var kana: [String] = []
    var icon: String?
    var accessibilityLabel = ""
}

/// 지도 구간 하나 (docs/design/home-map.md "2026-11-21 재구성안" 안 A, R2.3).
/// 그리는 순서: 점선 → 세션 칸(캡슐) → 장면 띠 → 스티커 → 출발·끝 표지.
/// 기리·말풍선은 구간을 넘어 뛰므로 지도 위 덮개 층(MapGiriLayer)이 그린다.
struct MapSectionView: View {
    let section: MapSection
    let width: CGFloat
    let metrics: MapMetrics
    let node: (MapNode) -> MapNodeInfo
    let band: (MapNode) -> MapBandInfo
    let showsStickers: Bool
    let onTapNode: (MapNode) -> Void
    let onTapBand: (MapNode) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * width, y: section.height - y)
    }

    private var sessionNodes: [MapNode] { section.nodes.filter(\.isSession) }
    private var bandNodes: [MapNode] { section.nodes.filter { $0.kind == .band } }
    private var markerNodes: [MapNode] { section.nodes.filter { $0.kind == .start || $0.kind == .gate } }
    private var nodeWidth: CGFloat { metrics.nodeWidth(in: width) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            dots
            ForEach(sessionNodes) { node in capsule(node, info: self.node(node)) }
            ForEach(bandNodes) { node in bandRow(node, info: band(node)) }
            if showsStickers { stickers }
            ForEach(markerNodes) { node in markerName(node) }
        }
        .frame(width: width, height: section.height, alignment: .topLeading)
    }

    // MARK: 점선 (R2.3): 지름 4pt 점, 점 가운데 사이 12pt, `PathEdge`. 지난 길·앞길을 나누지 않는다.

    @Environment(\.mapHalo) private var halo

    private var dots: some View {
        ZStack(alignment: .topLeading) {
            // 점 테: 점 밑에 지름 8 바탕색 원 (home-backdrop.md 2.4). 풍경을 쓰는 동안에만.
            if halo { dotPath(diameter: SkinStore.shared.backdrops.layout.dotHaloDiameter).fill(MapPalette.ground) }
            dotPath(diameter: metrics.dot).fill(MapPalette.ahead)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func dotPath(diameter: CGFloat) -> Path {
        Path { p in
            for path in section.paths {
                let pts = path.points
                guard pts.count == 2 else { continue }
                for c in Self.dotCenters(from: point(pts[0].x, pts[0].y), to: point(pts[1].x, pts[1].y),
                                         spacing: metrics.dotSpacing) {
                    p.addEllipse(in: CGRect(x: c.x - diameter / 2, y: c.y - diameter / 2, width: diameter, height: diameter))
                }
            }
        }
    }

    /// 조각 안에 spacing 간격으로 놓고 남는 길이를 양끝에 반씩 둔다. 조각이 spacing보다 짧으면 가운데 한 점.
    static func dotCenters(from a: CGPoint, to b: CGPoint, spacing: CGFloat) -> [CGPoint] {
        let length = hypot(b.x - a.x, b.y - a.y)
        guard length > 0 else { return [a] }
        let count = Int((length / spacing).rounded(.down)) + 1
        let used = CGFloat(count - 1) * spacing
        let start = (length - used) / 2
        return (0..<count).map { i in
            let t = (start + CGFloat(i) * spacing) / length
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }

    // MARK: 세션 칸 (R2.3)

    private func capsule(_ node: MapNode, info: MapNodeInfo) -> some View {
        Button {
            onTapNode(node)
        } label: {
            MapNodeCapsule(state: info.state, kana: info.kana, isQuiz: node.kind == .quiz,
                           width: nodeWidth, height: metrics.nodeHeight, ring: metrics.nodeRing)
                .contentShape(Capsule())
        }
        .buttonStyle(MapPressStyle())
        .position(point(node.x, node.y))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: info.state)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(info.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: 장면 띠 (R2.3)

    private func bandRow(_ node: MapNode, info: MapBandInfo) -> some View {
        let inner = width - metrics.bandInset * 2
        // 글자는 그림 오른쪽 12pt부터, 스티커 두 칸(+ 간격) 앞까지.
        let stickerArea = metrics.sticker * 2 + metrics.stickerGap + MapShape.bandStickerClear
        let textWidth = max(0, inner - metrics.bandArt - MapShape.bandTextGap - stickerArea)
        return Button {
            onTapBand(node)
        } label: {
            HStack(spacing: MapShape.bandTextGap) {
                MapBandArt(sceneID: node.scene ?? node.id, icon: info.icon, state: info.state, side: metrics.bandArt)
                MapBandText(info: info)
                    .mapHalo()
                    .frame(width: textWidth, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(width: inner, height: metrics.band, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(MapPressStyle())
        .allowsHitTesting(info.state != .locked)
        .position(point(node.x, node.y))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: info.state)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(info.accessibilityLabel)
        .accessibilityAddTraits(info.state == .locked ? [] : .isButton)
    }

    /// 출발·끝 표지: 글자만 (R2.3).
    private func markerName(_ node: MapNode) -> some View {
        let isStart = node.kind == .start
        let text = isStart ? L.regionStart(ContentLibrary.shared.sectionTitle) : L.katakanaComingSoon
        return Text(text)
            .font(.footnote.weight(.bold))
            .foregroundStyle(MapPalette.quietInk)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .lineLimit(1)
            .fixedSize()
            .mapHalo()
            .position(point(node.x, node.y))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isStart ? L.regionStartLabel(ContentLibrary.shared.sectionTitle) : L.katakanaComingSoonLabel)
    }

    // MARK: 스티커 (R2.3): 띠 오른쪽 끝의 정해진 두 칸

    private var stickers: some View {
        ForEach(section.stickers, id: \.slot) { sticker in
            let name = "map_sticker_\(sticker.art)"
            // 에셋이 없으면 그 자리를 그리지 않는다. 대체 그림을 두지 않는다.
            if UIImage(named: name) != nil {
                let p = point(sticker.x, sticker.y)
                Image(name)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: metrics.sticker, height: metrics.sticker)
                    .rotationEffect(.degrees(sticker.rotate))
                    .position(x: p.x + sticker.dx, y: p.y)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .accessibilityIgnoresInvertColors(true)
                    .transition(reduceMotion ? .identity : .scale(scale: 0.85).combined(with: .opacity))
            }
        }
    }
}

/// 누르는 동안 살짝 흐리게. 기본 버튼 모양(배경, 강조색 글자)을 쓰지 않는다.
struct MapPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// 세션 칸 캡슐 (R2.3). 지금: 노랑 채움 + 굵은 가나, 아이콘 없음. 완료: 카드 바탕 + 보조 색 테 + 체크.
/// 잠김: 바탕색 + `PathEdge` 테 + 자물쇠, 글자 보조 색.
struct MapNodeCapsule: View {
    let state: MapNodeState
    let kana: [String]
    let isQuiz: Bool
    let width: CGFloat
    let height: CGFloat
    let ring: CGFloat

    @Environment(\.mapHalo) private var halo

    var body: some View {
        HStack(spacing: MapShape.nodeIconGap) {
            if let icon {
                Image(systemName: icon.name)
                    .font(.system(size: MapShape.nodeIcon, weight: .semibold))
                    .foregroundStyle(icon.color)
            }
            label
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, MapShape.nodePadding)
        .frame(width: width, height: height)
        .background { background }
        .transition(.opacity)
        .id(state)
    }

    private var icon: (name: String, color: Color)? {
        switch state {
        case .locked: ("lock.fill", MapPalette.quietInk)
        case .completed: ("checkmark.circle.fill", MapPalette.done)
        case .current: nil
        }
    }

    private var textColor: Color {
        switch state {
        case .locked: MapPalette.quietInk
        case .completed: MapPalette.ink
        case .current: MapPalette.onCurrent
        }
    }

    @ViewBuilder
    private var label: some View {
        if isQuiz {
            Text(L.quizSessionName)
                .font(.headline.weight(state == .current ? .bold : .regular))
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundStyle(textColor)
        } else {
            Text(KanaText.japanese(kana.joined()))
                .font(.system(size: MapShape.nodeKanaSize, weight: state == .current ? .bold : .regular))
                .tracking(MapShape.nodeKanaSpacing)
                .environment(\.locale, Locale(identifier: "ja"))
                .foregroundStyle(textColor)
        }
    }

    @ViewBuilder
    private var background: some View {
        // 칸 테: 사방 2pt 키운 캡슐을 바탕색으로 칸 밑에 (home-backdrop.md 2.4). 풍경을 쓰는 동안에만.
        if halo {
            let w = SkinStore.shared.backdrops.layout.haloWidth
            Capsule().fill(MapPalette.ground).padding(-w)
        }
        switch state {
        case .current:
            Capsule().fill(MapPalette.current)
        case .completed:
            Capsule().fill(MapPalette.card)
            Capsule().strokeBorder(MapPalette.passed, lineWidth: ring)
        case .locked:
            Capsule().fill(MapPalette.ground)
            Capsule().strokeBorder(MapPalette.ahead, lineWidth: ring)
        }
    }
}

/// 장면 띠의 두 줄 글자 (R2.3): "{상태 아이콘} {순서} {장면}" + 그 장면의 새 글자.
struct MapBandText: View {
    let info: MapBandInfo

    var body: some View {
        let icon: (String, Color)? = switch info.state {
        case .locked: ("lock.fill", MapPalette.quietInk)
        case .completed: ("checkmark.circle.fill", MapPalette.done)
        case .open: nil
        }
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: MapShape.nameIconGap) {
                if let icon {
                    Image(systemName: icon.0).foregroundStyle(icon.1)
                }
                Text(L.buildingPill(order: info.order, name: info.name))
                    .fontWeight(info.state == .locked ? .regular : .bold)
                    .foregroundStyle(info.state == .locked ? MapPalette.quietInk : MapPalette.ink)
            }
            .font(.headline)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Text(KanaText.japanese(info.kana.joined()))
                .font(.system(size: MapShape.bandKanaSize))
                .tracking(MapShape.bandKanaSpacing)
                .environment(\.locale, Locale(identifier: "ja"))
                .foregroundStyle(MapPalette.quietInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// 장면 띠 그림 72pt (R2.3). 지금 장면은 `Outline` 2pt, 잠김은 흑백.
/// 그림 `map_building_{id}` → `SceneThumb-{id}` → 장면 아이콘 순으로 찾는다.
struct MapBandArt: View {
    let sceneID: String
    let icon: String?
    let state: MapBandState
    let side: CGFloat

    @Environment(\.mapHalo) private var halo

    private var image: UIImage? {
        UIImage(named: "map_building_\(sceneID)") ?? UIImage(named: "SceneThumb-\(sceneID)")
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MapShape.bandArtCorner, style: .continuous)
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .saturation(state == .locked ? 0 : 1)
            } else {
                ZStack {
                    MapPalette.card
                    Image(systemName: icon ?? "building.2.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(state == .locked ? MapPalette.quietInk : MapPalette.ink)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(MapPalette.outline, lineWidth: MapShape.outlineWidth)
                .opacity(state == .open ? 1 : 0)
        }
        .background {
            // 받침: 그림 밑에 바탕색 둥근 사각(둘레 4pt, 모서리 16) (home-backdrop.md 2.4). 풍경을 쓰는 동안에만.
            if halo {
                let l = SkinStore.shared.backdrops.layout
                RoundedRectangle(cornerRadius: l.artMatCorner, style: .continuous)
                    .fill(MapPalette.ground)
                    .padding(-l.artMatInset)
            }
        }
        .accessibilityIgnoresInvertColors(true)
    }
}
