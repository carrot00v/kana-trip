import Foundation
import Observation

// 진도 저장 계층. 화면 코드는 `ProgressStore`와 `SessionRun`의 메서드만 부르고,
// 실제 저장은 `ProgressStorage`가 맡는다. 나중에 동기화를 붙일 때는 `ProgressStorage` 구현을 바꾼다.

/// 세션 안의 구간. 단계 세션은 배우기 → 단어 읽기, 종합 퀴즈 세션은 퀴즈 하나다.
enum SessionPart: Int, Codable, CaseIterable {
    case learn
    case quiz
    case words
}

/// 종합 퀴즈의 문항 유형. 유형마다 화면과 판정이 다르고, 퀴즈는 유형별 부(part)를 차례로 푼다.
/// 유형을 더하거나 빼려면 여기에 case를 두고 `QuizPlan`과 `QuizSessionView`에 화면을 잇는다.
/// 최종 유형·문항 수·통과 기준은 docs/content/quiz-rules.md(작성 중)를 따른다.
enum QuizKind: String, Codable, CaseIterable {
    /// (가) 글자 보고 발음 고르기 (사지선다).
    case readingChoice
    /// (다) 발음 보고 가이드 없이 기억으로 쓰기.
    case recallWrite
    // 예정: (나) 발음 보고 글자 고르기, (라) 단어 보고 읽기 또는 뜻 고르기.
}

/// 종합 퀴즈의 진행 위치. 부마다 큐의 맨 앞이 다음에 낼 항목이고, 틀린 항목은 그 부의 끝으로 간다.
struct QuizProgress: Codable, Equatable {
    struct Part: Codable, Equatable {
        var kind: QuizKind
        /// 문항 대상. 지금 유형은 모두 글자(가나 한 자)다.
        var queue: [String]
        var done: [String] = []
    }

    /// 이 퀴즈에 내는 글자 전부: 장면의 새 글자 + 복습 글자.
    var kana: [String]
    var parts: [Part]
    /// 한 번이라도 답했는지. 다시 들어갈 때 안내(P2)를 건너뛸지 정한다 (scene-flow.md 2.5).
    var touched = false

    var doneCount: Int { parts.reduce(0) { $0 + $1.done.count } }
    /// 다시 나오는 문항은 분모를 늘리지 않는다 (scene-flow.md 7.2).
    var totalCount: Int { parts.reduce(0) { $0 + Set($1.done + $1.queue).count } }
    var isFinished: Bool { parts.allSatisfy(\.queue.isEmpty) }
    /// 지금 풀 부의 자리. 다 끝났으면 nil.
    var currentPartIndex: Int? { parts.firstIndex { !$0.queue.isEmpty } }
}

/// 문항 구성. 지금은 뼈대로 (가) 사지선다 → (다) 기억으로 쓰기, 각 부에 퀴즈 글자 전부를 섞어 낸다.
enum QuizPlan {
    static let kinds: [QuizKind] = [.readingChoice, .recallWrite]

    static func make(kana: [String]) -> QuizProgress {
        QuizProgress(kana: kana, parts: kinds.map { QuizProgress.Part(kind: $0, queue: kana.shuffled()) })
    }
}

/// 세션 하나의 진행. 항목 단위로 저장한다 (scene-flow.md 2.5, 16번).
struct SessionProgress: Codable, Equatable {
    var completed = false
    /// 배우기에서 끝낸 글자 (단계 세션).
    var learnDone: [String] = []
    /// 단어 읽기에서 끝낸 단어 (단계 세션).
    var wordsDone: [String] = []
    /// 종합 퀴즈 진행. 퀴즈 안내(P2)에서 만든다.
    var quiz: QuizProgress?
    /// 이 퀴즈에서 틀린 글자(복습 글자를 다시 틀린 것 포함).
    var quizWrong: [String] = []

    /// 끝내지 않은 세션을 하다가 나갔는지.
    var isStarted: Bool { !completed && (!learnDone.isEmpty || quiz?.touched == true || !wordsDone.isEmpty) }
}

struct ProgressState: Codable, Equatable {
    /// 저장 형식 버전. 장면 id나 글자 배정, 진도 단위가 바뀌어 예전 진도가 맞지 않게 되면 올린다.
    /// 1: 장면 1이 공항(よ う こ そ く)이던 때. 2: 장면 1이 밥집 간판(す し と ん か つ).
    /// 3: 장면 2~8 재배정, 옛 밥집(eatery) 장면을 빼고 이자카야(izakaya) 추가.
    /// 4: 흐름 개편안 B. 장면 8개 × 세션 3개(단계 a, 단계 b, 종합 퀴즈), 진도를 세션 id(`sushi-a`, `sushi-quiz`) 단위로 저장.
    static let currentVersion = 4

    var version = ProgressState.currentVersion
    var soundOn = false
    /// 세션 id → 진행.
    var sessions: [String: SessionProgress] = [:]
    /// 장면 id → 그 장면 종합 퀴즈에서 틀린 글자. 다음 장면의 종합 퀴즈에 섞는다.
    var wrongKana: [String: [String]] = [:]
    /// 엔과 아이템 (docs/content/reward-system.md 7번). 버전이 바뀌어 진도를 비워도 남긴다.
    var rewards = RewardState()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, soundOn, sessions, wrongKana, rewards
    }

    /// 키마다 따로 읽는다. 예전 형식(버전 3 이하, `scenes` 키)도 소리 설정과 엔·아이템은 읽고 진도만 비운다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 0
        soundOn = (try? c.decodeIfPresent(Bool.self, forKey: .soundOn)) ?? false
        rewards = (try? c.decodeIfPresent(RewardState.self, forKey: .rewards)) ?? RewardState()
        wrongKana = (try? c.decodeIfPresent([String: [String]].self, forKey: .wrongKana)) ?? [:]
        if let sessions = try? c.decodeIfPresent([String: SessionProgress].self, forKey: .sessions) {
            self.sessions = sessions
        } else {
            sessions = [:]
            version = 0
        }
    }

    var completedSessionIDs: Set<String> {
        Set(sessions.filter(\.value.completed).keys)
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
    /// 종합 퀴즈에 섞는 앞 장면 복습 글자 수의 상한. PLAN.md 8번 미정 항목의 임시값.
    static let reviewKanaLimit = 3

    private(set) var state: ProgressState
    @ObservationIgnored private let storage: ProgressStorage
    @ObservationIgnored let rewardCatalog: RewardCatalog
    @ObservationIgnored private let library: ContentLibrary

    init(
        storage: ProgressStorage = FileProgressStorage(),
        library: ContentLibrary = .shared,
        rewardCatalog: RewardCatalog? = nil
    ) {
        self.storage = storage
        self.library = library
        let catalog = rewardCatalog ?? .bundled(hiraganaScenes: library.scenes.map { scene in
            (scene.id, library.sessions(in: scene).map(\.id))
        })
        self.rewardCatalog = catalog
        let loaded = storage.load()
        var state = Self.migrated(loaded)
        // 완료했는데 지급하지 않은 지점에 지급하고, 목록에 없는 아이템을 입은 슬롯을 되돌린다 (reward-system.md 6.2, 6.3).
        _ = RewardRules.settle(completedSessions: state.completedSessionIDs, state: &state.rewards, catalog: catalog)
        state.rewards = RewardRules.sanitized(state.rewards, catalog: catalog)
        self.state = state
        if loaded != state { storage.save(state) }
    }

    /// 버전이 다른 진도는 비우고 새로 시작한다. 공개 전이라 옮겨 담지 않는다.
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

    func progress(for sessionID: String) -> SessionProgress {
        state.sessions[sessionID] ?? SessionProgress()
    }

    func isCompleted(_ session: TripSession) -> Bool {
        progress(for: session.id).completed
    }

    func isCompleted(_ step: TripStep) -> Bool {
        progress(for: step.id).completed
    }

    func isInProgress(_ session: TripSession) -> Bool {
        progress(for: session.id).isStarted
    }

    func completedSessionCount(_ scene: TripScene) -> Int {
        library.sessions(in: scene).count { isCompleted($0) }
    }

    /// 장면 완료 = 종합 퀴즈까지 세션 3개를 모두 끝냄.
    func isSceneCompleted(_ scene: TripScene) -> Bool {
        let sessions = library.sessions(in: scene)
        return !sessions.isEmpty && sessions.allSatisfy(isCompleted)
    }

    /// 세션은 1a → 1b → 1퀴즈 → 2a … 순서로 하나씩 열린다.
    func isUnlocked(_ session: TripSession) -> Bool {
        guard let previous = library.sessions.last(where: { $0.globalIndex < session.globalIndex }) else { return true }
        return isCompleted(previous)
    }

    func isSceneUnlocked(_ scene: TripScene) -> Bool {
        guard let first = library.sessions(in: scene).first else { return false }
        return isUnlocked(first)
    }

    /// 장면에서 다음에 할 세션. 모두 끝냈거나 잠겨 있으면 nil.
    func nextSession(in scene: TripScene) -> TripSession? {
        guard let session = library.sessions(in: scene).first(where: { !isCompleted($0) }), isUnlocked(session) else { return nil }
        return session
    }

    func wrongKana(sceneID: String) -> [String] {
        state.wrongKana[sceneID] ?? []
    }

    /// 배운 글자 (scene-flow.md 4.4): 앞 장면들의 새 글자 전부 + 이 장면에서 배우기를 끝낸 단계의 글자 전부
    /// + 배우기 도중인 단계의 끝낸 글자. 끝낸 세션을 다시 하는 동안에도 줄지 않는다(다시 하는 진행은 저장하지 않으므로).
    func learnedKana(in scene: TripScene) -> Set<String> {
        var learned = library.kana(before: scene)
        for step in scene.steps {
            let p = progress(for: step.id)
            if p.completed || Set(step.kana).isSubset(of: p.learnDone) {
                learned.formUnion(step.kana)
            } else {
                learned.formUnion(p.learnDone)
            }
        }
        return learned
    }

    /// 종합 퀴즈에 섞을 복습 글자: 바로 앞 장면 종합 퀴즈에서 틀린 글자, 틀린 순서로 최대 `reviewKanaLimit`자.
    func reviewKana(for scene: TripScene) -> [String] {
        guard let previous = library.scene(before: scene) else { return [] }
        return Array(wrongKana(sceneID: previous.id).filter { !scene.kana.contains($0) }.prefix(Self.reviewKanaLimit))
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

    // MARK: - 쓰기 (SessionRun이 부른다)

    fileprivate func save(_ progress: SessionProgress, sessionID: String) {
        guard state.sessions[sessionID] != progress else { return }
        var next = state
        next.sessions[sessionID] = progress
        commit(next)
    }

    fileprivate func recordWrong(_ char: String, sceneID: String) {
        var list = wrongKana(sceneID: sceneID)
        guard !list.contains(char) else { return }
        list.append(char)
        var next = state
        next.wrongKana[sceneID] = list
        commit(next)
    }

    /// 세션 완료를 저장하고, 같은 저장에서 엔을 주고 아이템을 연다 (reward-system.md 6.2).
    /// 재화 지급 키는 세션 id(`sushi-a`, `sushi-b`, `sushi-quiz`)다. 항목 진행은 비우고 틀린 글자만 남긴다.
    /// - Returns: 이번 지급 결과. 처음 끝낸 세션이 아니면 받은 엔이 0이다.
    fileprivate func complete(_ session: TripSession, quizWrong: [String]) -> RewardGrant {
        var next = state
        var done = SessionProgress()
        done.completed = true
        done.quizWrong = quizWrong
        next.sessions[session.id] = done
        let grant = RewardRules.settle(completedSessions: next.completedSessionIDs, state: &next.rewards, catalog: rewardCatalog)
        commit(next)
        return grant
    }

    private func commit(_ next: ProgressState) {
        guard next != state else { return }
        state = next
        storage.save(state)
    }
}

/// 세션 하나를 진행하는 동안의 상태.
/// 처음 하는 세션은 항목마다 `ProgressStore`에 저장하고, 끝낸 세션을 다시 할 때는 메모리에만 두고 버린다 (scene-flow.md 2.5, 17번 결정 6).
@Observable
final class SessionRun {
    let session: TripSession
    let scene: TripScene
    /// 이미 끝낸 세션을 다시 하는 중인지. 진행, 완료 상태, 틀린 글자 기록, 엔을 바꾸지 않는다.
    let isReplay: Bool
    private(set) var progress: SessionProgress
    @ObservationIgnored private let store: ProgressStore
    @ObservationIgnored private let library: ContentLibrary

    init(session: TripSession, store: ProgressStore, library: ContentLibrary = .shared) {
        self.session = session
        self.scene = library.scene(of: session)!
        self.store = store
        self.library = library
        isReplay = store.isCompleted(session)
        progress = isReplay ? SessionProgress() : store.progress(for: session.id)
    }

    var step: TripStep? { session.step }

    // MARK: 다시 들어갈 자리 (scene-flow.md 2.5 표)

    enum Entry {
        case learn, wordsIntro, words, quizIntro, quiz
    }

    var entry: Entry {
        guard let step else {
            return progress.quiz?.touched == true ? .quiz : .quizIntro
        }
        guard Set(step.kana).isSubset(of: progress.learnDone) else { return .learn }
        return progress.wordsDone.isEmpty ? .wordsIntro : .words
    }

    /// 복습 글자: 퀴즈 글자 가운데 이 장면의 새 글자가 아닌 것.
    var reviewKana: [String] {
        (progress.quiz?.kana ?? []).filter { !scene.kana.contains($0) }
    }

    /// 단어 읽기 순서: 목표 단어(데이터 순서) → 못 읽는 단어(데이터 순서) (scene-flow.md 12번).
    var orderedWords: [TripWord] {
        guard let step else { return [] }
        let groups = library.wordGroups(for: step)
        return groups.goal + groups.rest
    }

    // MARK: 배우기

    func markLearnDone(_ char: String) {
        mutate { p in
            if !p.learnDone.contains(char) { p.learnDone.append(char) }
        }
    }

    // MARK: 종합 퀴즈

    /// 퀴즈 문항을 만든다. 복습 글자는 이때 정해 함께 저장한다.
    func prepareQuiz() {
        guard step == nil, progress.quiz == nil else { return }
        let kana = scene.kana + store.reviewKana(for: scene)
        mutate { $0.quiz = QuizPlan.make(kana: kana) }
    }

    /// 지금 부의 한 문항 결과. 틀렸으면(가이드를 본 쓰기 포함) 그 부의 끝으로 보내 다시 낸다.
    func answer(_ char: String, correct: Bool) {
        if !correct { recordWrong(char) }
        mutate { p in
            guard var quiz = p.quiz, let index = quiz.currentPartIndex else { return }
            quiz.touched = true
            quiz.parts[index].queue.removeAll { $0 == char }
            if correct {
                if !quiz.parts[index].done.contains(char) { quiz.parts[index].done.append(char) }
            } else {
                quiz.parts[index].queue.append(char)
            }
            p.quiz = quiz
        }
    }

    /// 기억으로 쓰기에서 가이드를 본 시점에 부른다. 글자를 완성하기 전에 나가도 기록이 남는다.
    func markGuideUsed(_ char: String) {
        recordWrong(char)
        mutate { $0.quiz?.touched = true }
    }

    // MARK: 단어 읽기

    func markWordDone(_ text: String) {
        mutate { p in
            if !p.wordsDone.contains(text) { p.wordsDone.append(text) }
        }
    }

    /// 세션 완료. 처음 끝낸 세션만 저장하고 엔을 받는다.
    func complete() -> RewardGrant {
        progress.completed = true
        guard !isReplay else {
            var none = RewardGrant()
            none.balance = store.rewards.coins
            return none
        }
        return store.complete(session, quizWrong: progress.quizWrong)
    }

    // MARK: 저장

    private func recordWrong(_ char: String) {
        if !progress.quizWrong.contains(char) { progress.quizWrong.append(char) }
        if !isReplay { store.recordWrong(char, sceneID: scene.id) }
        persist()
    }

    private func mutate(_ body: (inout SessionProgress) -> Void) {
        body(&progress)
        persist()
    }

    private func persist() {
        guard !isReplay else { return }
        store.save(progress, sessionID: session.id)
    }
}
