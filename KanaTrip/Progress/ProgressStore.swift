import Foundation
import Observation

// 진도 저장 계층. 화면 코드는 `ProgressStore`와 `StepRun`의 메서드만 부르고,
// 실제 저장은 `ProgressStorage`가 맡는다. 나중에 동기화를 붙일 때는 `ProgressStorage` 구현을 바꾼다.

/// 세션(단계 하나) 안의 구간. 배우기 → 퀴즈 → 단어 읽기 순서로만 진행한다.
enum SessionPart: Int, Codable, CaseIterable {
    case learn
    case quiz
    case words
}

/// 퀴즈 구간의 진행 위치. 큐의 맨 앞이 다음에 낼 항목이고, 틀린 항목은 큐의 끝으로 간다.
struct QuizProgress: Codable, Equatable {
    /// 이 퀴즈에 내는 글자 전부: 단계의 새 글자 + 복습 글자. 진행 막대의 분모(2배)로 쓴다.
    var kana: [String]
    var choiceQueue: [String]
    var choiceDone: [String] = []
    var writeQueue: [String]
    var writeDone: [String] = []
    /// 한 번이라도 답했는지. 다시 들어갈 때 P2를 건너뛸지 정한다 (scene-flow.md 2.5).
    var touched = false

    init(kana: [String]) {
        self.kana = kana
        choiceQueue = kana.shuffled()
        writeQueue = kana.shuffled()
    }

    var doneCount: Int { choiceDone.count + writeDone.count }
    var totalCount: Int { kana.count * 2 }
    var isFinished: Bool { choiceQueue.isEmpty && writeQueue.isEmpty }
}

/// 단계 하나의 진행. 항목 단위로 저장한다 (scene-flow.md 2.5, 16번).
struct StepProgress: Codable, Equatable {
    var completed = false
    /// 배우기에서 끝낸 글자.
    var learnDone: [String] = []
    /// 배우기를 끝내면 만든다. 그 전에는 nil.
    var quiz: QuizProgress?
    /// 단어 읽기에서 끝낸 단어.
    var wordsDone: [String] = []
    /// 이 단계 퀴즈에서 틀린 글자(복습 글자를 다시 틀린 것 포함). P3 안내와 C1의 점에 쓴다.
    var quizWrong: [String] = []

    /// 끝내지 않은 단계를 하다가 나갔는지.
    var isStarted: Bool { !completed && (!learnDone.isEmpty || quiz != nil || !wordsDone.isEmpty) }
}

struct ProgressState: Codable, Equatable {
    /// 저장 형식 버전. 장면 id나 글자 배정, 진도 단위가 바뀌어 예전 진도가 맞지 않게 되면 올린다.
    /// 1: 장면 1이 공항(よ う こ そ く)이던 때. 2: 장면 1이 밥집 간판(す し と ん か つ).
    /// 3: 장면 2~8 재배정, 옛 밥집(eatery) 장면을 빼고 이자카야(izakaya) 추가.
    /// 4: 흐름 개편안 B. 장면 8개 × 단계 2개, 진도를 단계 id(`sushi-a` 등) 단위로 저장.
    static let currentVersion = 4

    var version = ProgressState.currentVersion
    var soundOn = false
    /// 단계 id → 진행.
    var steps: [String: StepProgress] = [:]
    /// 장면 id → 그 장면 퀴즈에서 틀린 글자(두 단계 합침). 다음 장면 단계 a의 퀴즈에 섞는다.
    var wrongKana: [String: [String]] = [:]
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
        // 예전 형식은 키가 달라 그대로 읽히지 않는다. 버전만 읽어 이전 진도로 처리한다.
        if let state = try? JSONDecoder().decode(ProgressState.self, from: data) { return state }
        return try? JSONDecoder().decode(LegacyState.self, from: data).asOutdated
    }

    func save(_ state: ProgressState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// 버전 3 이하 파일에서 버전과 소리 설정만 읽는다.
    private struct LegacyState: Decodable {
        let version: Int?
        let soundOn: Bool?

        var asOutdated: ProgressState {
            var state = ProgressState()
            state.version = version ?? 0
            state.soundOn = soundOn ?? false
            return state
        }
    }
}

@Observable
final class ProgressStore {
    /// 다음 장면 단계 a의 퀴즈에 섞는 복습 글자 수의 상한. PLAN.md 8번 미정 항목의 임시값.
    static let reviewKanaLimit = 3

    private(set) var state: ProgressState
    @ObservationIgnored private let storage: ProgressStorage

    init(storage: ProgressStorage = FileProgressStorage()) {
        self.storage = storage
        let loaded = storage.load()
        state = Self.migrated(loaded)
        if let loaded, loaded != state { storage.save(state) }
    }

    /// 버전이 다른 진도는 비우고 새로 시작한다. 공개 전이라 옮겨 담지 않는다.
    /// 소리 설정만 남긴다. 비운 결과는 바로 저장해 예전 장면 id가 남지 않게 한다.
    private static func migrated(_ loaded: ProgressState?) -> ProgressState {
        guard let loaded else { return ProgressState() }
        guard loaded.version != ProgressState.currentVersion else { return loaded }
        var fresh = ProgressState()
        fresh.soundOn = loaded.soundOn
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

    func progress(for stepID: String) -> StepProgress {
        state.steps[stepID] ?? StepProgress()
    }

    func isCompleted(_ step: TripStep) -> Bool {
        progress(for: step.id).completed
    }

    func isInProgress(_ step: TripStep) -> Bool {
        progress(for: step.id).isStarted
    }

    func completedStepCount(_ scene: TripScene) -> Int {
        scene.steps.count { isCompleted($0) }
    }

    func isSceneCompleted(_ scene: TripScene) -> Bool {
        !scene.steps.isEmpty && scene.steps.allSatisfy(isCompleted)
    }

    /// 단계 a는 앞 장면을 끝내면(장면 1은 처음부터), 단계 b는 같은 장면의 단계 a를 끝내면 열린다.
    func isUnlocked(_ step: TripStep, in library: ContentLibrary = .shared) -> Bool {
        guard let previous = library.steps.last(where: { $0.globalIndex < step.globalIndex }) else { return true }
        return isCompleted(previous)
    }

    func isSceneUnlocked(_ scene: TripScene, in library: ContentLibrary = .shared) -> Bool {
        guard let first = scene.steps.first else { return false }
        return isUnlocked(first, in: library)
    }

    /// 장면에서 다음에 할 단계. 두 단계를 모두 끝냈거나 잠겨 있으면 nil.
    func nextStep(in scene: TripScene) -> TripStep? {
        guard let step = scene.steps.first(where: { !isCompleted($0) }), isUnlocked(step) else { return nil }
        return step
    }

    func wrongKana(sceneID: String) -> [String] {
        state.wrongKana[sceneID] ?? []
    }

    /// 배운 글자 (scene-flow.md 4.4): 앞 장면들의 새 글자 전부 + 이 장면에서 배우기를 끝낸 단계의 글자 전부
    /// + 배우기 도중인 단계의 끝낸 글자. 끝낸 단계를 다시 하는 동안에도 줄지 않는다(다시 하는 진행은 저장하지 않으므로).
    func learnedKana(in scene: TripScene, library: ContentLibrary = .shared) -> Set<String> {
        var learned = library.kana(before: scene)
        for step in scene.steps {
            let p = progress(for: step.id)
            if p.completed || p.quiz != nil || Set(step.kana).isSubset(of: p.learnDone) {
                learned.formUnion(step.kana)
            } else {
                learned.formUnion(p.learnDone)
            }
        }
        return learned
    }

    /// 다음 장면 단계 a의 퀴즈에 섞을 복습 글자: 바로 앞 장면에서 틀린 글자, 틀린 순서로 최대 `reviewKanaLimit`자.
    /// 단계 b와 장면 1에는 섞지 않는다 (scene-flow.md 7.1, hiragana-allocation.md 7.1).
    func reviewKana(for step: TripStep, library: ContentLibrary = .shared) -> [String] {
        guard step.index == 0,
              let scene = library.scene(of: step),
              let previous = library.scene(before: scene)
        else { return [] }
        return Array(wrongKana(sceneID: previous.id).filter { !step.kana.contains($0) }.prefix(Self.reviewKanaLimit))
    }

    // MARK: - 쓰기 (StepRun만 부른다)

    fileprivate func save(_ progress: StepProgress, stepID: String) {
        guard state.steps[stepID] != progress else { return }
        state.steps[stepID] = progress
        storage.save(state)
    }

    fileprivate func recordWrong(_ char: String, sceneID: String) {
        var list = wrongKana(sceneID: sceneID)
        guard !list.contains(char) else { return }
        list.append(char)
        state.wrongKana[sceneID] = list
        storage.save(state)
    }

    /// 단계 완료를 저장한다. 항목 진행은 비우고 이 단계의 틀린 글자만 남긴다.
    /// 장면 완료와 다음 장면이 열리는 것은 이 값에서 계산한다.
    /// 보상: 재화 지급 키는 단계 id(`step.id`)다. 보상 시스템은 별도 브랜치에서 개발 중이라 여기서는 지급하지 않는다.
    /// 보상 브랜치를 합칠 때 이 자리(처음 끝낸 단계만)에서 단계 id로 지급한다.
    fileprivate func complete(_ step: TripStep, quizWrong: [String]) {
        var done = StepProgress()
        done.completed = true
        done.quizWrong = quizWrong
        state.steps[step.id] = done
        storage.save(state)
    }
}

/// 세션 하나(단계 하나)를 진행하는 동안의 상태.
/// 처음 하는 단계는 항목마다 `ProgressStore`에 저장하고, 끝낸 단계를 다시 할 때는 메모리에만 두고 버린다 (scene-flow.md 2.5, 17번 결정 6).
@Observable
final class StepRun {
    let step: TripStep
    let scene: TripScene
    /// 이미 끝낸 단계를 다시 하는 중인지. 진행, 완료 상태, 틀린 글자 기록을 바꾸지 않는다.
    let isReplay: Bool
    private(set) var progress: StepProgress
    @ObservationIgnored private let store: ProgressStore
    @ObservationIgnored private let library: ContentLibrary

    init(step: TripStep, store: ProgressStore, library: ContentLibrary = .shared) {
        self.step = step
        self.scene = library.scene(of: step)!
        self.store = store
        self.library = library
        isReplay = store.isCompleted(step)
        progress = isReplay ? StepProgress() : store.progress(for: step.id)
    }

    // MARK: 다시 들어갈 자리 (scene-flow.md 2.5 표)

    enum Entry {
        case learn, quizIntro, quiz, wordsIntro, words
    }

    var entry: Entry {
        guard Set(step.kana).isSubset(of: progress.learnDone) || progress.quiz != nil else { return .learn }
        guard let quiz = progress.quiz, quiz.isFinished else {
            return progress.quiz?.touched == true ? .quiz : .quizIntro
        }
        return progress.wordsDone.isEmpty ? .wordsIntro : .words
    }

    /// 복습 글자: 퀴즈 글자 가운데 이 단계의 새 글자가 아닌 것.
    var reviewKana: [String] {
        (progress.quiz?.kana ?? []).filter { !step.kana.contains($0) }
    }

    /// 단어 읽기 순서: 목표 단어(데이터 순서) → 못 읽는 단어(데이터 순서) (scene-flow.md 12번).
    var orderedWords: [TripWord] {
        let groups = library.wordGroups(for: step)
        return groups.goal + groups.rest
    }

    // MARK: 배우기

    func markLearnDone(_ char: String) {
        mutate { p in
            if !p.learnDone.contains(char) { p.learnDone.append(char) }
        }
    }

    /// 배우기를 끝내면 퀴즈 문항을 만든다. 복습 글자는 이때 정해 함께 저장한다.
    func finishLearning() {
        guard progress.quiz == nil else { return }
        let review = store.reviewKana(for: step, library: library)
        mutate { $0.quiz = QuizProgress(kana: step.kana + review) }
    }

    // MARK: 퀴즈

    /// 사지선다 한 문항의 결과. 틀린 문항은 큐의 끝으로 보내 다시 낸다.
    func answerChoice(_ char: String, correct: Bool) {
        if !correct { recordWrong(char) }
        mutate { p in
            guard var quiz = p.quiz else { return }
            quiz.touched = true
            quiz.choiceQueue.removeAll { $0 == char }
            if correct {
                if !quiz.choiceDone.contains(char) { quiz.choiceDone.append(char) }
            } else {
                quiz.choiceQueue.append(char)
            }
            p.quiz = quiz
        }
    }

    /// 기억으로 쓰기에서 가이드를 본 시점에 부른다. 글자를 완성하기 전에 나가도 기록이 남는다.
    func markGuideUsed(_ char: String) {
        recordWrong(char)
        mutate { $0.quiz?.touched = true }
    }

    /// 기억으로 쓰기 한 글자의 결과. 가이드를 본 글자는 큐의 끝으로 보내 다시 낸다.
    func finishWrite(_ char: String, usedGuide: Bool) {
        mutate { p in
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

    // MARK: 단어 읽기

    func markWordDone(_ text: String) {
        mutate { p in
            if !p.wordsDone.contains(text) { p.wordsDone.append(text) }
        }
    }

    /// 단계 완료. 처음 끝낸 단계만 저장한다(장면 완료, 다음 장면 열림이 함께 정해진다).
    func complete() {
        progress.completed = true
        guard !isReplay else { return }
        store.complete(step, quizWrong: progress.quizWrong)
    }

    // MARK: 저장

    private func recordWrong(_ char: String) {
        if !progress.quizWrong.contains(char) { progress.quizWrong.append(char) }
        if !isReplay { store.recordWrong(char, sceneID: scene.id) }
        persist()
    }

    private func mutate(_ body: (inout StepProgress) -> Void) {
        body(&progress)
        persist()
    }

    private func persist() {
        guard !isReplay else { return }
        store.save(progress, stepID: step.id)
    }
}
