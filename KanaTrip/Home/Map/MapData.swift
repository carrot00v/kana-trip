import CoreGraphics
import Foundation

// 지도 정의 데이터 map.json (docs/design/home-map.md 7.1). tools/build_map.py가 만들고 iOS·안드로이드가 같이 읽는다.
// SwiftUI에 의존하지 않는다. 칸 상태와 문구는 데이터에 없고 진도·장면 데이터에서 계산한다(MapProgress.swift).

struct MapDefinition: Decodable {
    let schema: Int
    let metrics: MapMetrics
    let motion: MapMotion
    let regions: [MapRegion]

    /// 번들의 map.json. 읽지 못하면 nil(앱은 지도를 그리지 못하므로 개발 중에 바로 드러나게 assert한다).
    static let bundled: MapDefinition? = {
        guard let url = Bundle.main.url(forResource: "map", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            assertionFailure("map.json이 번들에 없음")
            return nil
        }
        do {
            return try decode(data)
        } catch {
            assertionFailure("map.json을 읽지 못함: \(error)")
            return nil
        }
    }()

    static func decode(_ data: Data) throws -> MapDefinition {
        try JSONDecoder().decode(MapDefinition.self, from: data)
    }
}

/// 두 플랫폼이 상수 대신 읽는 수치(pt = dp). 앱 코드에 같은 숫자를 다시 쓰지 않는다 (7.1, 7.4).
struct MapMetrics: Decodable {
    let lanes: [CGFloat]
    let stepGap: CGFloat
    let sceneGap: CGFloat
    let nodeStep: CGFloat
    let nodeQuiz: CGFloat
    let building: CGFloat
    let buildingBadge: CGFloat
    let kanaPill: CGFloat
    let labelPill: CGFloat
    let road: CGFloat
    let roadEdge: CGFloat
    let progressLine: CGFloat
    let progressDotGap: CGFloat
    let giri: CGFloat
    let giriFootBelowNode: CGFloat
    let hopLift: CGFloat
    let bubbleBandAbove: CGFloat
    let bubbleBandBelow: CGFloat
    let sticker: CGFloat
    /// 쉼 자리: 지금 칸이 오는 높이(지도 영역 위 끝에서 잰 비율, 1.4).
    let restAnchor: CGFloat
    let dock: CGFloat
    let dockCustomize: CGFloat
    let dockGap: CGFloat
    /// 맨 위 여백 = max(0, 지도 영역 × restAnchor − topMarginBase) (1.3).
    let topMarginBase: CGFloat
    /// "지금 칸으로"가 나타나는 기준: 지금 칸 가운데가 지도 영역 위·아래 끝에서 이만큼 안쪽을 벗어날 때 (3.2).
    let edgeMargin: CGFloat
}

/// 연출 시간(초) (4번).
struct MapMotion: Decodable {
    let markFade: Double
    let bubbleOut: Double
    let hop: Double
    let hopScene: Double
    let buildingOpen: Double
    let faceSwap: Double
    let bubbleIn: Double
    let labelFade: Double
    let reduceMotionFade: Double
    /// 연출하는 최대 세션 칸 수. 이보다 멀리 앞서면 연출 없이 결과 상태 (4.1).
    let maxChainSessions: Int
    /// "지금 칸으로"를 눌렀을 때의 스크롤 (3.2).
    let jumpScroll: Double
}

struct MapRegion: Decodable, Identifiable {
    let id: String
    let script: String
    /// 아래(출발)에서 위(지역 끝) 순서.
    let sections: [MapSection]
}

struct MapSection: Decodable, Identifiable {
    enum Kind: String, Decodable {
        case start, scene, gate
    }

    let id: String
    let kind: Kind
    let scene: String?
    let height: CGFloat
    let tile: String?
    let nodes: [MapNode]
    let paths: [MapPath]
    let stickers: [MapSticker]
}

struct MapNode: Decodable, Identifiable, Equatable {
    enum Kind: String, Decodable {
        case start, building, step, quiz, gate, review
        /// 이 앱이 모르는 새 종류. 그리지 않는다.
        case unknown

        init(from decoder: Decoder) throws {
            self = Kind(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    enum BubbleSide: String, Decodable {
        case left, right
    }

    let id: String
    let kind: Kind
    let scene: String?
    let session: String?
    /// 지도 폭에 대한 비율.
    let x: CGFloat
    /// 구간 바닥에서 위로 잰 pt.
    let y: CGFloat
    /// 건물 앞 자리 [x, y]. 장면을 넘는 깡충의 중간 착지점 (4.4).
    let front: [CGFloat]?
    /// 기리가 이 칸에 섰을 때 말풍선 쪽.
    let bubble: BubbleSide?

    var isSession: Bool { kind == .step || kind == .quiz }
}

/// 3차 베지어 한 조각: [시작점, 제어점 1, 제어점 2, 끝점].
struct MapPath: Decodable, Equatable {
    let from: String
    let to: String
    let d: [[CGFloat]]

    var points: [CGPoint] { d.map { CGPoint(x: $0[0], y: $0[1]) } }
}

struct MapSticker: Decodable, Equatable {
    let step: String
    let art: String
    let x: CGFloat
    let y: CGFloat
    let rotate: Double
}

/// 지도 폭과 지도 영역 높이가 정해졌을 때의 콘텐츠 좌표 (7.1).
/// 콘텐츠 좌표는 화면처럼 위가 0이고 아래로 커진다. 구간은 위에서 아래로(데이터의 역순) 쌓는다.
struct MapLayout: Equatable {
    let width: CGFloat
    let topMargin: CGFloat
    let contentHeight: CGFloat
    /// 구간 id → 구간 위 끝의 콘텐츠 y.
    private let sectionTop: [String: CGFloat]
    private let sectionHeight: [String: CGFloat]
    private let sectionOfNode: [String: String]
    private let nodes: [String: MapNode]

    init(region: MapRegion, metrics: MapMetrics, width: CGFloat, viewportHeight: CGFloat) {
        self.width = width
        let margin = max(0, viewportHeight * metrics.restAnchor - metrics.topMarginBase)
        topMargin = margin
        var top = margin
        var tops: [String: CGFloat] = [:]
        var heights: [String: CGFloat] = [:]
        var owner: [String: String] = [:]
        var all: [String: MapNode] = [:]
        for section in region.sections.reversed() {
            tops[section.id] = top
            heights[section.id] = section.height
            top += section.height
            for node in section.nodes {
                owner[node.id] = section.id
                all[node.id] = node
            }
        }
        contentHeight = top
        sectionTop = tops
        sectionHeight = heights
        sectionOfNode = owner
        self.nodes = all
    }

    /// 구간 안 좌표(x 비율, 바닥에서 위로 잰 y)를 콘텐츠 좌표로.
    func point(section: String, x: CGFloat, y: CGFloat) -> CGPoint {
        let top = sectionTop[section] ?? 0
        let height = sectionHeight[section] ?? 0
        return CGPoint(x: x * width, y: top + height - y)
    }

    /// 칸 가운데의 콘텐츠 좌표.
    func center(of nodeID: String) -> CGPoint? {
        guard let node = nodes[nodeID], let section = sectionOfNode[nodeID] else { return nil }
        return point(section: section, x: node.x, y: node.y)
    }

    /// 건물 앞 자리의 콘텐츠 좌표. 건물이 아니면 nil.
    func front(of buildingID: String) -> CGPoint? {
        guard let node = nodes[buildingID], let front = node.front, front.count == 2,
              let section = sectionOfNode[buildingID]
        else { return nil }
        return point(section: section, x: front[0], y: front[1])
    }

    /// 콘텐츠 y가 지도 영역의 쉼 자리(위에서 restAnchor)에 오게 하는 스크롤 위치(콘텐츠 맨 위 = 0).
    /// 콘텐츠 끝을 넘지 않게 자른다 (4.3).
    func restOffset(forContentY y: CGFloat, viewportHeight: CGFloat, restAnchor: CGFloat) -> CGFloat {
        let wanted = y - viewportHeight * restAnchor
        return min(max(0, wanted), max(0, contentHeight - viewportHeight))
    }
}
