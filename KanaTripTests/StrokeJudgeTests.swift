import CoreGraphics
import Foundation
import Testing
@testable import KanaTrip

private let tolerance = JudgeTolerance()
private let hiragana = KanaStrokeStore.loadHiragana()

/// 실패한 입력을 모아 한 번에 보고하기 위한 도우미.
private struct Failures {
    private(set) var lines: [String] = []
    var isEmpty: Bool { lines.isEmpty }
    var report: Comment { Comment(rawValue: "\(lines.count)건\n" + lines.joined(separator: "\n")) }

    mutating func add(_ char: String, _ stroke: Int, _ detail: String) {
        lines.append("\(char) 획\(stroke + 1): \(detail)")
    }
}

/// 판정의 알려진 한계. 해당 입력이 기대한 판정을 내면(= 한계가 고쳐지면) 이 표시가 오히려 실패하므로 그때 지우면 된다.
private func expect(
    _ actual: StrokeVerdict,
    _ expected: StrokeVerdict,
    char: String,
    stroke: Int,
    detail: String,
    knownLimit: String? = nil,
    failures: inout Failures
) {
    if let knownLimit {
        withKnownIssue(Comment(rawValue: knownLimit)) {
            #expect(actual == expected, "\(char) 획\(stroke + 1) \(detail)")
        }
    } else if actual != expected {
        failures.add(char, stroke, "\(detail): \(actual)")
    }
}

@Suite("획 데이터")
struct StrokeDataTests {
    @Test func loadsAll46Hiragana() {
        #expect(hiragana.count == 46)
        #expect(Set(hiragana.map(\.char)).count == 46)
        for kana in hiragana {
            #expect(!kana.strokes.isEmpty, "\(kana.char)의 획이 비어 있음")
            for (n, stroke) in kana.strokes.enumerated() {
                #expect(stroke.count >= 2, "\(kana.char) 획\(n + 1)의 점이 너무 적음")
                for point in stroke {
                    #expect((0...KanaStrokeStore.viewBox).contains(point.x) && (0...KanaStrokeStore.viewBox).contains(point.y),
                            "\(kana.char) 획\(n + 1)이 좌표계 밖: \(point)")
                }
            }
        }
    }
}

@Suite("허용 오차")
struct ToleranceTests {
    @Test func scaledChangesEveryValueByTheFactor() {
        let base = JudgeTolerance()
        for factor in [0.5, 0.8, 1.5, 2.0] as [CGFloat] {
            let scaled = base.scaled(by: factor)
            #expect(abs(scaled.endpoint - base.endpoint * factor) < 1e-9)
            #expect(abs(scaled.shape - base.shape * factor) < 1e-9)
            #expect(abs(scaled.loopDistance - base.loopDistance * factor) < 1e-9)
            // 길이 비율은 배율이 클수록 느슨해지도록 최소는 나누고 최대는 곱한다.
            #expect(abs(scaled.minLengthRatio - base.minLengthRatio / factor) < 1e-9)
            #expect(abs(scaled.maxLengthRatio - base.maxLengthRatio * factor) < 1e-9)
        }
    }

    @Test func scaledByOneKeepsValues() {
        let base = JudgeTolerance()
        let same = base.scaled(by: 1)
        #expect(same.endpoint == base.endpoint && same.shape == base.shape)
        #expect(same.minLengthRatio == base.minLengthRatio && same.maxLengthRatio == base.maxLengthRatio)
        #expect(same.loopDistance == base.loopDistance)
    }
}

@Suite("쓰기 판정")
struct StrokeJudgeTests {
    private func judge(_ drawn: [CGPoint], _ kana: Kana, _ index: Int) -> StrokeVerdict {
        StrokeJudge.judge(drawn: drawn, strokes: kana.strokes, index: index, tolerance: tolerance)
    }

    @Test func referenceStrokesAreCorrect() {
        var failures = Failures()
        for kana in hiragana {
            for (n, stroke) in kana.strokes.enumerated() {
                let verdict = judge(stroke, kana, n)
                if verdict != .correct { failures.add(kana.char, n, "\(verdict)") }
            }
        }
        #expect(failures.isEmpty, failures.report)
    }

    @Test func denselySampledReferenceIsCorrect() {
        var failures = Failures()
        for kana in hiragana {
            for (n, stroke) in kana.strokes.enumerated() {
                let verdict = judge(StrokeShaper.densify(stroke, step: 0.7), kana, n)
                if verdict != .correct { failures.add(kana.char, n, "\(verdict)") }
            }
        }
        #expect(failures.isEmpty, failures.report)
    }

    @Test func reversedStrokesAreReversed() {
        // 점처럼 짧은 획도 방향이 있는 한 점 순서가 반대면 정방향보다 기준에 더 멀어지므로 예외를 두지 않았다.
        var failures = Failures()
        for kana in hiragana {
            for (n, stroke) in kana.strokes.enumerated() {
                let verdict = judge(StrokeShaper.reversed(stroke), kana, n)
                if verdict != .reversed { failures.add(kana.char, n, "\(verdict)") }
            }
        }
        #expect(failures.isEmpty, failures.report)
    }

    /// 고리가 있는 뒤 획을 먼저 그어도 고리 판정이 아니라 획순 오류가 나와야 한다. (예전 한계: な3-4, ほ2-4, よ1-2)
    @Test func laterStrokeWithLoopIsWrongOrderNotLoopVerdict() {
        let cases: [(String, Int, Int)] = [("な", 2, 3), ("ほ", 1, 3), ("よ", 0, 1)]
        for (char, index, other) in cases {
            guard let kana = hiragana.first(where: { $0.char == char }) else {
                Issue.record("\(char) 없음"); continue
            }
            #expect(judge(kana.strokes[other], kana, index) == .wrongOrder(drawn: other), "\(char) 획\(index + 1) 차례에 획\(other + 1)")
        }
    }

    @Test func laterStrokeDrawnFirstIsWrongOrder() {
        var failures = Failures()
        var checked = 0
        for kana in hiragana where kana.strokes.count > 1 {
            for index in kana.strokes.indices {
                for other in kana.strokes.indices where other > index {
                    // 현재 획과 모양이 비슷한 획은 순서 오류와 구분되지 않으므로 뺀다.
                    let drawn = kana.strokes[other]
                    let looksLikeCurrent = StrokeJudge.compare(drawn, kana.strokes[index]).passes(tolerance)
                        || StrokeJudge.compare(drawn.reversed(), kana.strokes[index]).passes(tolerance)
                    // 사이에 있는 다른 획과도 비슷하면 어느 쪽으로 읽을지 정해지지 않는다.
                    let looksLikeEarlierOther = kana.strokes.indices.contains { mid in
                        mid > index && mid < other && StrokeJudge.compare(drawn, kana.strokes[mid]).passes(tolerance)
                    }
                    if looksLikeCurrent || looksLikeEarlierOther { continue }
                    checked += 1
                    let verdict = judge(drawn, kana, index)
                    expect(verdict, .wrongOrder(drawn: other), char: kana.char, stroke: index,
                           detail: "획\(other + 1)을 먼저 그음", failures: &failures)
                }
            }
        }
        #expect(checked > 40, "검증한 조합이 너무 적음: \(checked)")
        #expect(failures.isEmpty, failures.report)
    }

    @Test func lastStrokeIsNeverWrongOrder() {
        // 마지막 획 차례에는 "뒤 획"이 없으므로 다른 획을 그어도 wrongOrder가 나오면 안 된다.
        var failures = Failures()
        for kana in hiragana where kana.strokes.count > 1 {
            let last = kana.strokes.count - 1
            let verdict = judge(kana.strokes[0], kana, last)
            if case .wrongOrder = verdict { failures.add(kana.char, last, "\(verdict)") }
        }
        #expect(failures.isEmpty, failures.report)
    }

    @Test func veryShortLineIsTooShort() {
        // 기준 획을 앞의 15%만 긋고 멈춘 선.
        var failures = Failures()
        for kana in hiragana {
            for (n, stroke) in kana.strokes.enumerated() {
                // 고리가 있는 획의 짧은 토막도 고리 누락이 아니라 tooShort여야 한다.
                let verdict = judge(StrokeShaper.prefix(stroke, fraction: 0.15), kana, n)
                expect(verdict, .tooShort, char: kana.char, stroke: n, detail: "앞 15%만 그음",
                       failures: &failures)
            }
        }
        #expect(failures.isEmpty, failures.report)
    }

    @Test func singleTapIsNotCorrect() {
        // 한 점만 찍힌 입력은 어떤 획도 통과하지 못한다.
        for kana in hiragana {
            for n in kana.strokes.indices {
                let tap = [kana.strokes[n][0]]
                #expect(judge(tap, kana, n) != .correct, "\(kana.char) 획\(n + 1)")
            }
        }
    }

    @Test func emptyInputIsOffTarget() {
        let kana = hiragana[0]
        #expect(judge([], kana, 0) == .offTarget)
        #expect(StrokeJudge.judge(drawn: kana.strokes[0], strokes: kana.strokes, index: 99, tolerance: tolerance) == .offTarget)
    }

    @Test func lineInWrongPlaceIsOffTarget() {
        // 기준 획 모양 그대로 글자 칸 밖(우하단 / 좌상단 쪽 멀리)으로 옮긴 선.
        var failures = Failures()
        for kana in hiragana {
            for (n, stroke) in kana.strokes.enumerated() {
                for (dx, dy) in [(80, 80), (-80, -80)] as [(CGFloat, CGFloat)] {
                    let verdict = judge(StrokeShaper.translated(stroke, dx: dx, dy: dy), kana, n)
                    if verdict != .offTarget { failures.add(kana.char, n, "(\(dx),\(dy)) 이동: \(verdict)") }
                }
            }
        }
        #expect(failures.isEmpty, failures.report)
    }

    @Test func smoothWobbleStaysCorrect() {
        for amplitude in [1.0, 2.0] as [CGFloat] {
            var failures = Failures()
            for kana in hiragana {
                for (n, stroke) in kana.strokes.enumerated() {
                    let seed = UInt64(kana.char.unicodeScalars.first!.value) &* 31 &+ UInt64(n)
                    let verdict = judge(StrokeShaper.wobbled(stroke, amplitude: amplitude, seed: seed), kana, n)
                    if verdict != .correct { failures.add(kana.char, n, "진폭 \(amplitude): \(verdict)") }
                }
            }
            #expect(failures.isEmpty, failures.report)
        }
    }

    // MARK: - 고리

    /// 기준 획에서 고리가 있는 (글자, 획 번호, 고리) 목록.
    private var loopStrokes: [(kana: Kana, index: Int, loops: [StrokeLoop])] {
        hiragana.flatMap { kana in
            kana.strokes.indices.compactMap { n -> (Kana, Int, [StrokeLoop])? in
                let found = StrokeJudge.loops(in: kana.strokes[n])
                return found.isEmpty ? nil : (kana, n, found)
            }
        }
    }

    @Test func referenceLoopsIncludeExpectedKana() {
        let chars = Set(loopStrokes.map(\.kana.char))
        for expected in ["ぬ", "ね", "よ", "ま"] {
            #expect(chars.contains(expected), "\(expected)에서 고리를 찾지 못함 (찾은 글자: \(chars.sorted()))")
        }
    }

    @Test func cuttingALoopIsMissingLoop() {
        var failures = Failures()
        var checked = 0
        for entry in loopStrokes {
            let dense = StrokeShaper.densify(entry.kana.strokes[entry.index])
            for loop in entry.loops {
                guard let span = StrokeShaper.span(of: loop, in: dense) else {
                    failures.add(entry.kana.char, entry.index, "테스트 도우미가 고리 구간을 찾지 못함 \(loop.center)")
                    continue
                }
                checked += 1
                let verdict = judge(StrokeShaper.shortcut(dense, skipping: span), entry.kana, entry.index)
                guard case .missingLoop = verdict else {
                    failures.add(entry.kana.char, entry.index, "고리(중심 \(loop.center), 넓이 \(Int(loop.area))) 생략: \(verdict)")
                    continue
                }
            }
        }
        #expect(checked >= 8, "검증한 고리가 너무 적음: \(checked)")
        #expect(failures.isEmpty, failures.report)
    }

    /// 요청에서 예로 든, 기준 획에 고리가 없는 글자들.
    private let loopFreeChars = ["め", "れ", "わ", "ろ", "つ"]

    @Test func smallCurlInLoopFreeStrokeIsExtraLoop() {
        var failures = Failures()
        for char in loopFreeChars {
            let kana = hiragana.first { $0.char == char }!
            for (n, stroke) in kana.strokes.enumerated() where StrokeJudge.loops(in: stroke).isEmpty {
                // 길이가 너무 짧은 획(점)에는 고리가 비현실적으로 커져 제외한다.
                guard StrokeJudge.length(stroke) > 40 else { continue }
                let curled = StrokeShaper.withExtraLoop(stroke)
                guard !StrokeJudge.loops(in: curled).isEmpty else {
                    failures.add(char, n, "테스트 도우미가 만든 획에서 고리가 감지되지 않음")
                    continue
                }
                let verdict = judge(curled, kana, n)
                if verdict != .extraLoop { failures.add(char, n, "작은 고리 추가: \(verdict)") }
            }
        }
        #expect(failures.isEmpty, failures.report)
    }

    @Test func smallCurlInAnyLoopFreeStrokeIsExtraLoop() {
        // 위 목록 밖의 모든 고리 없는 긴 획에도 같은 실수를 넣어 본다.
        var failures = Failures()
        var checked = 0
        for kana in hiragana {
            for (n, stroke) in kana.strokes.enumerated() where StrokeJudge.loops(in: stroke).isEmpty {
                guard StrokeJudge.length(stroke) > 40 else { continue }
                let curled = StrokeShaper.withExtraLoop(stroke)
                guard !StrokeJudge.loops(in: curled).isEmpty else { continue }
                checked += 1
                let verdict = judge(curled, kana, n)
                if verdict != .extraLoop { failures.add(kana.char, n, "작은 고리 추가: \(verdict)") }
            }
        }
        #expect(checked > 30, "검증한 획이 너무 적음: \(checked)")
        #expect(failures.isEmpty, failures.report)
    }
}
