import SwiftUI

/// 정사각형 쓰기 캔버스. 획 하나를 그을 때마다 109x109 좌표계의 점들을 `onStroke`로 넘긴다.
/// 화면 좌표와 획 좌표의 변환은 여기에서만 한다.
struct WritingCanvas: View {
    let kana: Kana
    /// 이미 맞게 쓴 획의 수.
    let doneCount: Int
    let showGuide: Bool
    /// 방금 틀린 획. 잠깐 빨갛게 보여주기 위한 값이다.
    let rejected: [CGPoint]
    /// 방금 빼먹은 고리의 위치. 가이드가 꺼져 있어도 잠깐 보여준다.
    let missedLoop: CGPoint?
    /// 손가락을 대거나 뗄 때 불린다. 획을 긋는 동안 바깥 버튼을 막는 데 쓴다.
    var onDrawingChanged: ((Bool) -> Void)? = nil
    /// VoiceOver 레이블에 글자를 넣을지. 기억으로 쓰기에서는 답이 되므로 뺀다.
    var revealsKanaToVoiceOver = true
    let onStroke: ([CGPoint]) -> Void

    @State private var current: [CGPoint] = []
    @Environment(\.colorSchemeContrast) private var contrast

    private var isFinished: Bool { doneCount >= kana.strokes.count }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / KanaStrokeStore.viewBox
            let guideOpacity = contrast == .increased ? 0.4 : 0.22

            Canvas { context, size in
                drawGrid(&context, size: size)

                if showGuide {
                    for stroke in kana.strokes {
                        context.stroke(
                            StrokeDrawing.path(stroke, scale: scale),
                            with: .color(.gray.opacity(guideOpacity)),
                            style: StrokeDrawing.style(StrokeDrawing.guideWidth * scale)
                        )
                    }
                }
                for stroke in kana.strokes.prefix(doneCount) {
                    context.stroke(
                        StrokeDrawing.path(stroke, scale: scale),
                        with: .color(.primary),
                        style: StrokeDrawing.style(StrokeDrawing.strokeWidth * scale)
                    )
                }
                if showGuide, !isFinished, let start = kana.strokes[doneCount].first {
                    StrokeDrawing.drawStartHint(&context, at: start, number: doneCount + 1, scale: scale)
                }
                if showGuide, !isFinished {
                    for loop in StrokeJudge.loops(in: kana.strokes[doneCount]) {
                        StrokeDrawing.drawLoopMark(&context, at: loop.center, area: loop.area, color: .orange, scale: scale)
                    }
                }
                if let missedLoop {
                    StrokeDrawing.drawLoopMark(&context, at: missedLoop, area: 250, color: .red, scale: scale)
                }
                if !rejected.isEmpty {
                    context.stroke(
                        StrokeDrawing.path(rejected, scale: scale),
                        with: .color(.red.opacity(0.7)),
                        style: StrokeDrawing.style(StrokeDrawing.strokeWidth * scale)
                    )
                }
                if !current.isEmpty {
                    context.stroke(
                        StrokeDrawing.path(current, scale: 1),
                        with: .color(.accentColor),
                        style: StrokeDrawing.style(StrokeDrawing.strokeWidth * scale)
                    )
                }
            }
            .frame(width: side, height: side)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        // 글자를 완성한 뒤에는 입력을 받지 않는다.
                        guard !isFinished else { return }
                        if current.isEmpty { onDrawingChanged?(true) }
                        current.append(value.location)
                    }
                    .onEnded { _ in
                        guard !current.isEmpty else { return }
                        let points = current.map { CGPoint(x: $0.x / scale, y: $0.y / scale) }
                        current = []
                        onDrawingChanged?(false)
                        onStroke(points)
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(L.canvasLabel(
            char: revealsKanaToVoiceOver ? kana.char : nil,
            total: kana.strokes.count,
            current: doneCount + 1
        ))
        .accessibilityDirectTouch()
    }

    private func drawGrid(_ context: inout GraphicsContext, size: CGSize) {
        var cross = Path()
        cross.move(to: CGPoint(x: size.width / 2, y: 12))
        cross.addLine(to: CGPoint(x: size.width / 2, y: size.height - 12))
        cross.move(to: CGPoint(x: 12, y: size.height / 2))
        cross.addLine(to: CGPoint(x: size.width - 12, y: size.height / 2))
        context.stroke(cross, with: .color(.gray.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
    }
}
