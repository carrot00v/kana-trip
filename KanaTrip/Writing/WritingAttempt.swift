import CoreGraphics
import Foundation

/// 글자 하나를 한 획씩 써 나가는 동안의 상태. SwiftUI에 의존하지 않는다.
struct WritingAttempt: Equatable {
    enum Feedback: Equatable {
        case idle
        case good
        /// 값은 판정 결과와 그때 써야 했던 획의 번호(1부터).
        case bad(StrokeVerdict, expectedStroke: Int)
        case finished(mistakes: Int)
    }

    /// 이미 맞게 쓴 획의 수.
    var doneCount = 0
    var mistakes = 0
    var feedback = Feedback.idle
    /// 방금 틀린 획. 잠깐 빨갛게 보여 주기 위한 값이다.
    var rejected: [CGPoint] = []
    /// 방금 빼먹은 고리의 위치.
    var missedLoop: CGPoint?

    func isFinished(strokeCount: Int) -> Bool {
        doneCount >= strokeCount
    }

    /// 그은 획 하나를 판정하고 상태를 바꾼다. 이미 완성한 글자면 nil.
    mutating func submit(_ points: [CGPoint], strokes: [[CGPoint]], tolerance: JudgeTolerance) -> StrokeVerdict? {
        guard doneCount < strokes.count else { return nil }
        let verdict = StrokeJudge.judge(drawn: points, strokes: strokes, index: doneCount, tolerance: tolerance)
        if verdict == .correct {
            doneCount += 1
            clearRejected()
            feedback = doneCount == strokes.count ? .finished(mistakes: mistakes) : .good
        } else {
            mistakes += 1
            feedback = .bad(verdict, expectedStroke: doneCount + 1)
            rejected = points
            if case .missingLoop(let center) = verdict { missedLoop = center } else { missedLoop = nil }
        }
        return verdict
    }

    mutating func clearRejected() {
        rejected = []
        missedLoop = nil
    }
}
