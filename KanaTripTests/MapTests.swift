import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import KanaTrip

@Suite("지도 데이터와 칸 상태")
struct MapTests {
    private let library = ContentLibrary.shared

    private func definition() throws -> MapDefinition {
        try #require(MapDefinition.bundled)
    }

    private func route() throws -> MapRoute {
        try MapRoute(region: #require(definition().regions.first))
    }

    /// 앞에서부터 n개 세션을 끝낸 진도.
    private func completed(_ n: Int) -> Set<String> {
        Set(library.sessions.prefix(n).map(\.id))
    }

    // MARK: map.json 해석

    @Test func bundledMapDecodes() throws {
        let map = try definition()
        #expect(map.schema == 2)
        #expect(map.metrics.columns == ["a": 0.4, "b": 0.52, "quiz": 0.46])
        #expect(map.metrics.nodeWidth == 152 && map.metrics.nodeHeight == 52 && map.metrics.nodeWidthRatio == 0.38)
        #expect(map.metrics.band == 96 && map.metrics.bandArt == 72 && map.metrics.sticker == 48)
        #expect(map.metrics.giri == 72 && map.metrics.hopLift == 24 && map.metrics.bubbleHeight == 40)
        #expect(map.metrics.restAnchor == 0.7)
        #expect(map.motion.hop == 0.35)
        #expect(map.motion.maxChainSessions == 3)
        let region = try #require(map.regions.first)
        #expect(region.id == "hiragana")
        // 출발 + 장면 8 + 끝, 아래에서 위 순서.
        #expect(region.sections.map(\.kind) == [.start] + Array(repeating: .scene, count: 8) + [.gate])
        #expect(region.sections.dropFirst().dropLast().compactMap(\.scene) == library.scenes.map(\.id))
        // 지역 높이: 출발 96 + 장면 514 × 8 + 끝 176 (R2.1).
        let total: CGFloat = region.sections.map(\.height).reduce(0, +)
        #expect(total == 4384)
    }

    @Test func stickerWithoutDxDecodesAsZero() throws {
        let json = #"{"slot": "b", "art": "b", "x": 1, "y": 10, "rotate": 6}"#
        let sticker = try JSONDecoder().decode(MapSticker.self, from: Data(json.utf8))
        #expect(sticker.dx == 0)
    }

    /// 375pt 폭에서 한 줄 H 대사가 모두 말풍선 한 줄(최대 폭 W − 32) 안에 들어가는지 (R2.3, R2.5).
    @Test @MainActor func homeLinesFitOneLineAt375() {
        var turns: [GiriSpeech.HomeTurn] = [.allDone, .comingSoon]
        for scene in library.scenes {
            turns.append(.first(scene: scene.name))
            turns.append(.quiz(scene: scene.name))
            for step in scene.steps {
                turns.append(.newScene(scene: scene.name, step: step.name))
                turns.append(.stepB(scene: scene.name, step: step.name))
                turns.append(.resume(scene: scene.name, session: step.name))
            }
        }
        let available: CGFloat = 375 - 32 - MapShape.bubblePadding * 2
        let over = turns.map(GiriSpeech.homeLine).filter {
            ($0 as NSString).size(withAttributes: [.font: MapLineBubble.font]).width > available
        }
        #expect(over.isEmpty, "375pt(글 폭 \(available))에서 한 줄을 넘는 대사: \(over)")
    }

    @Test func homeLinesAreShort() {
        #expect(GiriSpeech.homeLine(.first(scene: "스시집")) == "첫 여행지는 스시집이에요")
        #expect(GiriSpeech.homeLine(.newScene(scene: "돈카츠집", step: "간판")) == "다음 여행지는 돈카츠집이에요")
        #expect(GiriSpeech.homeLine(.stepB(scene: "돈카츠집", step: "메뉴")) == "메뉴 읽으러 가요")
        #expect(GiriSpeech.homeLine(.quiz(scene: "스시집")) == "읽은 걸 같이 확인해 봐요")
        #expect(GiriSpeech.homeLine(.resume(scene: "스시집", session: "간판")) == "하던 데부터 이어서 해요")
    }

    @Test func unknownNodeKindDecodesAsUnknown() throws {
        let json = #"{"id": "x", "kind": "bridge", "x": 0.5, "y": 10}"#
        let node = try JSONDecoder().decode(MapNode.self, from: Data(json.utf8))
        #expect(node.kind == .unknown)
        #expect(!node.isSession)
    }

    @Test func sessionNodesFollowContentOrder() throws {
        let route = try route()
        #expect(route.sessionNodes.map(\.id) == library.sessions.map(\.id))
        #expect(route.count == 24)
        #expect(route.gateID == "hiragana-end")
    }

    /// 칸은 거의 곧게: 모든 장면 같은 x, 좌우 뒤집기 없음. 띠는 세 칸 위 끝 (R2.1, R2.3).
    @Test func nodesStackNearlyStraight() throws {
        let region = try #require(definition().regions.first)
        for section in region.sections where section.kind == .scene {
            let byKind = Dictionary(grouping: section.nodes, by: \.kind)
            let a = try #require(byKind[.step]?.first)
            let b = try #require(byKind[.step]?.last)
            let quiz = try #require(byKind[.quiz]?.first)
            let band = try #require(byKind[.band]?.first)
            #expect([a.x, b.x, quiz.x] == [0.4, 0.52, 0.46], "\(section.id)")
            #expect([a.y, b.y, quiz.y] == [48, 180, 312])
            #expect(band.x == 0.5 && band.y == 466 && band.front == [0.5, 466])
            // 점선 네 조각: 앞 칸 → a → b → 퀴즈 → 띠. 띠 안으로는 지나지 않는다(띠 아래 끝 418 − 6).
            #expect(section.paths.map(\.to) == [a.id, b.id, quiz.id, band.id])
            #expect(section.paths.allSatisfy { $0.d.count == 2 })
            #expect(section.paths.last?.d.last == [0.46, 412])
        }
    }

    @Test func stickersSitAtBandRightEnd() throws {
        let region = try #require(definition().regions.first)
        let arts = region.sections.flatMap(\.stickers).map(\.art)
        // 스시집은 장면 그림이 단어 그림 すし가 되어 스티커를 붙이지 않는다(2026-11-21 사용자 지시, 이슈 #8).
        #expect(arts == ["tonkatsu", "hirekatsu", "udon", "kitsune", "eki", "norikae",
                         "omamori", "takoyaki", "yakitori", "sasami", "yu", "nuruyu", "youkoso", "ofuro"])
        let sushi = try #require(region.sections.first { $0.id == "sushi" })
        #expect(sushi.stickers.isEmpty)
        for section in region.sections where section.kind == .scene && section.id != "sushi" {
            // A x 1 − 96, B x 1 − 40 (B 오른쪽 변 = W − 16), 세로 가운데 = 띠 가운데.
            #expect(section.stickers.map { [$0.x, $0.dx, $0.y] } == [[1, -96, 466], [1, -40, 466]], "\(section.id)")
            #expect(section.stickers.map(\.rotate) == [-6, 6])
            #expect(section.stickers.map(\.slot) == ["a", "b"])
        }
    }

    @Test func layoutPlacesSectionsTopDown() throws {
        let map = try definition()
        let region = try #require(map.regions.first)
        // 402×874: 지도 영역 662pt → 맨 위 여백 662 × 0.7 − 378 = 85.4, 맨 아래 여백 662 × 0.3 − 144 = 54.6.
        let layout = MapLayout(region: region, metrics: map.metrics, width: 402, viewportHeight: 662)
        #expect(abs(layout.topMargin - 85.4) < 0.001)
        #expect(abs(layout.bottomMargin - 54.6) < 0.001)
        #expect(abs(layout.contentHeight - (85.4 + 4384 + 54.6)) < 0.001)
        #expect(layout.nodeWidth == 152)
        let start = try #require(layout.center(of: "hiragana-start"))
        #expect(abs(start.y - (layout.contentHeight - 54.6 - 48)) < 0.001)
        #expect(start.x == 201)
        let sushiA = try #require(layout.center(of: "sushi-a"))
        #expect(abs(sushiA.y - (layout.contentHeight - 54.6 - 96 - 48)) < 0.001)
        #expect(abs(sushiA.x - 402 * 0.4) < 0.001)
        // 기리: 칸 오른쪽 변 + 8, 아래 끝 = 칸 가운데 + 30. 402에서 a x 245~317 (R2.3).
        let giri = try #require(layout.giriCenter(atNode: "sushi-a"))
        #expect(abs((giri.x - 36) - 244.8) < 0.001)
        #expect(abs((giri.y + 36) - (sushiA.y + 30)) < 0.001)
        // 띠 가운데(장면을 넘는 깡충의 중간 자리).
        let band = try #require(layout.front(of: "sushi"))
        #expect(abs(band.y - (layout.contentHeight - 54.6 - 96 - 466)) < 0.001)
        // 360dp: 칸 폭 136.
        #expect(MapLayout(region: region, metrics: map.metrics, width: 360, viewportHeight: 600).nodeWidth == 136)
        let small = MapLayout(region: region, metrics: map.metrics, width: 375, viewportHeight: 300)
        #expect(small.topMargin == 0)
    }

    @Test func restOffsetClampsToContent() throws {
        let map = try definition()
        let region = try #require(map.regions.first)
        let viewport: CGFloat = 662
        let layout = MapLayout(region: region, metrics: map.metrics, width: 402, viewportHeight: viewport)
        // 첫 칸과 마지막 퀴즈 칸 모두 여백 덕분에 쉼 자리(위에서 70%)에 온다.
        for id in ["sushi-a", "ryokan-quiz", "tonkatsu-b"] {
            let c = try #require(layout.center(of: id))
            let offset = layout.restOffset(forContentY: c.y, viewportHeight: viewport, restAnchor: 0.7)
            #expect(abs((c.y - offset) - viewport * 0.7) < 0.001, "\(id)")
        }
        // 출발 표지는 지도 맨 아래라 끝까지만 스크롤한다.
        let start = try #require(layout.center(of: "hiragana-start"))
        #expect(layout.restOffset(forContentY: start.y, viewportHeight: viewport, restAnchor: 0.7) == layout.contentHeight - viewport)
    }

    /// 칸·띠·기리·말풍선이 겹치지 않고 화면 폭(여백 16) 안에 든다 (R2.3 "기리 x 확인", "말풍선 세로 확인", 겹침 0).
    @Test @MainActor func layoutHasNoOverlapAndFitsWidth() throws {
        let map = try definition()
        let region = try #require(map.regions.first)
        let m = map.metrics
        let route = MapRoute(region: region)
        let longest = "다음 여행지는 소바·우동집이에요"
        for width: CGFloat in [360, 375, 402, 440] {
            let layout = MapLayout(region: region, metrics: m, width: width, viewportHeight: 662)
            var boxes: [(id: String, rect: CGRect)] = []
            for node in route.sessionNodes {
                let f = try #require(layout.frame(of: node.id))
                #expect(f.minX >= 16 && f.maxX <= width - 16, "\(width) \(node.id) 칸 \(f)")
                boxes.append((node.id, f))
            }
            for section in region.sections where section.kind == .scene {
                let c = try #require(layout.front(of: section.id))
                boxes.append((section.id, CGRect(x: 16, y: c.y - m.band / 2, width: width - 32, height: m.band)))
            }
            for (i, a) in boxes.enumerated() {
                for b in boxes[(i + 1)...] {
                    #expect(!a.rect.intersects(b.rect), "\(width): \(a.id)와 \(b.id)가 겹침")
                }
            }
            // 기리와 가장 긴 한 줄 말풍선: 어느 칸에 서도 다른 칸·띠와 겹치지 않고 화면 안에 든다.
            for node in route.sessionNodes {
                let g = try #require(layout.giriCenter(atNode: node.id))
                let giri = CGRect(x: g.x - m.giri / 2, y: g.y - m.giri / 2, width: m.giri, height: m.giri)
                #expect(giri.maxX <= width - 16, "\(width) \(node.id) 기리 \(giri)")
                let bubble = MapLineBubble.layout(text: longest, giriCenter: g, width: width, metrics: m).frame
                #expect(bubble.minX >= 16 && bubble.maxX <= width - 16, "\(width) \(node.id) 말풍선 \(bubble)")
                #expect(bubble.maxY <= giri.minY, "\(width) \(node.id) 말풍선이 기리를 덮음")
                for box in boxes {
                    #expect(!giri.intersects(box.rect), "\(width): \(node.id) 기리가 \(box.id)와 겹침")
                    #expect(!bubble.intersects(box.rect), "\(width): \(node.id) 말풍선이 \(box.id)와 겹침")
                }
            }
            // 띠 글자 자리(그림 72 + 12 ~ 스티커 A 왼쪽 − 12)가 가장 긴 가나 줄(6자 약 126pt)보다 넓다.
            let textRoom = (width - 16 - m.sticker * 2 - m.stickerGap - 12) - (16 + m.bandArt + 12)
            #expect(textRoom >= 126, "\(width): 띠 글자 자리 \(textRoom)")
        }
    }

    @Test func dotsAreEvenlySpaced() {
        let dots = MapSectionView.dotCenters(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 68), spacing: 12)
        #expect(dots.count == 6)
        #expect(abs(dots[0].y - 4) < 0.001 && abs(dots[5].y - 64) < 0.001)
        // 짧은 조각은 가운데 한 점.
        let one = MapSectionView.dotCenters(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 10), spacing: 12)
        #expect(one.count == 1 && abs(one[0].y - 5) < 0.001)
    }

    // MARK: 지금 칸

    @Test func currentNodeFollowsCompletedSessions() throws {
        let route = try route()
        #expect(route.currentNodeID(completed: []) == "sushi-a")
        #expect(route.currentNodeID(completed: completed(1)) == "sushi-b")
        #expect(route.currentNodeID(completed: completed(3)) == "tonkatsu-a")
        #expect(route.currentNodeID(completed: completed(23)) == "ryokan-quiz")
        #expect(route.currentNodeID(completed: completed(24)) == "hiragana-end")
    }

    @Test func currentNodeMatchesHomeTarget() throws {
        let route = try route()
        for n in [0, 1, 2, 3, 7, 12, 23] {
            let store = ProgressStore(storage: MapMemoryStorage(completed: completed(n)))
            let target = try #require(store.homeTarget())
            #expect(route.currentNodeID(completed: store.state.completedSessionIDs) == target.session.id)
            #expect(store.mapCurrentNodeID(route: route) == target.session.id)
        }
        let done = ProgressStore(storage: MapMemoryStorage(completed: completed(24)))
        #expect(done.homeTarget() == nil)
        #expect(done.mapCurrentNodeID(route: route) == "hiragana-end")
    }

    // MARK: 칸 상태

    @Test func steadyStatesFromProgress() throws {
        let route = try route()
        let done = completed(4)  // 스시집 끝, 돈카츠집 a 끝
        let display = MapDisplay(index: 4)
        #expect(route.state(ofSession: "sushi-a", display: display) == .completed)
        #expect(route.state(ofSession: "tonkatsu-a", display: display) == .completed)
        #expect(route.state(ofSession: "tonkatsu-b", display: display) == .current)
        #expect(route.state(ofSession: "tonkatsu-quiz", display: display) == .locked)
        #expect(route.state(ofSession: "soba-a", display: display) == .locked)
        #expect(route.state(ofBand: "sushi", display: display, completed: done) == .completed)
        #expect(route.state(ofBand: "tonkatsu", display: display, completed: done) == .open)
        #expect(route.state(ofBand: "soba", display: display, completed: done) == .locked)
    }

    @Test func displayStagesDuringHop() throws {
        let route = try route()
        var display = MapDisplay(index: 0)
        #expect(route.state(ofSession: "sushi-a", display: display) == .current)
        #expect(route.state(ofSession: "sushi-b", display: display) == .locked)
        display.markIndex = 1
        #expect(route.state(ofSession: "sushi-a", display: display) == .completed)
        #expect(route.state(ofSession: "sushi-b", display: display) == .locked)
        display.currentIndex = 1
        #expect(route.state(ofSession: "sushi-b", display: display) == .current)
    }

    /// 장면 완료: 띠의 체크·스티커는 기리가 띠에 내려앉을 때 붙고, 다음 띠도 그때 열린다 (R2.4).
    @Test func bandCompletesWhenGiriLands() throws {
        let route = try route()
        let done = completed(3)  // 스시집 퀴즈까지 끝
        var display = MapDisplay(index: 2)  // 보여 준 칸 = 스시집 퀴즈(연출 전)
        #expect(route.state(ofBand: "sushi", display: display, completed: done) == .open)
        #expect(route.state(ofBand: "tonkatsu", display: display, completed: done) == .locked)
        display.markIndex = 3
        #expect(route.state(ofBand: "sushi", display: display, completed: done) == .open)
        display.bandDoneIndex = 3
        display.bandOpenIndex = 3
        #expect(route.state(ofBand: "sushi", display: display, completed: done) == .completed)
        #expect(route.state(ofBand: "tonkatsu", display: display, completed: done) == .open)
        // 진도를 되돌렸으면(끝내지 않은 세션이 있으면) 띠는 완료가 아니다.
        #expect(route.state(ofBand: "sushi", display: MapDisplay(index: 3), completed: completed(2)) == .open)
    }

    // MARK: 다음 칸과 깡충 계획

    @Test func oneStepHop() throws {
        let route = try route()
        #expect(route.transition(from: "sushi-a", to: "sushi-b", maxChain: 3) == .hops([MapHop(to: .node("sushi-b"), kind: .step)]))
        #expect(route.transition(from: "sushi-b", to: "sushi-quiz", maxChain: 3) == .hops([MapHop(to: .node("sushi-quiz"), kind: .step)]))
    }

    @Test func sceneCrossingGoesThroughFinishedBand() throws {
        let route = try route()
        #expect(route.transition(from: "sushi-quiz", to: "tonkatsu-a", maxChain: 3) == .hops([
            MapHop(to: .front("sushi"), kind: .scene),
            MapHop(to: .node("tonkatsu-a"), kind: .scene),
        ]))
        #expect(route.transition(from: "ryokan-quiz", to: "hiragana-end", maxChain: 3) == .hops([
            MapHop(to: .front("ryokan"), kind: .scene),
            MapHop(to: .node("hiragana-end"), kind: .scene),
        ]))
    }

    @Test func chainedHops() throws {
        let route = try route()
        // a → b → 퀴즈 → 띠 → 다음 a (가장 긴 경우).
        #expect(route.transition(from: "sushi-a", to: "tonkatsu-a", maxChain: 3) == .hops([
            MapHop(to: .node("sushi-b"), kind: .step),
            MapHop(to: .node("sushi-quiz"), kind: .step),
            MapHop(to: .front("sushi"), kind: .scene),
            MapHop(to: .node("tonkatsu-a"), kind: .scene),
        ]))
    }

    @Test func noHopWhenSameFarBackOrUnknown() throws {
        let route = try route()
        #expect(route.transition(from: "sushi-b", to: "sushi-b", maxChain: 3) == .none)
        #expect(route.transition(from: "sushi-a", to: "tonkatsu-b", maxChain: 3) == .jump)  // 4칸 앞
        #expect(route.transition(from: "tonkatsu-a", to: "sushi-a", maxChain: 3) == .jump)  // 뒤로(진도 초기화)
        #expect(route.transition(from: nil, to: "sushi-a", maxChain: 3) == .jump)  // 첫 실행
        #expect(route.transition(from: "airport-a", to: "sushi-a", maxChain: 3) == .jump)  // 데이터 교체
    }

    @Test func shownNodeStorageRoundTrips() {
        let defaults = UserDefaults(suiteName: "MapTests-\(UUID().uuidString)")!
        let store = MapShownStore(defaults: defaults)
        #expect(store.shownNodeID == nil)
        store.shownNodeID = "sushi-b"
        #expect(MapShownStore(defaults: defaults).shownNodeID == "sushi-b")
        #expect(defaults.string(forKey: "map.lastShownNodeID") == "sushi-b")
    }
}

/// 끝낸 세션만 든 진도.
private final class MapMemoryStorage: ProgressStorage {
    private var state: ProgressState?

    init(completed: Set<String>) {
        var state = ProgressState()
        for id in completed {
            var progress = SessionProgress()
            progress.completed = true
            state.sessions[id] = progress
        }
        self.state = state
    }

    func load() -> ProgressState? { state }
    func save(_ state: ProgressState) { self.state = state }
}
