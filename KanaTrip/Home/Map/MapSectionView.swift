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

struct MapBuildingInfo {
    var state: MapBuildingState = .locked
    var order = 0
    var name = ""
    var icon: String?
    var accessibilityLabel = ""
}

/// 지도 구간 하나 (docs/design/home-map.md 1.3, 2.1~2.5, "2026-11-18 시각 정리" S4·S7).
/// 그리는 순서(2.5): 앞길 선 → 지난 길 선 → 칸 원 → 건물 카드 → 스티커 → 건물 이름(가림 캡슐) → 칸 라벨.
/// 발판·기리·말풍선은 구간을 넘어 뛰므로 지도 위 덮개 층(MapGiriLayer)이 그린다.
struct MapSectionView: View {
    let section: MapSection
    let width: CGFloat
    let metrics: MapMetrics
    let isPassed: (MapPath) -> Bool
    let node: (MapNode) -> MapNodeInfo
    let building: (MapNode) -> MapBuildingInfo
    let showsStickers: Bool
    let onTapNode: (MapNode) -> Void
    let onTapBuilding: (MapNode) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * width, y: section.height - y)
    }

    private var sessionNodes: [MapNode] { section.nodes.filter(\.isSession) }
    private var buildingNodes: [MapNode] { section.nodes.filter { $0.kind == .building } }
    private var markerNodes: [MapNode] { section.nodes.filter { $0.kind == .start || $0.kind == .gate } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            lines
            ForEach(sessionNodes) { node in sessionCircle(node, info: self.node(node)) }
            ForEach(buildingNodes) { node in buildingCard(node, info: building(node)) }
            if showsStickers { stickers }
            ForEach(buildingNodes) { node in buildingName(node, info: building(node)) }
            ForEach(markerNodes) { node in markerName(node) }
            ForEach(sessionNodes) { node in sessionLabel(node, info: self.node(node)) }
        }
        .frame(width: width, height: section.height, alignment: .topLeading)
    }

    // MARK: 길: 선 하나 (2.5)

    private func curve(_ path: MapPath) -> Path {
        var p = Path()
        let pts = path.points.map { point($0.x, $0.y) }
        guard pts.count == 4 else { return p }
        p.move(to: pts[0])
        p.addCurve(to: pts[3], control1: pts[1], control2: pts[2])
        return p
    }

    /// 앞길 4pt `PathEdge`를 먼저, 지난 길 6pt `InkSecondary`를 위에. 조각마다 하나로 칠하고 바뀔 때는 교차 페이드.
    private var lines: some View {
        ZStack {
            ForEach(Array(section.paths.enumerated()), id: \.offset) { _, path in
                curve(path)
                    .stroke(MapPalette.ahead, style: StrokeStyle(lineWidth: metrics.aheadLine, lineCap: .round, lineJoin: .round))
                    .opacity(isPassed(path) ? 0 : 1)
            }
            ForEach(Array(section.paths.enumerated()), id: \.offset) { _, path in
                curve(path)
                    .stroke(MapPalette.passed, style: StrokeStyle(lineWidth: metrics.progressLine, lineCap: .round, lineJoin: .round))
                    .opacity(isPassed(path) ? 1 : 0)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: 칸 (2.1)

    private func diameter(_ node: MapNode) -> CGFloat {
        node.kind == .quiz ? metrics.nodeQuiz : metrics.nodeStep
    }

    /// 원(지금 칸은 원 없이 누르는 영역만). 이 버튼이 VoiceOver 레이블을 가진다. 라벨은 따로 그리고 같은 동작을 건다.
    private func sessionCircle(_ node: MapNode, info: MapNodeInfo) -> some View {
        let d = diameter(node)
        let hit = info.state == .current ? MapShape.currentTapArea : max(d, MapShape.minTapHeight)
        return Button {
            onTapNode(node)
        } label: {
            ZStack {
                MapNodeCircle(state: info.state, diameter: d, isQuiz: node.kind == .quiz, ring: metrics.nodeRing)
            }
            .frame(width: hit, height: hit)
            .contentShape(Rectangle())
        }
        .buttonStyle(MapPressStyle())
        .position(point(node.x, node.y))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(info.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    /// 테두리 없는 라벨: 칸의 지도 가운데 쪽 옆, 칸 가장자리에서 8pt, 세로 가운데 맞춤. 지금 칸은 숨김 (2.1).
    @ViewBuilder
    private func sessionLabel(_ node: MapNode, info: MapNodeInfo) -> some View {
        let d = diameter(node)
        let center = point(node.x, node.y)
        let toRight = node.x < 0.5
        let anchorX = center.x + (toRight ? 1 : -1) * (d / 2 + metrics.labelGap)
        Color.clear
            .frame(width: 0, height: 0)
            .overlay(alignment: toRight ? .leading : .trailing) {
                label(node, info: info)
                    .fixedSize()
                    .frame(minHeight: MapShape.minTapHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapNode(node) }
                    .opacity(info.state == .current ? 0 : 1)
                    .allowsHitTesting(info.state != .current)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: info.state)
            }
            .position(x: anchorX, y: center.y)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func label(_ node: MapNode, info: MapNodeInfo) -> some View {
        if node.kind == .quiz {
            Text(L.quizSessionName)
                .font(.footnote)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(MapPalette.quietInk)
        } else {
            HStack(spacing: MapShape.kanaLabelSpacing) {
                ForEach(Array(info.kana.enumerated()), id: \.offset) { _, char in
                    Text(KanaText.japanese(char))
                        .font(.system(size: MapShape.kanaLabelSize))
                }
            }
            .environment(\.locale, Locale(identifier: "ja"))
            .foregroundStyle(MapPalette.quietInk)
        }
    }

    // MARK: 건물 (2.2)

    private func buildingSide(_ state: MapBuildingState) -> CGFloat {
        state == .open ? metrics.building : metrics.buildingSmall
    }

    private func buildingCard(_ node: MapNode, info: MapBuildingInfo) -> some View {
        let side = buildingSide(info.state)
        return Button {
            onTapBuilding(node)
        } label: {
            MapBuildingCard(sceneID: node.scene ?? node.id, icon: info.icon, state: info.state, side: side)
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

    /// 이름: 카드 아래 변에서 6pt, 가림 캡슐로 x 0.5의 길 선을 끊는다. 앞에 상태 아이콘 (2.2).
    private func buildingName(_ node: MapNode, info: MapBuildingInfo) -> some View {
        let side = buildingSide(info.state)
        let center = point(node.x, node.y)
        let y = center.y + side / 2 + metrics.nameGap + MapShape.nameCapsuleHeight / 2
        let icon: (String, Color)? = switch info.state {
        case .locked: ("lock.fill", MapPalette.quietInk)
        case .completed: ("checkmark.circle.fill", MapPalette.done)
        case .open: nil
        }
        return MapNameTag(text: L.buildingPill(order: info.order, name: info.name), icon: icon,
                          bold: info.state != .locked, quiet: info.state == .locked)
            .contentShape(Rectangle())
            .onTapGesture { if info.state != .locked { onTapBuilding(node) } }
            .position(x: center.x, y: y)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: info.state)
            .accessibilityHidden(true)
    }

    /// 출발·끝 표지: 건물 이름과 같은 모양, 글자 `InkSecondary` (1.1).
    private func markerName(_ node: MapNode) -> some View {
        let isStart = node.kind == .start
        let text = isStart ? L.regionStart(ContentLibrary.shared.sectionTitle) : L.katakanaComingSoon
        return MapNameTag(text: text, icon: nil, bold: true, quiet: true)
            .position(point(node.x, node.y))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isStart ? L.regionStartLabel(ContentLibrary.shared.sectionTitle) : L.katakanaComingSoonLabel)
    }

    // MARK: 스티커 (2.3): 건물 카드 양옆, 카드 위 층

    private var stickers: some View {
        ForEach(section.stickers, id: \.step) { sticker in
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

/// 세션 칸의 원 (2.1). 잠김: 연한 테 + 자물쇠. 완료: 보조 색 테 + 체크. 지금: 그리지 않는다(발판과 기리가 대신한다).
struct MapNodeCircle: View {
    let state: MapNodeState
    let diameter: CGFloat
    let isQuiz: Bool
    let ring: CGFloat

    var body: some View {
        ZStack {
            switch state {
            case .locked:
                Circle().fill(MapPalette.card)
                Circle().strokeBorder(MapPalette.ahead, lineWidth: ring)
                Image(systemName: "lock.fill")
                    .font(.system(size: MapShape.lockSymbol))
                    .foregroundStyle(MapPalette.quietInk)
            case .current:
                Color.clear
            case .completed:
                Circle().fill(MapPalette.card)
                Circle().strokeBorder(MapPalette.passed, lineWidth: ring)
                Image(systemName: "checkmark")
                    .font(.system(size: isQuiz ? MapShape.checkQuiz : MapShape.checkStep, weight: .bold))
                    .foregroundStyle(MapPalette.done)
            }
        }
        .frame(width: diameter, height: diameter)
        .transition(.opacity)
        .id(state)
    }
}

/// 건물 이름·출발·끝 표지: 테두리 없는 `.footnote` 글자 + 바탕색 가림 캡슐 (2.2).
struct MapNameTag: View {
    let text: String
    let icon: (String, Color)?
    let bold: Bool
    let quiet: Bool

    var body: some View {
        HStack(spacing: MapShape.nameIconGap) {
            if let icon {
                Image(systemName: icon.0).foregroundStyle(icon.1)
            }
            Text(text)
                .foregroundStyle(quiet ? MapPalette.quietInk : MapPalette.ink)
        }
        .font(.footnote.weight(bold ? .bold : .regular))
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .lineLimit(1)
        .padding(.horizontal, MapShape.nameCapsulePadding)
        .frame(minHeight: MapShape.nameCapsuleHeight)
        .background(MapPalette.ground, in: Capsule())
        .fixedSize()
    }
}

/// 건물 카드 (2.2). 열림 96pt + `Outline` 2pt, 잠김·완료 72pt 테 없음(잠김은 흑백).
/// 그림 `map_building_{id}` → `SceneThumb-{id}` → 장면 아이콘 순으로 찾는다.
struct MapBuildingCard: View {
    let sceneID: String
    let icon: String?
    let state: MapBuildingState
    let side: CGFloat

    private var image: UIImage? {
        UIImage(named: "map_building_\(sceneID)") ?? UIImage(named: "SceneThumb-\(sceneID)")
    }

    private var isOpen: Bool { state == .open }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: isOpen ? MapShape.buildingCorner : MapShape.buildingSmallCorner,
                                     style: .continuous)
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
                        .font(.system(size: isOpen ? 40 : 30))
                        .foregroundStyle(state == .locked ? MapPalette.quietInk : MapPalette.ink)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(MapPalette.outline, lineWidth: MapShape.outlineWidth)
                .opacity(isOpen ? 1 : 0)
        }
        .accessibilityIgnoresInvertColors(true)
    }
}
