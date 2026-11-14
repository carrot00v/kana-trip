import Foundation

/// 장면에 실리는 단어 하나.
struct TripWord: Decodable, Identifiable {
    struct Unit: Decodable {
        let kana: String
        let romaji: String
        /// 현지 표기대로 붙여 쓴 한자(かつ丼의 丼 등). 가르치지 않고, 배운 글자 계산에서 빠지며, 늘 발음을 위에 표기한다.
        let kanji: Bool?

        var isKanji: Bool { kanji == true }
    }

    let text: String
    /// 글자 하나씩의 발음. 아직 배우지 않은 글자 위에 표기할 때 쓴다.
    let units: [Unit]
    let reading: String
    let meaning: String
    /// 확인 후에 보이는 보조 설명(어디서 보는지, 장음 안내). 없는 단어도 있다.
    let note: String?

    var id: String { text }

    /// 한자 칸을 뺀 가나 칸. 읽을 수 있는지와 채워진 정도는 이 칸들로만 계산한다.
    /// 탁음·반탁음 글자와 っ는 46자에 들지 않으므로 늘 "못 읽는 글자"로 남는다.
    var kanaUnits: [Unit] { units.filter { !$0.isKanji } }
}

/// 장면 안의 단계 하나(간판, 메뉴 등). 단계 하나가 세션 하나다 (PLAN.md 5번).
struct TripStep: Decodable, Identifiable, Hashable {
    /// `{장면 id}-a`, `{장면 id}-b`. 진도 저장 키이고, 보상 브랜치의 재화 지급 키도 이 값이다.
    let id: String
    let name: String
    /// 새 글자. 배우는 순서다.
    let kana: [String]
    /// 단어. 데이터 순서다.
    let words: [TripWord]

    /// 장면 id. 데이터를 읽은 뒤 채운다.
    fileprivate(set) var sceneID = ""
    /// 장면 안에서의 자리. 0이 단계 a.
    fileprivate(set) var index = 0
    /// 히라가나 전체에서의 순서(1a = 0, 1b = 1, 2a = 2 …). 배운 글자를 누적할 때 쓴다.
    fileprivate(set) var globalIndex = 0

    var hasContent: Bool { !words.isEmpty }
    /// VoiceOver와 아이콘에 쓰는 단계 번호(1, 2).
    var number: Int { index + 1 }

    private enum CodingKeys: String, CodingKey {
        case id, name, kana, words
    }

    static func == (lhs: TripStep, rhs: TripStep) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 세션 하나. 장면마다 단계 a 세션, 단계 b 세션, 종합 퀴즈 세션의 3개다.
/// 진도 저장 키와 보상 지급 키가 `id`다: `{장면 id}-a`, `{장면 id}-b`, `{장면 id}-quiz`.
struct TripSession: Identifiable, Hashable {
    enum Kind: Hashable {
        /// 단계 세션: 배우기 → 단어 읽기.
        case step(TripStep)
        /// 종합 퀴즈: 장면 글자 전부 + 앞 장면 복습 글자.
        case quiz
    }

    let id: String
    let sceneID: String
    let kind: Kind
    /// 장면 안의 순서(1, 2, 3).
    let number: Int
    /// 히라가나 전체에서의 순서. 열리는 순서를 정한다.
    let globalIndex: Int

    var step: TripStep? {
        if case .step(let step) = kind { return step }
        return nil
    }

    var isQuiz: Bool { step == nil }

    static func quizID(sceneID: String) -> String { "\(sceneID)-quiz" }
}

/// 장면 하나. 단계 2개로 나뉜다.
struct TripScene: Decodable, Identifiable {
    let id: String
    let order: Int
    let name: String
    /// SF Symbols 이름. 글자 소개의 단어 카드와 큰 글자 크기의 홈에서 쓴다.
    let icon: String?
    fileprivate(set) var steps: [TripStep]

    /// 장면의 새 글자. 단계 글자를 순서대로 이은 것이다.
    var kana: [String] { steps.flatMap(\.kana) }
    var words: [TripWord] { steps.flatMap(\.words) }
    var hasContent: Bool { steps.contains { $0.hasContent } }

    /// 장면 그림 에셋 이름 (docs/design/scene-art/brief.md 7번).
    var thumbnailName: String { "SceneThumb-\(id)" }
    static let placeholderThumbnailName = "SceneThumb-placeholder"
}

/// 번들에 든 장면·글자 데이터. 앱이 켜질 때 한 번 읽는다.
final class ContentLibrary {
    static let shared = ContentLibrary()

    let sectionTitle: String
    let scenes: [TripScene]
    /// 모든 단계를 1a → 1b → 2a → … 순서로.
    let steps: [TripStep]
    /// 모든 세션을 1a → 1b → 1퀴즈 → 2a → … 순서로.
    let sessions: [TripSession]
    private let kanaByChar: [String: Kana]
    /// 글자 → 그 글자를 새로 배우는 단계.
    private let stepByKana: [String: TripStep]

    private struct File: Decodable {
        let title: String
        let scenes: [TripScene]
    }

    private init() {
        let all = KanaStrokeStore.loadHiragana()
        kanaByChar = Dictionary(all.map { ($0.char, $0) }, uniquingKeysWith: { first, _ in first })

        if let url = Bundle.main.url(forResource: "hiragana_scenes", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(File.self, from: data) {
            sectionTitle = file.title
            var scenes = file.scenes.sorted { $0.order < $1.order }
            var global = 0
            for s in scenes.indices {
                for i in scenes[s].steps.indices {
                    scenes[s].steps[i].sceneID = scenes[s].id
                    scenes[s].steps[i].index = i
                    scenes[s].steps[i].globalIndex = global
                    global += 1
                }
            }
            self.scenes = scenes
        } else {
            assertionFailure("hiragana_scenes.json을 읽지 못함")
            sectionTitle = ""
            scenes = []
        }
        steps = scenes.flatMap(\.steps)
        var sessions: [TripSession] = []
        for scene in scenes {
            for step in scene.steps {
                sessions.append(TripSession(id: step.id, sceneID: scene.id, kind: .step(step), number: step.number, globalIndex: sessions.count))
            }
            sessions.append(TripSession(id: TripSession.quizID(sceneID: scene.id), sceneID: scene.id, kind: .quiz,
                                        number: scene.steps.count + 1, globalIndex: sessions.count))
        }
        self.sessions = sessions
        var byKana: [String: TripStep] = [:]
        for step in steps {
            for char in step.kana where byKana[char] == nil { byKana[char] = step }
        }
        stepByKana = byKana
    }

    // MARK: - 장면과 단계 찾기

    func scene(id: String) -> TripScene? {
        scenes.first { $0.id == id }
    }

    func scene(of step: TripStep) -> TripScene? {
        scene(id: step.sceneID)
    }

    func scene(after scene: TripScene) -> TripScene? {
        scenes.first { $0.order == scene.order + 1 }
    }

    func scene(before scene: TripScene) -> TripScene? {
        scenes.first { $0.order == scene.order - 1 }
    }

    func step(id: String) -> TripStep? {
        steps.first { $0.id == id }
    }

    /// 같은 장면의 다음 단계. 단계 b면 nil.
    func step(after step: TripStep) -> TripStep? {
        scene(of: step)?.steps.first { $0.index == step.index + 1 }
    }

    func session(id: String) -> TripSession? {
        sessions.first { $0.id == id }
    }

    func sessions(in scene: TripScene) -> [TripSession] {
        sessions.filter { $0.sceneID == scene.id }
    }

    /// 같은 장면의 다음 세션. 종합 퀴즈면 nil.
    func session(after session: TripSession) -> TripSession? {
        sessions.first { $0.sceneID == session.sceneID && $0.number == session.number + 1 }
    }

    func scene(of session: TripSession) -> TripScene? {
        scene(id: session.sceneID)
    }

    /// 글자를 새로 배우는 단계.
    func homeStep(of char: String) -> TripStep? {
        stepByKana[char]
    }

    // MARK: - 글자

    func kana(_ char: String) -> Kana? {
        kanaByChar[char]
    }

    /// 단계의 새 글자를 획 데이터와 함께 돌려준다.
    func kana(for step: TripStep) -> [Kana] {
        step.kana.compactMap { kanaByChar[$0] }
    }

    /// 이 단계보다 앞 단계들(앞 장면 전부 + 같은 장면의 앞 단계)의 새 글자.
    func kana(before step: TripStep) -> Set<String> {
        Set(steps.filter { $0.globalIndex < step.globalIndex }.flatMap(\.kana))
    }

    /// 이 단계까지의 글자: 앞 단계들의 새 글자 + 이 단계의 새 글자 (scene-flow.md 4.4).
    /// 단어 읽기의 발음 표기와 목표 단어를 정할 때 쓴다. 탁음·한자는 들지 않는다.
    func kana(through step: TripStep) -> Set<String> {
        kana(before: step).union(step.kana)
    }

    /// 이 장면보다 앞 장면들의 새 글자.
    func kana(before scene: TripScene) -> Set<String> {
        Set(scenes.filter { $0.order < scene.order }.flatMap(\.kana))
    }
}
