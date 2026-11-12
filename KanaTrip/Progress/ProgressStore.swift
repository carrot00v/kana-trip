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
    var version = 1
    var soundOn = false
    var scenes: [String: SceneProgress] = [:]
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

    init(storage: ProgressStorage = FileProgressStorage()) {
        self.storage = storage
        state = storage.load() ?? ProgressState()
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

    func completeSession(_ kind: SessionKind, sceneID: String) {
        update(sceneID) { $0.completed.insert(kind) }
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

    // MARK: - 저장

    private func update(_ sceneID: String, _ body: (inout SceneProgress) -> Void) {
        var p = progress(for: sceneID)
        body(&p)
        guard p != state.scenes[sceneID] else { return }
        state.scenes[sceneID] = p
        storage.save(state)
    }
}
