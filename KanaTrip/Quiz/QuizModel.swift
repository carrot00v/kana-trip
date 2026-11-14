import Foundation

// 종합 퀴즈의 저장 모델과 진행 규칙 (docs/content/quiz-rules.md 3, 5번).
// SwiftUI에 의존하지 않는다. 문항 만들기는 QuizBuilder.swift.

/// 문항 유형. 퀴즈는 유형별 부(part)를 이 순서로 푼다 (quiz-rules.md 3.1).
/// 유형을 더하려면 case를 두고 `QuizBuilder`와 `QuizSessionView`에 잇는다.
enum QuizKind: String, Codable, CaseIterable {
    /// 1부 (가) 글자 보고 발음 고르기.
    case readingChoice
    /// 2부 (라) 단어 보고 읽기 고르기.
    case wordReading
    /// 3부 (다) 발음 보고 가이드 없이 기억으로 쓰기.
    case recallWrite
}

/// 문항 하나. 처음 시작할 때 만들어 저장하고 이어 할 때 그대로 쓴다 (quiz-rules.md 5.2).
struct QuizItem: Codable, Equatable, Identifiable {
    /// 오답 보기 하나.
    struct Wrong: Codable, Equatable {
        let romaji: String
        /// (라): 바꾼 칸의 자리와 원래 글자. 이 오답을 고르면 원래 글자를 틀린 글자로 기록한다 (5.3).
        let changedIndex: Int?
        let original: String?
    }

    let id: Int
    let kind: QuizKind
    /// (가)·(다): 묻는 글자. (라): nil.
    let kana: String?
    /// (라): 묻는 단어의 표기. (가)·(다): nil.
    let word: String?
    /// 정답 로마자.
    let answer: String
    /// 오답 보기 3개. (다)는 비어 있다.
    let wrongs: [Wrong]
    /// 복습 글자 문항인지.
    let isReview: Bool

    /// 이 오답을 골랐을 때 틀린 글자로 기록할 글자 (5.3).
    func wrongKana(picked romaji: String) -> String? {
        switch kind {
        case .readingChoice, .recallWrite: return kana
        case .wordReading: return wrongs.first { $0.romaji == romaji }?.original
        }
    }
}

/// 종합 퀴즈의 진행. 부마다 큐의 맨 앞이 다음에 낼 문항이고, 틀린 문항은 그 부의 줄 끝에 다시 붙는다 (5.1).
struct QuizProgress: Codable, Equatable {
    struct Part: Codable, Equatable {
        var kind: QuizKind
        /// 처음 정한 순서의 문항.
        var items: [QuizItem]
        /// 남은 문항 id. 처음 차례가 앞, 다시 낼 문항이 뒤.
        var queue: [Int]
        /// 맞힌 문항 id.
        var done: [Int] = []
        /// 한 번이라도 틀린 문항 id. 다시 내는 차례인지 가린다.
        var missed: [Int] = []

        init(kind: QuizKind, items: [QuizItem]) {
            self.kind = kind
            self.items = items
            queue = items.map(\.id)
        }

        func item(id: Int) -> QuizItem? { items.first { $0.id == id } }

        /// 지금 낼 문항이 다시 내는 차례인지.
        var isRetrying: Bool { queue.first.map(missed.contains) ?? false }
    }

    /// 이 장면의 새 글자(N).
    var kana: [String]
    /// 복습 글자(R). 끝낸 퀴즈를 다시 하면 비어 있다.
    var review: [String]
    var parts: [Part]
    /// 한 번이라도 답했는지. 다시 들어갈 때 QI를 건너뛸지 정한다 (scene-flow.md 2.5).
    var touched = false

    var doneCount: Int { parts.reduce(0) { $0 + $1.done.count } }
    /// 처음 문항 수. 다시 내는 문항은 세지 않는다.
    var totalCount: Int { parts.reduce(0) { $0 + $1.items.count } }
    var isFinished: Bool { parts.allSatisfy(\.queue.isEmpty) }
    /// 지금 풀 부의 자리. 다 끝났으면 nil.
    var currentPartIndex: Int? { parts.firstIndex { !$0.queue.isEmpty } }

    var currentItem: QuizItem? {
        guard let index = currentPartIndex, let id = parts[index].queue.first else { return nil }
        return parts[index].item(id: id)
    }

    /// 지금 문항의 결과. 맞으면 끝낸 문항으로, 틀리면 그 부의 줄 끝으로 보낸다.
    mutating func answerCurrent(correct: Bool) {
        guard let index = currentPartIndex, let id = parts[index].queue.first else { return }
        touched = true
        parts[index].queue.removeFirst()
        if correct {
            if !parts[index].done.contains(id) { parts[index].done.append(id) }
        } else {
            parts[index].queue.append(id)
            if !parts[index].missed.contains(id) { parts[index].missed.append(id) }
        }
    }
}

/// 복습 대기 목록: 글자 → 들어온 장면 번호 (quiz-rules.md 5.4).
enum ReviewQueue {
    /// 종합 퀴즈에 섞는 복습 글자 수의 상한. PLAN.md 8번 미정 항목의 임시값.
    static let limit = 3

    /// 장면 `sceneOrder`의 복습 글자: 들어온 장면이 이 장면보다 앞인 글자를
    /// 오래 기다린 것 → 배우는 순서가 빠른 것 순으로 최대 `limit`자.
    static func pick(from queue: [String: Int], sceneOrder: Int, learnOrder: (String) -> Int) -> [String] {
        queue.filter { $0.value < sceneOrder }
            .sorted { ($0.value, learnOrder($0.key)) < ($1.value, learnOrder($1.key)) }
            .prefix(limit)
            .map(\.key)
    }

    /// 종합 퀴즈를 통과할 때 한 번에 고친다. 이번 복습 글자 가운데 틀리지 않은 것은 빼고,
    /// 이번에 틀린 글자는 모두 넣어 들어온 장면을 이 장면으로 바꾼다.
    static func update(_ queue: inout [String: Int], review: [String], wrong: [String], sceneOrder: Int) {
        for char in review where !wrong.contains(char) {
            queue[char] = nil
        }
        for char in wrong {
            queue[char] = sceneOrder
        }
    }
}

/// 시드를 줄 수 있는 난수. 테스트에서 문항 예시를 재현할 때 쓴다 (quiz-rules.md 11번의 8).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// SplitMix64.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
