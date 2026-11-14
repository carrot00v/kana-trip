import Foundation
import Observation

// 진도 저장 계층. 화면 코드는 `ProgressStore`의 메서드만 부르고,
// 실제 저장은 `ProgressStorage`가 맡는다. 나중에 동기화를 붙일 때는 `ProgressStorage` 구현을 바꾼다.

enum SessionKind: String, Codable, CaseIterable {
    case learn
    case quiz
    case words

    var next: SessionKind? {
        switch self {
        case .learn: .quiz
        case .quiz: .words
        case .words: nil
        }
    }

    var previous: SessionKind? {
        switch self {
        case .learn: nil
        case .quiz: .learn
        case .words: .quiz
        }
    }
}

/// 퀴즈 세션의 진행 위치. 큐의 맨 앞이 다음에 낼 항목이고, 틀린 항목은 큐의 끝으로 간다.
struct QuizProgress: Codable, Equatable {
    var choiceQueue: [String]
    var choiceDone: [String] = []
    var writeQueue: [String]
    var writeDone: [String] = []
    /// 한 번이라도 답했는지. "이어서 하기" 표시에 쓴다.
    var touched = false

    var doneCount: Int { choiceDone.count + writeDone.count }
}

struct SceneProgress: Codable, Equatable {
    var completed: Set<SessionKind> = []
    /// 배우기에서 끝낸 글자.
    var learnDone: [String] = []
    var quiz: QuizProgress?
    /// 단어 읽기에서 끝낸 단어.
    var wordsDone: [String] = []
    /// 사지선다에서 틀렸거나 기억으로 쓰기에서 가이드를 본 글자.
    var wrongKana: [String] = []
}

struct ProgressState: Codable, Equatable {
    /// 저장 형식 버전. 장면 id나 글자 배정이 바뀌어 예전 진도가 맞지 않게 되면 올린다.
    /// 1: 장면 1이 공항(よ う こ そ く)이던 때. 2: 장면 1이 밥집 간판(す し と ん か つ).
    /// 3: 장면 2~8 재배정, 옛 밥집(eatery) 장면을 빼고 이자카야(izakaya) 추가.
    static let currentVersion = 3

    var version = ProgressState.currentVersion
    var soundOn = false
    var scenes: [String: SceneProgress] = [:]
    /// 엔과 아이템 (docs/content/reward-system.md 7번). 버전이 바뀌어 진도를 비워도 남긴다.
    var rewards = RewardState()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, soundOn, scenes, rewards
    }

    /// 키마다 따로 읽는다. `rewards`가 없는 예전 파일도 진도를 그대로 읽고,
    /// 진도(`scenes`)를 읽지 못하면 버전을 0으로 두어 진도만 비우고 엔과 아이템은 남긴다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 0
        soundOn = (try? c.decodeIfPresent(Bool.self, forKey: .soundOn)) ?? false
        rewards = (try? c.decodeIfPresent(RewardState.self, forKey: .rewards)) ?? RewardState()
        if let scenes = try? c.decodeIfPresent([String: SceneProgress].self, forKey: .scenes) {
            self.scenes = scenes
        } else {
            scenes = [:]
            version = 0
        }
    }

    /// 세 세션을 모두 끝낸 장면 id.
    var completedSceneIDs: Set<String> {
        Set(scenes.filter { $0.value.completed.count == SessionKind.allCases.count }.keys)
    }
}

protocol ProgressStorage {
    func load() -> ProgressState?
    func save(_ state: ProgressState)
}

/// 앱의 Application Support 폴더에 JSON 파일 하나로 저장한다.
struct FileProgressStorage: ProgressStorage {
    private let url: URL

    init(fileName: String = "progress.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent(fileName)
    }

    func load() -> ProgressState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ProgressState.self, from: data)
    }

    func save(_ state: ProgressState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

@Observable
final class ProgressStore {
    private(set) var state: ProgressState
    @ObservationIgnored private let storage: ProgressStorage
    @ObservationIgnored let rewardCatalog: RewardCatalog

    init(
        storage: ProgressStorage = FileProgressStorage(),
        rewardCatalog: RewardCatalog = .bundled(hiraganaSceneIDs: ContentLibrary.shared.scenes.map(\.id))
    ) {
        self.storage = storage
        self.rewardCatalog = rewardCatalog
        let loaded = storage.load()
        var state = Self.migrated(loaded)
        // 완료했는데 지급하지 않은 지점에 지급하고, 목록에 없는 아이템을 입은 슬롯을 되돌린다 (reward-system.md 6.2, 6.3).
        _ = RewardRules.reconcile(
            completedSessions: state.scenes.mapValues(\.completed),
            state: &state.rewards,
            catalog: rewardCatalog
        )
        state.rewards = RewardRules.sanitized(state.rewards, catalog: rewardCatalog)
        self.state = state
        if loaded != state { storage.save(state) }
    }

    /// 버전이 다른 진도는 장면 진행을 비우고 새로 시작한다. 공개 전이라 옮겨 담지 않는다.
    /// 소리 설정과 엔·아이템은 남긴다 (reward-system.md 6.3). 비운 결과는 바로 저장해 예전 장면 id가 남지 않게 한다.
    private static func migrated(_ loaded: ProgressState?) -> ProgressState {
        guard let loaded else { return ProgressState() }
        guard loaded.version != ProgressState.currentVersion else { return loaded }
        var fresh = ProgressState()
        fresh.soundOn = loaded.soundOn
        fresh.rewards = loaded.rewards
        return fresh
    }

    // MARK: - 설정

    var soundOn: Bool {
        get { state.soundOn }
        set {
            state.soundOn = newValue
            storage.save(state)
        }
    }

    // MARK: - 조회

    func progress(for sceneID: String) -> SceneProgress {
        state.scenes[sceneID] ?? SceneProgress()
    }

    func isCompleted(_ kind: SessionKind, sceneID: String) -> Bool {
        progress(for: sceneID).completed.contains(kind)
    }

    func completedCount(sceneID: String) -> Int {
        progress(for: sceneID).completed.count
    }

    func isSceneCompleted(sceneID: String) -> Bool {
        completedCount(sceneID: sceneID) == SessionKind.allCases.count
    }

    /// 세션은 배우기 → 퀴즈 → 단어 읽기 순서로 열린다.
    func isUnlocked(_ kind: SessionKind, sceneID: String) -> Bool {
        guard let previous = kind.previous else { return true }
        return isCompleted(previous, sceneID: sceneID)
    }

    /// 다음에 할 세션. 세 세션을 모두 끝냈으면 nil.
    func nextSession(sceneID: String) -> SessionKind? {
        SessionKind.allCases.first { !isCompleted($0, sceneID: sceneID) }
    }

    /// 끝낸 항목 수.
    func doneCount(_ kind: SessionKind, sceneID: String) -> Int {
        let p = progress(for: sceneID)
        switch kind {
        case .learn: return p.learnDone.count
        case .quiz: return p.quiz?.doneCount ?? 0
        case .words: return p.wordsDone.count
        }
    }

    /// 끝내지 않은 세션을 하다가 나갔는지.
    func isInProgress(_ kind: SessionKind, sceneID: String) -> Bool {
        guard !isCompleted(kind, sceneID: sceneID) else { return false }
        let p = progress(for: sceneID)
        switch kind {
        case .learn: return !p.learnDone.isEmpty
        case .quiz: return p.quiz?.touched ?? false
        case .words: return !p.wordsDone.isEmpty
        }
    }

    // MARK: - 세션 시작과 끝

    /// 세션에 들어갈 때 부른다. 이미 끝낸 세션이면 항목 진행을 비우고 처음부터 다시 한다.
    /// - Returns: 다시 하는 세션이면 true. 완료 상태와 틀린 글자 기록은 바뀌지 않는다.
    @discardableResult
    func beginSession(_ kind: SessionKind, sceneID: String, kana: [String]) -> Bool {
        let replay = isCompleted(kind, sceneID: sceneID)
        update(sceneID) { p in
            switch kind {
            case .learn:
                if replay { p.learnDone = [] }
            case .quiz:
                if replay || p.quiz == nil {
                    p.quiz = QuizProgress(choiceQueue: kana.shuffled(), writeQueue: kana.shuffled())
                }
            case .words:
                if replay { p.wordsDone = [] }
            }
        }
        return replay
    }

    /// 세션을 완료로 바꾸고, 같은 저장에서 엔을 주고 아이템을 연다 (reward-system.md 6.2).
    /// - Returns: 이번 지급 결과. 다시 한 세션이면 받은 엔이 0이다.
    @discardableResult
    func completeSession(_ kind: SessionKind, sceneID: String) -> RewardGrant {
        var next = state
        var p = progress(for: sceneID)
        p.completed.insert(kind)
        next.scenes[sceneID] = p
        let grant = RewardRules.grantSession(
            kind, sceneID: sceneID,
            completedScenes: next.completedSceneIDs,
            state: &next.rewards,
            catalog: rewardCatalog
        )
        commit(next)
        return grant
    }

    // MARK: - 항목 진행

    func markLearnDone(_ char: String, sceneID: String) {
        update(sceneID) { p in
            if !p.learnDone.contains(char) { p.learnDone.append(char) }
        }
    }

    /// 사지선다 한 문항의 결과. 틀린 문항은 큐의 끝으로 보내 다시 낸다.
    func answerChoice(_ char: String, correct: Bool, sceneID: String, recordWrong: Bool) {
        update(sceneID) { p in
            guard var quiz = p.quiz else { return }
            quiz.touched = true
            quiz.choiceQueue.removeAll { $0 == char }
            if correct {
                if !quiz.choiceDone.contains(char) { quiz.choiceDone.append(char) }
            } else {
                quiz.choiceQueue.append(char)
                if recordWrong, !p.wrongKana.contains(char) { p.wrongKana.append(char) }
            }
            p.quiz = quiz
        }
    }

    /// 기억으로 쓰기에서 가이드를 본 시점에 부른다. 글자를 완성하기 전에 나가도 기록이 남는다.
    func markGuideUsed(_ char: String, sceneID: String, recordWrong: Bool) {
        update(sceneID) { p in
            p.quiz?.touched = true
            if recordWrong, !p.wrongKana.contains(char) { p.wrongKana.append(char) }
        }
    }

    /// 기억으로 쓰기 한 글자의 결과. 가이드를 본 글자는 큐의 끝으로 보내 다시 낸다.
    func finishWrite(_ char: String, usedGuide: Bool, sceneID: String) {
        update(sceneID) { p in
            guard var quiz = p.quiz else { return }
            quiz.touched = true
            quiz.writeQueue.removeAll { $0 == char }
            if usedGuide {
                quiz.writeQueue.append(char)
            } else if !quiz.writeDone.contains(char) {
                quiz.writeDone.append(char)
            }
            p.quiz = quiz
        }
    }

    func markWordDone(_ text: String, sceneID: String) {
        update(sceneID) { p in
            if !p.wordsDone.contains(text) { p.wordsDone.append(text) }
        }
    }

    // MARK: - 리워드

    var rewards: RewardState { state.rewards }

    /// 지금 살 수 있는 아이템이 있는지. 홈의 기리 행과 장면 완료의 "기리 꾸미기"에 쓴다.
    var canBuyAnyItem: Bool {
        !RewardRules.buyableItems(state: state.rewards, catalog: rewardCatalog).isEmpty
    }

    /// 사기: 잔액 차감, 아이템 추가, 착용을 한 번에 저장한다.
    func buy(_ item: RewardItem) -> RewardRules.PurchaseResult {
        var next = state
        let result = RewardRules.purchase(item, state: &next.rewards)
        if result == .bought { commit(next) }
        return result
    }

    func equip(_ item: RewardItem) {
        var next = state
        if RewardRules.equip(item, state: &next.rewards) { commit(next) }
    }

    func clearSlot(_ slot: RewardSlot) {
        var next = state
        RewardRules.clear(slot, state: &next.rewards)
        commit(next)
    }

    func resetOutfit() {
        var next = state
        RewardRules.resetOutfit(state: &next.rewards, catalog: rewardCatalog)
        commit(next)
    }

    // MARK: - 저장

    private func commit(_ next: ProgressState) {
        guard next != state else { return }
        state = next
        storage.save(state)
    }

    private func update(_ sceneID: String, _ body: (inout SceneProgress) -> Void) {
        var p = progress(for: sceneID)
        body(&p)
        guard p != state.scenes[sceneID] else { return }
        state.scenes[sceneID] = p
        storage.save(state)
    }
}
