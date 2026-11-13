import CoreGraphics
import Foundation
@testable import KanaTrip

/// 결정적인 난수. 같은 시드면 항상 같은 값이 나온다.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 기준 획을 실제 손글씨 실수처럼 바꾸는 도우미. 모두 109x109 좌표계에서 동작한다.
enum StrokeShaper {
    /// 점 사이를 약 `step` 간격으로 촘촘하게 다시 뽑는다. 손으로 그은 획처럼 점이 고르게 찍힌 상태.
    static func densify(_ points: [CGPoint], step: CGFloat = 1) -> [CGPoint] {
        let count = max(2, Int((StrokeJudge.length(points) / step).rounded()) + 1)
        return StrokeJudge.resample(points, count: count)
    }

    static func reversed(_ points: [CGPoint]) -> [CGPoint] {
        Array(points.reversed())
    }

    static func translated(_ points: [CGPoint], dx: CGFloat, dy: CGFloat) -> [CGPoint] {
        points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
    }

    /// 획의 앞쪽 `fraction` 만큼만 남긴다. 그으려다 만 획.
    static func prefix(_ points: [CGPoint], fraction: CGFloat) -> [CGPoint] {
        let dense = densify(points)
        let keep = max(2, Int(CGFloat(dense.count) * fraction))
        return Array(dense.prefix(keep))
    }

    /// 손떨림처럼 부드러운 사인파 흔들림을 더한다. x와 y에 서로 다른 위상의 사인파를 얹어
    /// 점이 움직인 거리가 최대 `amplitude`를 넘지 않는다. 파장(25~45)과 위상은 시드로 정해진다.
    /// 획의 진행 방향에 수직으로 밀면 급하게 꺾이는 획(て 등)의 안쪽이 접혀 가짜 고리가 생기므로 쓰지 않는다.
    static func wobbled(_ points: [CGPoint], amplitude: CGFloat, seed: UInt64) -> [CGPoint] {
        var rng = SeededGenerator(seed: seed)
        let waveX = CGFloat.random(in: 25...45, using: &rng)
        let waveY = CGFloat.random(in: 25...45, using: &rng)
        let phaseX = CGFloat.random(in: 0...(2 * .pi), using: &rng)
        let phaseY = CGFloat.random(in: 0...(2 * .pi), using: &rng)
        let axis = amplitude / 2.0.squareRoot()
        let dense = densify(points)
        return dense.indices.map { k in
            let s = CGFloat(k)
            return CGPoint(
                x: dense[k].x + axis * sin(2 * .pi * s / waveX + phaseX),
                y: dense[k].y + axis * sin(2 * .pi * s / waveY + phaseY)
            )
        }
    }

    // MARK: - 고리

    /// 획 안의 자기 교차 하나. 점 `i`~`j` 구간이 한 바퀴 돈 부분이고 `cross`에서 만난다.
    struct LoopSpan {
        let i: Int
        let j: Int
        let cross: CGPoint
        let center: CGPoint
        let area: CGFloat
    }

    /// 촘촘한 점들에서 `loop`(기준 고리)에 가장 가까운 자기 교차 구간을 찾는다.
    static func span(of loop: StrokeLoop, in dense: [CGPoint]) -> LoopSpan? {
        var best: (span: LoopSpan, gap: CGFloat)?
        for i in 0..<max(dense.count - 3, 0) {
            for j in (i + 2)..<(dense.count - 1) {
                guard let cross = intersection(dense[i], dense[i + 1], dense[j], dense[j + 1]) else { continue }
                let polygon = [cross] + Array(dense[(i + 1)...j])
                let area = polygonArea(polygon)
                guard area >= StrokeJudge.minLoopArea else { continue }
                let center = CGPoint(
                    x: polygon.reduce(0) { $0 + $1.x } / CGFloat(polygon.count),
                    y: polygon.reduce(0) { $0 + $1.y } / CGFloat(polygon.count)
                )
                let gap = StrokeJudge.distance(center, loop.center)
                if gap < 10, best == nil || gap < best!.gap {
                    best = (LoopSpan(i: i, j: j, cross: cross, center: center, area: area), gap)
                }
            }
        }
        return best?.span
    }

    /// 고리를 돌지 않고 교차점으로 바로 지나가게 한다. 고리를 빼먹고 쓴 획.
    static func shortcut(_ dense: [CGPoint], skipping span: LoopSpan) -> [CGPoint] {
        Array(dense[...span.i]) + [span.cross] + Array(dense[(span.j + 1)...])
    }

    /// 획 한가운데에 작은 고리를 끼워 넣는다. 펜이 앞으로 가면서 한 바퀴 도는 모양(트로코이드)이라 선이 끊기지 않고 부드럽다.
    /// - Parameter radius: 고리의 대략적인 반지름.
    static func withExtraLoop(_ points: [CGPoint], at fraction: CGFloat = 0.5, radius: CGFloat = 4, flip: Bool = false) -> [CGPoint] {
        let dense = densify(points)
        let k = min(max(2, Int(CGFloat(dense.count) * fraction)), dense.count - 3)
        let tangent = unit(CGPoint(x: dense[k + 2].x - dense[k - 2].x, y: dense[k + 2].y - dense[k - 2].y))
        let normal = CGPoint(x: -tangent.y * (flip ? -1 : 1), y: tangent.x * (flip ? -1 : 1))
        let origin = dense[k]
        // 가로 이동량 a·θ 보다 회전 반지름 b 가 커야 고리가 생긴다.
        let b = radius
        let a = radius * 0.15
        let steps = 40
        var curl: [CGPoint] = []
        for s in 0...steps {
            let theta = 2 * CGFloat.pi * CGFloat(s) / CGFloat(steps)
            let along = a * theta + b * sin(theta)
            let across = b - b * cos(theta)
            curl.append(CGPoint(
                x: origin.x + tangent.x * along + normal.x * across,
                y: origin.y + tangent.y * along + normal.y * across
            ))
        }
        // 고리가 끝난 자리에서 원래 획으로 이어 붙인다.
        let end = curl[curl.count - 1]
        var resumeAt = k + 1
        var nearest = CGFloat.infinity
        for m in (k + 1)..<dense.count {
            let d = StrokeJudge.distance(dense[m], end)
            if d < nearest { nearest = d; resumeAt = m }
        }
        return Array(dense[...k]) + curl.dropFirst() + Array(dense[resumeAt...])
    }

    // MARK: - 기하

    private static func unit(_ v: CGPoint) -> CGPoint {
        let n = hypot(v.x, v.y)
        return n > 0 ? CGPoint(x: v.x / n, y: v.y / n) : CGPoint(x: 1, y: 0)
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
}
