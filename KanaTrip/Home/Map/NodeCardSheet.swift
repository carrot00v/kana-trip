import SwiftUI

/// 칸 카드: 지난 칸 다시 하기, 지금 칸 시작, 앞 칸 미리 보기 (docs/design/home-map.md 3.3).
/// 시트를 닫은 뒤에 세션이나 S를 띄운다(시트와 덮개를 겹치지 않는다). 무엇을 띄울지는 `onChoose`로 돌려준다.
struct NodeCardSheet: View {
    enum Choice {
        case session(TripSession)
        case sceneWords(String)
    }

    let session: TripSession
    let state: MapNodeState
    let onChoose: (Choice) -> Void

    @Environment(ProgressStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss

    private var library: ContentLibrary { .shared }

    /// 콘텐츠 276pt. 잠긴 칸은 주 버튼 + 간격 60pt를 뺀 216pt (3.3).
    /// 잠긴 장면(건물이 잠김)의 칸은 "장면 단어 전체 보기"도 빼고 168pt (구현 값).
    static func height(state: MapNodeState, sceneOpen: Bool) -> CGFloat {
        var h: CGFloat = 276
        if state == .locked { h -= 60 }
        if !sceneOpen { h -= 48 }
        return h
    }

    var body: some View {
        let scene = library.scene(of: session)
        let sceneOpen = scene.map(store.isSceneUnlocked) ?? false
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L.nodeCardTitle(scene: scene?.name ?? "", session: L.sessionName(session)))
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                    .frame(minHeight: 24)
                statusLine
                    .padding(.top, 4)
                    .frame(minHeight: 20)
                KanaText(text: kana(scene).joined(separator: "  "), size: 34)
                    .foregroundStyle(state == .locked ? Color.inkSecondary : Color.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .padding(.top, 16)
                    .accessibilityLabel(Text(KanaText.japanese(kana(scene).joined(separator: " "))))
                wordLine(scene)
                    .frame(minHeight: 28)
                    .padding(.top, 12)
                if state != .locked {
                    PrimaryButton(title: buttonTitle) {
                        onChoose(.session(session))
                        dismiss()
                    }
                    .padding(.top, 16)
                }
                if sceneOpen, let scene {
                    Button {
                        onChoose(.sceneWords(scene.id))
                        dismiss()
                    } label: {
                        Text(L.allSceneWords)
                            .font(.headline)
                            .foregroundStyle(Color.accent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, state == .locked ? 16 : 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.appBackground)
        .presentationDetents(typeSize >= .xLarge ? [.medium] : [.height(Self.height(state: state, sceneOpen: sceneOpen))])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }

    private func kana(_ scene: TripScene?) -> [String] {
        session.step?.kana ?? scene?.kana ?? []
    }

    private var isInProgress: Bool { store.isInProgress(session) }

    private var buttonTitle: String {
        switch state {
        case .completed: L.redo
        case .current: isInProgress ? L.resume : L.start
        case .locked: ""
        }
    }

    private var turnSymbol: String {
        session.isQuiz ? "star.circle.fill" : "\(session.number).circle.fill"
    }

    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: 6) {
            switch state {
            case .current:
                Image(systemName: turnSymbol).foregroundStyle(Color.accent)
                Text(isInProgress ? L.nodeResume : L.nodeMyTurn)
            case .completed:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.correct)
                Text(L.nodeDone)
            case .locked:
                Image(systemName: "lock.fill").foregroundStyle(Color.inkSecondary)
                Text(L.nodeLocked(previous: MapCopy.previousSessionName(of: session)))
            }
        }
        .font(.subheadline)
        .foregroundStyle(Color.inkSecondary)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func wordLine(_ scene: TripScene?) -> some View {
        if let step = session.step {
            let words = library.shownGoalWords(for: step)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(L.goalWordsTitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                KanaText(text: words.map(\.text).joined(separator: "  "), size: 22, weight: .bold)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(AttributedString("\(L.goalWordsTitle), ") + KanaText.japanese(words.map(\.text).joined(separator: ", "))))
        } else if let scene {
            let summary = store.quizSummary(for: scene)
            Text(L.quizRowSummary(kana: scene.kana.count, words: summary.words, review: summary.review))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.inkSecondary)
        }
    }
}

/// 지도의 칸 문구 가운데 여러 곳(칸 카드, VoiceOver, 알림)이 같이 쓰는 것.
enum MapCopy {
    /// "{앞 세션}을 끝내면 열려요"의 앞 세션: 같은 장면이면 단계 이름 또는 "종합 퀴즈", a 칸이면 "{앞 장면} 종합 퀴즈" (3.3).
    static func previousSessionName(of session: TripSession, library: ContentLibrary = .shared) -> String {
        guard let previous = library.sessions.last(where: { $0.globalIndex < session.globalIndex }) else { return "" }
        if previous.sceneID == session.sceneID { return L.sessionName(previous) }
        let scene = library.scene(of: previous)?.name ?? ""
        return "\(scene) \(L.sessionName(previous))"
    }
}
