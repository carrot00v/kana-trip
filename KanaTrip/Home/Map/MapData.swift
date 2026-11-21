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

/// 두 플랫폼이 상수 대신 읽는 수치(pt = dp). 앱 코드에 같은 숫자를 다시 쓰지 않는다
/// (home-map.md 7.1, 7.4, "2026-11-21 재구성안" R2.3).
struct MapMetrics: Decodable {
    /// 칸 종류별 x(폭 비율): 단계 a, 단계 b, 종합 퀴즈. 모든 장면 같다.
    let columns: [String: CGFloat]
    let stepGap: CGFloat
    /// 세션 칸(캡슐) 폭 = min(nodeWidth, nodeWidthRatio × 지도 폭).
    let nodeWidth: CGFloat
    let nodeWidthRatio: CGFloat
    let nodeHeight: CGFloat
    /// 완료·잠김 칸의 테 굵기.
    let nodeRing: CGFloat
    /// 장면 띠 높이.
    let band: CGFloat
    /// 장면 띠 왼쪽 그림 한 변.
    let bandArt: CGFloat
    /// 장면 띠 좌우 여백(화면 가장자리에서).
    let bandInset: CGFloat
    /// 점선의 점 지름, 점 가운데 사이.
    let dot: CGFloat
    let dotSpacing: CGFloat
    /// 칸·띠 가장자리에서 점선이 멈추는 거리.
    let dotGap: CGFloat
    let giri: CGFloat
    /// 칸 오른쪽 변에서 기리 왼쪽 변까지.
    let giriGap: CGFloat
    /// 기리 아래 끝 = 칸 가운데 + 이 값.
    let giriFootBelowNode: CGFloat
    let hopLift: CGFloat
    /// 한 줄 말풍선 몸통 높이.
    let bubbleHeight: CGFloat
    /// 기리 위 끝에서 말풍선 몸통 아래 끝까지.
    let bubbleAboveGiri: CGFloat
    let sticker: CGFloat
    let stickerGap: CGFloat
    /// 쉼 자리: 지금 칸이 오는 높이(지도 영역 위 끝에서 잰 비율).
    let restAnchor: CGFloat
    let dock: CGFloat
    let dockCustomize: CGFloat
    let dockGap: CGFloat
    /// "지금 칸으로" 원 버튼 지름.
    let jumpButton: CGFloat
    /// 맨 위 여백 = max(0, 지도 영역 × restAnchor − topMarginBase). topMarginBase = 지역 위 끝에서 마지막 퀴즈 칸 가운데까지.
    let topMarginBase: CGFloat
    /// "지금 칸으로"가 나타나는 기준: 지금 칸 가운데가 지도 영역 위·아래 끝에서 이만큼 안쪽을 벗어날 때 (3.2).
    let edgeMargin: CGFloat

    /// 지도 폭에서의 세션 칸 폭.
    func nodeWidth(in width: CGFloat) -> CGFloat {
        min(nodeWidth, (nodeWidthRatio * width).rounded(.down))
    }
}

/// 연출 시간(초) (4번, R2.4).
struct MapMotion: Decodable {
    let markFade: Double
    let bubbleOut: Double
    let hop: Double
    let hopScene: Double
    /// 다음 장면 띠가 열리는(흑백 → 컬러) 시간.
    let bandOpen: Double
    /// 장면 완료 때 스티커가 나타나는 시간.
    let stickerIn: Double
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
        case start, band, step, quiz, gate, review
        /// 이 앱이 모르는 새 종류. 그리지 않는다.
        case unknown

        init(from decoder: Decoder) throws {
            self = Kind(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    let id: String
    let kind: Kind
    let scene: String?
    let session: String?
    /// 지도 폭에 대한 비율.
    let x: CGFloat
    /// 구간 바닥에서 위로 잰 pt.
    let y: CGFloat
    /// 장면 띠의 기리 자리 [x, y](기리 가운데). 장면을 넘는 깡충의 중간 착지점 (R2.4).
    let front: [CGFloat]?

    var isSession: Bool { kind == .step || kind == .quiz }
}

/// 곧은 점선 한 조각: [시작점, 끝점]. y는 `to` 칸이 든 구간 바닥에서 잰 값(앞 구간으로 넘어가면 음수) (R2.3).
struct MapPath: Decodable, Equatable {
    let from: String
    let to: String
    let d: [[CGFloat]]

    var points: [CGPoint] { d.map { CGPoint(x: $0[0], y: $0[1]) } }
}

/// 자리 = (x × 지도 폭 + dx, y). dx는 pt로, 띠 오른쪽 끝에 붙여 두려고 폭에 비례하지 않게 둔다 (R2.3).
struct MapSticker: Decodable, Equatable {
    /// "a" 또는 "b"(띠 오른쪽 끝의 두 칸 가운데 어느 것).
    let slot: String
    let art: String
    let x: CGFloat
    let dx: CGFloat
    let y: CGFloat
    let rotate: Double

    private enum CodingKeys: String, CodingKey {
        case slot, art, x, dx, y, rotate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slot = try c.decode(String.self, forKey: .slot)
        art = try c.decode(String.self, forKey: .art)
        x = try c.decode(CGFloat.self, forKey: .x)
        dx = try c.decodeIfPresent(CGFloat.self, forKey: .dx) ?? 0
        y = try c.decode(CGFloat.self, forKey: .y)
        rotate = try c.decode(Double.self, forKey: .rotate)
    }
}

/// 지도 폭과 지도 영역 높이가 정해졌을 때의 콘텐츠 좌표 (7.1).
/// 콘텐츠 좌표는 화면처럼 위가 0이고 아래로 커진다. 구간은 위에서 아래로(데이터의 역순) 쌓는다.
/// 위·아래 여백은 맨 위 퀴즈 칸과 첫 칸이 쉼 자리(restAnchor)에 올 수 있게 둔다.
struct MapLayout: Equatable {
    let width: CGFloat
    let topMargin: CGFloat
    let bottomMargin: CGFloat
    let contentHeight: CGFloat
    /// 세션 칸(캡슐) 폭.
    let nodeWidth: CGFloat
    let nodeHeight: CGFloat
    /// 구간 id → 구간 위 끝의 콘텐츠 y.
    private let sectionTop: [String: CGFloat]
    private let sectionHeight: [String: CGFloat]
    private let sectionOfNode: [String: String]
    private let nodes: [String: MapNode]
    private let giriSize: CGFloat
    private let giriGap: CGFloat
    private let giriFoot: CGFloat

    init(region: MapRegion, metrics: MapMetrics, width: CGFloat, viewportHeight: CGFloat) {
        self.width = width
        nodeWidth = metrics.nodeWidth(in: width)
        nodeHeight = metrics.nodeHeight
        giriSize = metrics.giri
        giriGap = metrics.giriGap
        giriFoot = metrics.giriFootBelowNode
        let margin = max(0, viewportHeight * metrics.restAnchor - metrics.topMarginBase)
        topMargin = margin
        // 첫 세션 칸이 지역 바닥에서 얼마나 위에 있는지.
        var firstFromBottom: CGFloat = 0
        var below: CGFloat = 0
        search: for section in region.sections {
            for node in section.nodes where node.kind == .step || node.kind == .quiz {
                firstFromBottom = below + node.y
                break search
            }
            below += section.height
        }
        bottomMargin = max(0, viewportHeight * (1 - metrics.restAnchor) - firstFromBottom)
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
        contentHeight = top + bottomMargin
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

    /// 세션 칸(캡슐)의 콘텐츠 사각형. 세션 칸이 아니면 nil.
    func frame(of nodeID: String) -> CGRect? {
        guard let node = nodes[nodeID], node.isSession, let c = center(of: nodeID) else { return nil }
        return CGRect(x: c.x - nodeWidth / 2, y: c.y - nodeHeight / 2, width: nodeWidth, height: nodeHeight)
    }

    /// 장면 띠의 기리 자리(기리 가운데)의 콘텐츠 좌표. 띠가 아니면 nil.
    func front(of bandID: String) -> CGPoint? {
        guard let node = nodes[bandID], let front = node.front, front.count == 2,
              let section = sectionOfNode[bandID]
        else { return nil }
        return point(section: section, x: front[0], y: front[1])
    }

    /// 칸에 선 기리의 가운데: 칸 오른쪽 변 + giriGap, 아래 끝 = 칸 가운데 + giriFootBelowNode (R2.3).
    /// 지역 끝 표지도 세션 칸과 같은 폭의 자리로 본다.
    func giriCenter(atNode nodeID: String) -> CGPoint? {
        guard let c = center(of: nodeID) else { return nil }
        return CGPoint(x: c.x + nodeWidth / 2 + giriGap + giriSize / 2,
                       y: c.y + giriFoot - giriSize / 2)
    }

    /// 콘텐츠 y가 지도 영역의 쉼 자리(위에서 restAnchor)에 오게 하는 스크롤 위치(콘텐츠 맨 위 = 0).
    /// 콘텐츠 끝을 넘지 않게 자른다 (4.3).
    func restOffset(forContentY y: CGFloat, viewportHeight: CGFloat, restAnchor: CGFloat) -> CGFloat {
        let wanted = y - viewportHeight * restAnchor
        return min(max(0, wanted), max(0, contentHeight - viewportHeight))
    }
}
