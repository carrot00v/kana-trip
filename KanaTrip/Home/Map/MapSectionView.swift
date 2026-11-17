import SwiftUI

/// 칸 하나를 그릴 때 필요한 것. 상태와 문구는 지도 화면이 진도에서 계산해 넘긴다.
struct MapNodeInfo {
    var state: MapNodeState = .locked
    /// 원 안 번호(단계 칸 1·2).
    var number = 1
    /// 단계 칸의 글자.
    var kana: [String] = []
    /// 종합 퀴즈 칸의 복습 글자 수(완료 전만).
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

/// 지도 구간 하나 (docs/design/home-map.md 1.3, 2.1~2.5). 높이는 구간 높이, 폭은 지도 폭.
/// 그리는 순서: 길 띠 → 진행 선 → 스티커 → 칸·건물·알약. 기리는 구간을 넘어 뛰므로 지도 위 덮개 층이 그린다.
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            road
            progressLines
            if showsStickers {
                stickers
            }
            ForEach(section.nodes) { node in
                nodeView(node)
            }
        }
        .frame(width: width, height: section.height, alignment: .topLeading)
    }

    // MARK: 길

    private func curve(_ path: MapPath) -> Path {
        var p = Path()
        let pts = path.points.map { point($0.x, $0.y) }
        guard pts.count == 4 else { return p }
        p.move(to: pts[0])
        p.addCurve(to: pts[3], control1: pts[1], control2: pts[2])
        return p
    }

    private var road: some View {
        let all = section.paths.reduce(into: Path()) { $0.addPath(curve($1)) }
        return ZStack {
            all.stroke(MapPalette.pathEdge, style: StrokeStyle(lineWidth: metrics.road + metrics.roadEdge * 2, lineCap: .round, lineJoin: .round))
            all.stroke(MapPalette.pathFill, style: StrokeStyle(lineWidth: metrics.road, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }

    /// 지난 길은 실선, 앞길은 둥근 점선. 조각마다 하나로 칠하고, 바뀔 때는 교차 페이드 (2.5, 4.3).
    private var progressLines: some View {
        ZStack {
            ForEach(Array(section.paths.enumerated()), id: \.offset) { _, path in
                let passed = isPassed(path)
                let shape = curve(path)
                ZStack {
                    shape.stroke(MapPalette.ahead, style: StrokeStyle(lineWidth: metrics.progressLine, lineCap: .round,
                                                                       dash: [0, metrics.progressDotGap]))
                        .opacity(passed ? 0 : 1)
                    shape.stroke(MapPalette.passed, style: StrokeStyle(lineWidth: metrics.progressLine, lineCap: .round))
                        .opacity(passed ? 1 : 0)
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: 스티커 (2.3)

    private var stickers: some View {
        ForEach(section.stickers, id: \.step) { sticker in
            let name = "map_sticker_\(sticker.art)"
            // 에셋이 없으면 그 자리를 그리지 않는다. 대체 그림을 두지 않는다.
            if UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: metrics.sticker, height: metrics.sticker)
                    .rotationEffect(.degrees(sticker.rotate))
                    .position(point(sticker.x, sticker.y))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .accessibilityIgnoresInvertColors(true)
            }
        }
    }

    // MARK: 칸

    @ViewBuilder
    private func nodeView(_ node: MapNode) -> some View {
        let center = point(node.x, node.y)
        switch node.kind {
        case .step, .quiz:
            sessionNode(node, info: self.node(node), center: center)
        case .building:
            buildingNode(node, info: building(node), center: center)
        case .start, .gate:
            MapLabelPill(text: node.kind == .start ? L.regionStart(ContentLibrary.shared.sectionTitle) : L.katakanaComingSoon,
                         height: metrics.labelPill, locked: node.kind == .gate)
                .position(center)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(node.kind == .start ? L.regionStartLabel(ContentLibrary.shared.sectionTitle) : L.katakanaComingSoonLabel)
        case .review, .unknown:
            EmptyView()
        }
    }

    /// 원 + 아래 알약을 한 버튼으로 (2.1). 원의 가운데를 칸 자리에 맞춘다.
    private func sessionNode(_ node: MapNode, info: MapNodeInfo, center: CGPoint) -> some View {
        let isQuiz = node.kind == .quiz
        let diameter = isQuiz ? metrics.nodeQuiz : metrics.nodeStep
        let pillHeight = isQuiz ? metrics.labelPill : metrics.kanaPill
        let total = diameter + MapShape.pillGap + pillHeight
        return Button {
            onTapNode(node)
        } label: {
            VStack(spacing: MapShape.pillGap) {
                MapNodeCircle(state: info.state, diameter: diameter, isQuiz: isQuiz, number: info.number)
                Group {
                    if isQuiz {
                        MapLabelPill(text: L.quizPill(review: info.review), height: pillHeight, locked: info.state == .locked)
                    } else {
                        MapKanaPill(kana: info.kana, height: pillHeight, locked: info.state == .locked)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: info.state)
            }
            .frame(minWidth: metrics.nodeStep)
            .contentShape(Rectangle())
        }
        .buttonStyle(MapPressStyle())
        .position(x: center.x, y: center.y - diameter / 2 + total / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(info.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    /// 장면 그림 카드 96pt + 배지 + 이름 알약 (2.2). 잠김이면 누르지 않는다.
    private func buildingNode(_ node: MapNode, info: MapBuildingInfo, center: CGPoint) -> some View {
        let side = metrics.building
        let pill = metrics.labelPill
        let total = side + pill / 2
        return Button {
            onTapBuilding(node)
        } label: {
            VStack(spacing: -pill / 2) {
                MapBuildingCard(sceneID: node.scene ?? node.id, icon: info.icon, state: info.state,
                                side: side, badge: metrics.buildingBadge)
                MapLabelPill(text: L.buildingPill(order: info.order, name: info.name), height: pill,
                             locked: info.state == .locked)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MapPressStyle())
        .allowsHitTesting(info.state != .locked)
        .position(x: center.x, y: center.y - side / 2 + total / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(info.accessibilityLabel)
        .accessibilityAddTraits(info.state == .locked ? [] : .isButton)
    }
}

/// 누르는 동안 살짝 흐리게. 기본 버튼 모양(배경, 강조색 글자)을 쓰지 않는다.
struct MapPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// 세션 칸의 원 (2.1). 잠김: 점선 + 자물쇠, 지금: 채운 원 + 번호(퀴즈는 별), 완료: 실선 + 체크.
struct MapNodeCircle: View {
    let state: MapNodeState
    let diameter: CGFloat
    let isQuiz: Bool
    let number: Int

    var body: some View {
        ZStack {
            switch state {
            case .locked:
                Circle().fill(MapPalette.card)
                Circle().strokeBorder(MapPalette.outline,
                                      style: StrokeStyle(lineWidth: MapShape.outlineWidth, dash: MapShape.lockedDash))
                Image(systemName: "lock.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(MapPalette.lockedInk)
            case .current:
                Circle().fill(MapPalette.passed)
                if isQuiz {
                    Image(systemName: "star.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(MapPalette.onPassed)
                } else {
                    Text("\(number)")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MapPalette.onPassed)
                }
            case .completed:
                Circle().fill(MapPalette.card)
                Circle().strokeBorder(MapPalette.outline, lineWidth: MapShape.outlineWidth)
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MapPalette.done)
            }
        }
        .frame(width: diameter, height: diameter)
        .transition(.opacity)
        .id(state)
    }
}

/// 단계 칸의 글자 알약: 가나 20pt(일본어 로캘), 글자 사이 6pt (2.1). 글자 크기는 따르지 않는다(배치가 깨지므로, 9.3).
struct MapKanaPill: View {
    let kana: [String]
    let height: CGFloat
    let locked: Bool

    var body: some View {
        HStack(spacing: MapShape.kanaSpacing) {
            ForEach(Array(kana.enumerated()), id: \.offset) { _, char in
                Text(KanaText.japanese(char))
                    .font(.system(size: MapShape.kanaSize, weight: locked ? .regular : .bold))
            }
        }
        .environment(\.locale, Locale(identifier: "ja"))
        .foregroundStyle(locked ? MapPalette.lockedInk : MapPalette.ink)
        .padding(.horizontal, MapShape.pillPadding)
        .frame(height: height)
        .background(MapPalette.card, in: Capsule())
        .overlay { Capsule().strokeBorder(MapPalette.outline, lineWidth: MapShape.outlineWidth) }
        .fixedSize()
    }
}

/// 한글 알약("종합 퀴즈", 장면 이름, 표지). `.footnote` 굵게, xxxLarge에서 멈춘다 (2.1, 2.2, 9.3).
struct MapLabelPill: View {
    let text: String
    let height: CGFloat
    let locked: Bool

    var body: some View {
        Text(text)
            .font(.footnote.weight(.bold))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .foregroundStyle(locked ? MapPalette.lockedInk : MapPalette.ink)
            .lineLimit(1)
            .padding(.horizontal, MapShape.pillPadding)
            .frame(height: height)
            .background(MapPalette.card, in: Capsule())
            .overlay { Capsule().strokeBorder(MapPalette.outline, lineWidth: MapShape.outlineWidth) }
            .fixedSize()
    }
}

/// 건물 카드 (2.2). 그림 `map_building_{id}` → `SceneThumb-{id}` → 장면 아이콘 순으로 찾는다.
struct MapBuildingCard: View {
    let sceneID: String
    let icon: String?
    let state: MapBuildingState
    let side: CGFloat
    let badge: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var image: UIImage? {
        UIImage(named: "map_building_\(sceneID)") ?? UIImage(named: "SceneThumb-\(sceneID)")
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MapShape.buildingCorner, style: .continuous)
        ZStack(alignment: .topLeading) {
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
                            .font(.system(size: 40))
                            .foregroundStyle(state == .locked ? MapPalette.lockedInk : MapPalette.ink)
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(shape)
            .overlay { shape.strokeBorder(MapPalette.outline, lineWidth: MapShape.outlineWidth) }
            .accessibilityIgnoresInvertColors(true)

            ZStack {
                badgeView(symbol: "lock.fill", color: MapPalette.lockedInk)
                    .opacity(state == .locked ? 1 : 0)
                badgeView(symbol: "checkmark.circle.fill", color: MapPalette.done)
                    .opacity(state == .completed ? 1 : 0)
            }
            // 원의 중심은 카드 오른쪽 위 꼭짓점에서 왼쪽과 아래로 8pt.
            .position(x: side - MapShape.buildingBadgeInset, y: MapShape.buildingBadgeInset)
        }
        .frame(width: side, height: side)
    }

    private func badgeView(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: MapShape.buildingBadgeSymbol, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: badge, height: badge)
            .background(MapPalette.card, in: Circle())
            .overlay { Circle().strokeBorder(MapPalette.outline, lineWidth: 1) }
    }
}
