import CoreGraphics
import Foundation
import Testing
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
        #expect(map.schema == 1)
        #expect(map.metrics.lanes == [0.3, 0.7])
        #expect(map.metrics.nodeStep == 36 && map.metrics.nodeQuiz == 44)
        #expect(map.metrics.building == 96 && map.metrics.buildingSmall == 72 && map.metrics.sticker == 48)
        #expect(map.metrics.footSpot == [64, 20] && map.metrics.bubbleBandAbove == 48)
        #expect(map.metrics.restAnchor == 0.6)
        #expect(map.motion.hop == 0.35)
        #expect(map.motion.maxChainSessions == 3)
        let region = try #require(map.regions.first)
        #expect(region.id == "hiragana")
        // 출발 + 장면 8 + 끝, 아래에서 위 순서.
        #expect(region.sections.map(\.kind) == [.start] + Array(repeating: .scene, count: 8) + [.gate])
        #expect(region.sections.dropFirst().dropLast().compactMap(\.scene) == library.scenes.map(\.id))
        // 지역 높이 4,384pt (1.3).
        #expect(region.sections.map(\.height).reduce(0, +) == 4384)
    }

    @Test func stickerWithoutDxDecodesAsZero() throws {
        let json = #"{"step": "a", "art": "b", "x": 0.3, "y": 10, "rotate": 6}"#
        let sticker = try JSONDecoder().decode(MapSticker.self, from: Data(json.utf8))
        #expect(sticker.dx == 0)
    }

    /// 375pt 폭에서 H 권유 대사가 모두 지도 말풍선 3줄 안에 들어가는지 ("2026-11-18 시각 정리" S5·S8).
    /// 말풍선 몸통 = 기리 쪽 변 + 12 ~ 화면 여백 16, 글 폭 = 몸통 − 안쪽 24. 두 길이 대칭이라 왼쪽 길로 잰다.
    @Test @MainActor func homeLinesFitBubbleAt375() throws {
        let map = try definition()
        let width: CGFloat = 375
        let cx = width * map.metrics.lanes[0]
        let body = (width - 16) - (cx + map.metrics.giri / 2 + 12)
        let textWidth = body - 24
        var turns: [GiriSpeech.HomeTurn] = [.allDone, .comingSoon]
        for scene in library.scenes {
            turns.append(.first(scene: scene.name))
            turns.append(.quiz(scene: scene.name))
            for step in scene.steps {
                turns.append(.newScene(scene: scene.name, step: step.name))
                turns.append(.stepB(scene: scene.name, step: step.name))
                turns.append(.resume(scene: scene.name, session: step.name))
            }
            turns.append(.resume(scene: scene.name, session: L.quizSessionName))
        }
        let over = turns.map(GiriSpeech.home).filter {
            GiriSpeechRow.lineCount($0, width: textWidth, typeSize: .large) > 3
        }
        #expect(over.isEmpty, "375pt(글 폭 \(textWidth))에서 3줄을 넘는 대사: \(over)")
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

    @Test func lanesAlternateByScene() throws {
        let region = try #require(definition().regions.first)
        for (i, section) in region.sections.filter({ $0.kind == .scene }).enumerated() {
            let byKind = Dictionary(grouping: section.nodes, by: \.kind)
            let a = try #require(byKind[.step]?.first)
            let b = try #require(byKind[.step]?.last)
            let quiz = try #require(byKind[.quiz]?.first)
            let building = try #require(byKind[.building]?.first)
            let left = i % 2 == 0
            #expect(a.x == (left ? 0.3 : 0.7), "\(section.id) a 칸 길")
            #expect(b.x == (left ? 0.7 : 0.3))
            #expect(quiz.x == a.x)
            #expect(building.x == 0.5 && building.y == 80 && building.front == [0.5, 40])
            #expect([a.y, b.y, quiz.y] == [200, 328, 456])
            #expect(a.bubble == (left ? .right : .left))
            #expect(b.bubble == (left ? .left : .right))
            // 길은 구간 경계에서 x 0.5로 지난다.
            #expect(section.paths.first?.d.first == [0.5, 0])
            #expect(section.paths.last?.d.last == [0.5, 504])
        }
    }

    @Test func stickersMatchDesignedPicks() throws {
        let region = try #require(definition().regions.first)
        let arts = region.sections.flatMap(\.stickers).map(\.art)
        #expect(arts == ["sushi", "ika", "tonkatsu", "hirekatsu", "udon", "kitsune", "eki", "norikae",
                         "omamori", "takoyaki", "yakitori", "sasami", "yu", "nuruyu", "youkoso", "ofuro"])
        let sushi = try #require(region.sections.first { $0.id == "sushi" })
        // 건물 카드 양옆에 붙인다: A 왼쪽 dx −50·8pt 아래, B 오른쪽 dx +50·8pt 위. 홀짝 같음 (2.3).
        #expect(sushi.stickers.map { [$0.x, $0.dx, $0.y] } == [[0.5, -50, 72], [0.5, 50, 88]])
        #expect(sushi.stickers.map(\.rotate) == [-6, 6])
        let tonkatsu = try #require(region.sections.first { $0.id == "tonkatsu" })
        #expect(tonkatsu.stickers.map { [$0.x, $0.dx, $0.y] } == [[0.5, -50, 72], [0.5, 50, 88]])
        #expect(region.sections.flatMap(\.stickers).allSatisfy { $0.x == 0.5 })
    }

    @Test func layoutPlacesSectionsTopDown() throws {
        let map = try definition()
        let region = try #require(map.regions.first)
        // 402×874: 지도 영역 662pt → 맨 위 여백 662 × 0.6 − 224 = 173.2.
        let layout = MapLayout(region: region, metrics: map.metrics, width: 402, viewportHeight: 662)
        #expect(abs(layout.topMargin - 173.2) < 0.001)
        #expect(abs(layout.contentHeight - (173.2 + 4384)) < 0.001)
        // 출발 표지: 맨 아래 구간 바닥에서 위로 72.
        let start = try #require(layout.center(of: "hiragana-start"))
        #expect(abs(start.y - (layout.contentHeight - 72)) < 0.001)
        #expect(start.x == 201)
        // 스시집 a 칸: 출발 구간 위 끝(아래에서 176) + 200.
        let sushiA = try #require(layout.center(of: "sushi-a"))
        #expect(abs(sushiA.y - (layout.contentHeight - 176 - 200)) < 0.001)
        #expect(abs(sushiA.x - 402 * 0.3) < 0.001)
        let front = try #require(layout.front(of: "tonkatsu"))
        #expect(abs(front.y - (layout.contentHeight - 176 - 504 - 40)) < 0.001)
        // 지역 끝 표지: 맨 위 여백 + 176 − 72.
        let gate = try #require(layout.center(of: "hiragana-end"))
        #expect(abs(gate.y - (layout.topMargin + 104)) < 0.001)
        // 작은 화면은 여백이 없다(531 × 0.6 < 224 아님 → 94.6).
        let small = MapLayout(region: region, metrics: map.metrics, width: 375, viewportHeight: 300)
        #expect(small.topMargin == 0)
    }

    @Test func restOffsetClampsToContent() throws {
        let map = try definition()
        let region = try #require(map.regions.first)
        let layout = MapLayout(region: region, metrics: map.metrics, width: 402, viewportHeight: 662)
        // 출발 표지는 지도 맨 아래라 끝까지만 스크롤한다.
        let start = try #require(layout.center(of: "hiragana-start"))
        let offset = layout.restOffset(forContentY: start.y, viewportHeight: 662, restAnchor: 0.6)
        #expect(offset == layout.contentHeight - 662)
        // 첫 칸(바닥에서 376pt)은 쉼 자리(바닥에서 662 × 0.4)에 온다.
        let first = try #require(layout.center(of: "sushi-a"))
        let firstOffset = layout.restOffset(forContentY: first.y, viewportHeight: 662, restAnchor: 0.6)
        #expect(abs((first.y - firstOffset) - 662 * 0.6) < 0.001)
        // 마지막 퀴즈 칸은 맨 위 여백 덕분에 쉼 자리에 온다 (1.3).
        let last = try #require(layout.center(of: "ryokan-quiz"))
        let top = layout.restOffset(forContentY: last.y, viewportHeight: 662, restAnchor: 0.6)
        #expect(abs((last.y - top) - 662 * 0.6) < 0.001)
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
        #expect(route.state(ofBuilding: "sushi", display: display, completed: done) == .completed)
        #expect(route.state(ofBuilding: "tonkatsu", display: display, completed: done) == .open)
        #expect(route.state(ofBuilding: "soba", display: display, completed: done) == .locked)
    }

    @Test func displayStagesDuringHop() throws {
        let route = try route()
        // sushi-a를 끝내고 돌아옴: 보여 준 칸 0, 지금 칸 1.
        var display = MapDisplay(index: 0)
        #expect(route.state(ofSession: "sushi-a", display: display) == .current)
        #expect(route.state(ofSession: "sushi-b", display: display) == .locked)
        // 2 칸 완료 표시.
        display.markIndex = 1
        #expect(route.state(ofSession: "sushi-a", display: display) == .completed)
        #expect(route.state(ofSession: "sushi-b", display: display) == .locked)
        // 4 착지.
        display.currentIndex = 1
        #expect(route.state(ofSession: "sushi-b", display: display) == .current)
    }

    @Test func buildingStaysLockedUntilOpened() throws {
        let route = try route()
        let done = completed(3)  // 스시집 퀴즈까지 끝
        var display = MapDisplay(index: 2)  // 보여 준 칸 = 스시집 퀴즈
        // 끝낸 장면의 건물은 연출 전에도 완료(배지·스티커는 결과 상태, 4.2).
        #expect(route.state(ofBuilding: "sushi", display: display, completed: done) == .completed)
        #expect(route.state(ofBuilding: "tonkatsu", display: display, completed: done) == .locked)
        display.buildingOpenIndex = 3
        #expect(route.state(ofBuilding: "tonkatsu", display: display, completed: done) == .open)
    }

    @Test func progressLineEndsAtMarkedNode() throws {
        let route = try route()
        let sushi = try #require(route.region.sections.first { $0.id == "sushi" })
        let paths = Dictionary(uniqueKeysWithValues: sushi.paths.map { ("\($0.from)>\($0.to)", $0) })
        let display = MapDisplay(index: 1)  // 지금 칸 sushi-b
        #expect(route.isPassed(try #require(paths["hiragana-start>sushi"]), display: display))
        #expect(route.isPassed(try #require(paths["sushi>sushi-a"]), display: display))
        #expect(route.isPassed(try #require(paths["sushi-a>sushi-b"]), display: display))
        #expect(!route.isPassed(try #require(paths["sushi-b>sushi-quiz"]), display: display))
        #expect(!route.isPassed(try #require(paths["sushi-quiz>tonkatsu"]), display: display))
        // 장면을 넘어 다음 a 칸이 지금이면 퀴즈 → 건물 → a 모두 실선.
        let next = MapDisplay(index: 3)
        #expect(route.isPassed(try #require(paths["sushi-quiz>tonkatsu"]), display: next))
        // 모두 끝냄: 지역 끝 표지까지 실선.
        let end = try #require(route.region.sections.last?.paths.first)
        #expect(route.isPassed(end, display: MapDisplay(index: 24)))
        #expect(!route.isPassed(end, display: MapDisplay(index: 23)))
    }

    // MARK: 다음 칸과 깡충 계획

    @Test func oneStepHop() throws {
        let route = try route()
        #expect(route.transition(from: "sushi-a", to: "sushi-b", maxChain: 3) == .hops([MapHop(to: .node("sushi-b"), kind: .step)]))
        #expect(route.transition(from: "sushi-b", to: "sushi-quiz", maxChain: 3) == .hops([MapHop(to: .node("sushi-quiz"), kind: .step)]))
    }

    @Test func sceneCrossingGoesThroughBuildingFront() throws {
        let route = try route()
        #expect(route.transition(from: "sushi-quiz", to: "tonkatsu-a", maxChain: 3) == .hops([
            MapHop(to: .front("tonkatsu"), kind: .scene),
            MapHop(to: .node("tonkatsu-a"), kind: .scene),
        ]))
        #expect(route.transition(from: "ryokan-quiz", to: "hiragana-end", maxChain: 3) == .hops([
            MapHop(to: .node("hiragana-end"), kind: .step),
        ]))
    }

    @Test func chainedHops() throws {
        let route = try route()
        // a → b → 퀴즈 → 다음 a (가장 긴 경우, 4.4).
        #expect(route.transition(from: "sushi-a", to: "tonkatsu-a", maxChain: 3) == .hops([
            MapHop(to: .node("sushi-b"), kind: .step),
            MapHop(to: .node("sushi-quiz"), kind: .step),
            MapHop(to: .front("tonkatsu"), kind: .scene),
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
