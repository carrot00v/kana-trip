import CoreGraphics
import Foundation

/// 판정 허용 오차. 단위는 109x109 획 좌표계의 길이다.
struct JudgeTolerance {
    /// 시작점과 끝점이 기준 획에서 벗어나도 되는 거리.
    var endpoint: CGFloat = 22
    /// 획 전체가 기준 획에서 평균적으로 벗어나도 되는 거리.
    var shape: CGFloat = 14
    /// 기준 획 길이 대비 허용하는 길이 비율.
    var minLengthRatio: CGFloat = 0.45
    var maxLengthRatio: CGFloat = 2.2
    /// 그은 고리의 중심이 기준 고리의 중심에서 벗어나도 되는 거리.
    var loopDistance: CGFloat = 16

    /// 배율이 1보다 크면 느슨해지고 작으면 엄격해진다.
    func scaled(by factor: CGFloat) -> JudgeTolerance {
        JudgeTolerance(
            endpoint: endpoint * factor,
            shape: shape * factor,
            minLengthRatio: minLengthRatio / factor,
            maxLengthRatio: maxLengthRatio * factor,
            loopDistance: loopDistance * factor
        )
    }
}

enum StrokeVerdict: Equatable {
    case correct
    /// 모양은 맞지만 반대 방향으로 그음.
    case reversed
    /// 지금 차례가 아닌 획을 그음. 값은 실제로 그은 획의 번호(0부터).
    case wrongOrder(drawn: Int)
    case tooShort
    case offTarget
    /// 기준 획에 있는 고리를 만들지 않음. 값은 놓친 고리의 중심.
    case missingLoop(at: CGPoint)
    /// 기준 획에 없는 고리를 만듦.
    case extraLoop
}

/// 획이 자기 자신과 교차해서 생긴 고리. ぬ, ね, る의 끝 고리나 あ, の의 큰 고리가 여기에 해당한다.
struct StrokeLoop: Equatable {
    let center: CGPoint
    let area: CGFloat
}

/// 사용자가 그은 획 하나를 기준 획과 비교한다. SwiftUI에 의존하지 않는다.
enum StrokeJudge {
    static let sampleCount = 24

    /// - Parameters:
    ///   - drawn: 사용자가 그은 점들 (109x109 좌표계)
    ///   - strokes: 글자의 전체 기준 획
    ///   - index: 지금 써야 할 획의 번호
    static func judge(
        drawn: [CGPoint],
        strokes: [[CGPoint]],
        index: Int,
        tolerance: JudgeTolerance
    ) -> StrokeVerdict {
        guard strokes.indices.contains(index), !drawn.isEmpty else { return .offTarget }
        let target = strokes[index]

        let forward = compare(drawn, target)
        let backward = compare(drawn.reversed(), target)

        // 정방향과 역방향 중 기준 획에 더 가까운 쪽을 사용자가 의도한 방향으로 본다.
        if backward.meanDistance < forward.meanDistance, backward.passes(tolerance) {
            return .reversed
        }
        if forward.passes(tolerance) {
            return loopVerdict(drawn: drawn, target: target, tolerance: tolerance) ?? .correct
        }

        // 뒤 획과 그대로 맞으면 고리보다 획순이 먼저다. 뒤 획 자체에 고리가 있을 수 있어서다.
        for other in strokes.indices where other > index {
            if compare(drawn, strokes[other]).passes(tolerance) {
                return .wrongOrder(drawn: other)
            }
        }

        // 기준 획의 앞부분만 긋고 멈춘 것은 고리를 빼먹은 것이 아니다.
        // 큰 고리를 건너뛴 획도 짧아지지만, 그때는 끝점이 기준 획의 끝에 닿아 있다.
        if forward.lengthRatio < tolerance.minLengthRatio, forward.endDistance > tolerance.endpoint {
            return .tooShort
        }

        // 시작점은 맞는데 모양이 어긋났다면, 고리를 빼먹거나 더 만든 것이 원인인지 본다.
        // 고리 하나가 빠지면 획 길이가 달라져 모양 비교도 함께 어긋나기 때문이다.
        if forward.startDistance <= tolerance.endpoint,
           let verdict = loopVerdict(drawn: drawn, target: target, tolerance: tolerance) {
            return verdict
        }
        return forward.lengthRatio < tolerance.minLengthRatio ? .tooShort : .offTarget
    }

    // MARK: - 고리

    /// 위치와 방향이 맞은 획에 대해 고리의 유무를 확인한다. 문제가 없으면 nil.
    private static func loopVerdict(drawn: [CGPoint], target: [CGPoint], tolerance: JudgeTolerance) -> StrokeVerdict? {
        let targetLoops = loops(in: target)
        let drawnLoops = loops(in: drawn)
        func near(_ a: StrokeLoop, _ b: StrokeLoop) -> Bool {
            // 큰 고리는 중심이 더 많이 흔들리므로 크기에 비례해 허용 거리를 넓힌다.
            let reach = max(tolerance.loopDistance, sqrt(max(a.area, b.area)) * 0.6)
            return distance(a.center, b.center) <= reach
        }
        for loop in targetLoops where !drawnLoops.contains(where: { near(loop, $0) }) {
            return .missingLoop(at: loop.center)
        }
        // の처럼 크게 도는 획은 사람에 따라 시작 부분과 교차하기도 하므로, 작은 고리만 잘못으로 본다.
        for loop in drawnLoops where loop.area <= maxExtraLoopArea && !targetLoops.contains(where: { near(loop, $0) }) {
            return .extraLoop
        }
        return nil
    }

    /// 고리로 인정하는 최소 넓이. 손떨림으로 생긴 작은 교차를 걸러낸다.
    static let minLoopArea: CGFloat = 8
    /// 기준 획에 없을 때 잘못으로 보는 고리의 최대 넓이. 이보다 큰 교차는 문제 삼지 않는다.
    static let maxExtraLoopArea: CGFloat = 500
    /// 넓이 / 둘레² 의 최솟값. 갔던 길을 되돌아오며 생기는 가늘고 긴 틈을 걸러낸다. (원은 약 0.08)
    static let minLoopCompactness: CGFloat = 0.02

    /// 획이 자기 자신과 교차해 만든 고리를 찾는다.
    static func loops(in points: [CGPoint]) -> [StrokeLoop] {
        let p = resample(points, count: 64)
        guard p.count >= 4, length(p) > 0 else { return [] }
        var found: [StrokeLoop] = []
        for i in 0..<(p.count - 3) {
            for j in (i + 2)..<(p.count - 1) {
                guard let cross = intersection(p[i], p[i + 1], p[j], p[j + 1]) else { continue }
                let polygon = [cross] + Array(p[(i + 1)...j])
                let area = polygonArea(polygon)
                let perimeter = length(polygon + [cross])
                guard area >= minLoopArea, perimeter > 0, area / (perimeter * perimeter) >= minLoopCompactness else { continue }
                let center = CGPoint(
                    x: polygon.reduce(0) { $0 + $1.x } / CGFloat(polygon.count),
                    y: polygon.reduce(0) { $0 + $1.y } / CGFloat(polygon.count)
                )
                let loop = StrokeLoop(center: center, area: area)
                if let same = found.firstIndex(where: { distance($0.center, center) < 5 }) {
                    if area > found[same].area { found[same] = loop }
                } else {
                    found.append(loop)
                }
            }
        }
        return found
    }

    private static func intersection(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> CGPoint? {
        let r = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let s = CGPoint(x: d.x - c.x, y: d.y - c.y)
        let denominator = r.x * s.y - r.y * s.x
        guard abs(denominator) > 1e-9 else { return nil }
        let t = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / denominator
        let u = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / denominator
        guard t >= 0, t <= 1, u >= 0, u <= 1 else { return nil }
        return CGPoint(x: a.x + r.x * t, y: a.y + r.y * t)
    }

    private static func polygonArea(_ polygon: [CGPoint]) -> CGFloat {
        var sum: CGFloat = 0
        for k in polygon.indices {
            let a = polygon[k]
            let b = polygon[(k + 1) % polygon.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    // MARK: - 비교

    struct Comparison {
        let startDistance: CGFloat
        let endDistance: CGFloat
        let meanDistance: CGFloat
        let lengthRatio: CGFloat

        func passes(_ tolerance: JudgeTolerance) -> Bool {
            startDistance <= tolerance.endpoint
                && endDistance <= tolerance.endpoint
                && meanDistance <= tolerance.shape
                && lengthRatio >= tolerance.minLengthRatio
                && lengthRatio <= tolerance.maxLengthRatio
        }
    }

    static func compare(_ drawn: [CGPoint], _ target: [CGPoint]) -> Comparison {
        let a = resample(drawn, count: sampleCount)
        let b = resample(target, count: sampleCount)
        let total = zip(a, b).reduce(CGFloat(0)) { $0 + distance($1.0, $1.1) }
        let targetLength = max(length(target), 0.001)
        return Comparison(
            startDistance: distance(a[0], b[0]),
            endDistance: distance(a[sampleCount - 1], b[sampleCount - 1]),
            meanDistance: total / CGFloat(sampleCount),
            lengthRatio: length(drawn) / targetLength
        )
    }

    /// 점들을 획 길이를 따라 같은 간격으로 `count`개 다시 뽑는다.
    static func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard let first = points.first else { return [] }
        let total = length(points)
        guard points.count > 1, total > 0 else {
            return Array(repeating: first, count: count)
        }
        let step = total / CGFloat(count - 1)
        var result = [first]
        var travelled: CGFloat = 0
        var nextMark = step
        for i in 1..<points.count {
            let from = points[i - 1]
            let to = points[i]
            let segment = distance(from, to)
            while segment > 0, travelled + segment >= nextMark, result.count < count {
                let t = (nextMark - travelled) / segment
                result.append(CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
                nextMark += step
            }
            travelled += segment
        }
        while result.count < count {
            result.append(points[points.count - 1])
        }
        return result
    }

    static func length(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        return (1..<points.count).reduce(CGFloat(0)) { $0 + distance(points[$1 - 1], points[$1]) }
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
