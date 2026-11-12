import SwiftUI

/// 획 데이터를 그릴 때 캔버스와 글자 표시가 함께 쓰는 그리기 함수.
/// 굵기와 반지름은 109 좌표계의 값이고 `scale`(변 ÷ 109)을 곱해 화면 크기로 바꾼다.
enum StrokeDrawing {
    static let guideWidth: CGFloat = 7
    static let strokeWidth: CGFloat = 5

    static func style(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    static func path(_ points: [CGPoint], scale: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
        if points.count == 1 {
            path.addLine(to: CGPoint(x: first.x * scale + 0.1, y: first.y * scale))
        }
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * scale, y: point.y * scale))
        }
        return path
    }

    /// 고리를 만들어야 하는 자리를 점선 원으로 표시한다. `center`는 109 좌표계.
    static func drawLoopMark(_ context: inout GraphicsContext, at center: CGPoint, area: CGFloat, color: Color, scale: CGFloat) {
        let radius = (min(sqrt(area / .pi), 14) + 5) * scale
        let rect = CGRect(x: center.x * scale - radius, y: center.y * scale - radius, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(color), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
    }

    /// 획의 시작점에 번호 원을 그린다. `point`는 109 좌표계.
    /// 숫자는 주황 바탕 위에서 읽히도록 라이트·다크 모두 검정이다.
    static func drawStartHint(_ context: inout GraphicsContext, at point: CGPoint, number: Int, scale: CGFloat) {
        let center = CGPoint(x: point.x * scale, y: point.y * scale)
        let radius = 5.5 * scale
        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(circle, with: .color(.orange))
        context.draw(
            Text("\(number)").font(.system(size: 8 * scale, weight: .bold)).foregroundStyle(Color.black),
            at: center
        )
    }
}
