import SwiftUI

/// 캔버스에 판정과 피드백(햅틱, 틀린 획 표시 시간, VoiceOver 알림)을 붙인 것.
/// 따라 쓰기, 기억으로 쓰기, 스파이크 화면이 함께 쓴다.
struct WritingPad: View {
    /// 틀린 획과 빼먹은 고리를 보여 주는 시간.
    static let rejectedDuration = Duration.milliseconds(900)

    let kana: Kana
    let showGuide: Bool
    @Binding var attempt: WritingAttempt
    /// 정식 화면은 기본값을 쓴다. 스파이크만 배율을 바꿔 넘긴다.
    var tolerance = JudgeTolerance()
    var revealsKanaToVoiceOver = true
    /// 글자를 완성했을 때 VoiceOver로 읽어 줄 문구. 없으면 따라 쓰기의 완성 문구를 쓴다.
    var finishedAnnouncement: String? = nil
    /// 획을 긋는 중인지. 바깥 버튼을 막는 데 쓴다.
    var isDrawing: Binding<Bool> = .constant(false)
    /// 틀린 획의 빨간 표시가 사라진 뒤에 불린다.
    var onRejectedCleared: (() -> Void)? = nil

    @State private var pendingRejection: Int?
    @State private var rejectionCounter = 0
    @State private var strokeTick = 0
    @State private var finishTick = 0
    @State private var errorTick = 0

    var body: some View {
        WritingCanvas(
            kana: kana,
            doneCount: attempt.doneCount,
            showGuide: showGuide,
            rejected: attempt.rejected,
            missedLoop: attempt.missedLoop,
            onDrawingChanged: { drawing in
                isDrawing.wrappedValue = drawing
                // 빨간 표시가 남아 있을 때 새 획을 시작하면 표시를 바로 지운다.
                if drawing, let pending = pendingRejection { settle(pending) }
            },
            revealsKanaToVoiceOver: revealsKanaToVoiceOver,
            onStroke: handle
        )
        .sensoryFeedback(.impact(weight: .light), trigger: strokeTick)
        .sensoryFeedback(.success, trigger: finishTick)
        .sensoryFeedback(.error, trigger: errorTick)
        .onDisappear { isDrawing.wrappedValue = false }
    }

    private func handle(_ points: [CGPoint]) {
        guard let verdict = attempt.submit(points, strokes: kana.strokes, tolerance: tolerance) else { return }
        announce()
        if verdict == .correct {
            pendingRejection = nil
            if attempt.isFinished(strokeCount: kana.strokes.count) {
                finishTick += 1
            } else {
                strokeTick += 1
            }
            return
        }

        errorTick += 1
        rejectionCounter += 1
        let id = rejectionCounter
        pendingRejection = id
        Task {
            try? await Task.sleep(for: Self.rejectedDuration)
            settle(id)
        }
    }

    private func settle(_ id: Int) {
        guard pendingRejection == id else { return }
        pendingRejection = nil
        attempt.clearRejected()
        onRejectedCleared?()
    }

    private func announce() {
        let text: String
        switch attempt.feedback {
        case .idle: return
        case .good: text = L.strokeGood
        case .bad(let verdict, let expected): text = L.verdictMessage(verdict, expectedStroke: expected)
        case .finished(let mistakes): text = finishedAnnouncement ?? L.traceFinished(mistakes: mistakes)
        }
        AccessibilityNotification.Announcement(text).post()
    }
}

/// 판정 줄. 높이를 고정해서 문구가 바뀌어도 아래 캔버스가 움직이지 않게 한다.
/// 색은 아이콘에만 주고 문구는 본문 색으로 쓴다.
struct VerdictLine: View {
    enum Kind {
        case hint, good, bad, finished, guide

        var icon: String? {
            switch self {
            case .hint: nil
            case .good: "checkmark.circle.fill"
            case .bad: "xmark.circle.fill"
            case .finished: "checkmark.seal.fill"
            case .guide: "lightbulb.fill"
            }
        }

        var tint: Color {
            switch self {
            case .hint: .inkSecondary
            case .good, .finished: .correct
            case .bad: .wrong
            case .guide: .highlightStrong
            }
        }
    }

    static let height: CGFloat = 28

    let kind: Kind
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            if let icon = kind.icon {
                Image(systemName: icon)
                    .foregroundStyle(kind.tint)
                    .accessibilityHidden(true)
            }
            Text(text)
                .foregroundStyle(kind == .hint ? Color.inkSecondary : Color.ink)
        }
        .font(.subheadline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .padding(.horizontal, 16)
    }

    /// 쓰기 상태에 맞는 판정 줄. `idleText`는 아직 긋지 않았을 때의 안내다.
    static func forAttempt(_ feedback: WritingAttempt.Feedback, idleText: String, finishedText: String? = nil) -> VerdictLine {
        switch feedback {
        case .idle:
            VerdictLine(kind: .hint, text: idleText)
        case .good:
            VerdictLine(kind: .good, text: L.strokeGood)
        case .bad(let verdict, let expected):
            VerdictLine(kind: .bad, text: L.verdictMessage(verdict, expectedStroke: expected))
        case .finished(let mistakes):
            VerdictLine(kind: .finished, text: finishedText ?? L.traceFinished(mistakes: mistakes))
        }
    }
}

/// 획 데이터로 그린 글자. 캔버스에서 쓰게 될 모양과 같게 보여 주기 위해 글꼴을 쓰지 않는다.
struct KanaGlyphView: View {
    let kana: Kana
    let side: CGFloat
    /// 획마다 시작점 번호와 고리 점선 원을 함께 그릴지.
    var showsOrder = false

    var body: some View {
        let scale = side / KanaStrokeStore.viewBox
        Canvas { context, _ in
            for stroke in kana.strokes {
                context.stroke(
                    StrokeDrawing.path(stroke, scale: scale),
                    with: .color(Color.ink),
                    style: StrokeDrawing.style(StrokeDrawing.strokeWidth * scale)
                )
            }
            guard showsOrder else { return }
            for (index, stroke) in kana.strokes.enumerated() {
                if let start = stroke.first {
                    StrokeDrawing.drawStartHint(&context, at: start, number: index + 1, scale: scale)
                }
                for loop in StrokeJudge.loops(in: stroke) {
                    StrokeDrawing.drawLoopMark(&context, at: loop.center, area: loop.area, color: Color.highlightStrong, scale: scale)
                }
            }
        }
        .frame(width: side, height: side)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }
}
