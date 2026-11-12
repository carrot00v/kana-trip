import SwiftUI

/// 홈과 장면 진입에서 세션을 띄울 때 넘기는 값.
struct SessionRoute: Identifiable, Hashable {
    let sceneID: String
    let kind: SessionKind

    var id: String { "\(sceneID)-\(kind.rawValue)" }
}

/// fullScreenCover 안에서 세션과 완료 화면을 이어서 보여 준다.
struct SessionView: View {
    let scene: TripScene
    let initialKind: SessionKind
    /// 덮개를 닫고 장면 진입으로 돌아간다.
    let onClose: () -> Void
    /// 덮개를 닫고 홈까지 돌아간다.
    let onBackToList: () -> Void

    @Environment(ProgressStore.self) private var store
    @State private var stage: Stage?
    @State private var isReplay = false

    private enum Stage: Hashable {
        case running(SessionKind)
        case sessionDone(SessionKind)
        case sceneDone
    }

    var body: some View {
        Group {
            switch stage {
            case .running(.learn):
                LearnSessionView(scene: scene, onClose: onClose) { finish(.learn) }
            case .running(.quiz):
                QuizSessionView(scene: scene, isReplay: isReplay, onClose: onClose) { finish(.quiz) }
            case .running(.words):
                WordSessionView(scene: scene, onClose: onClose) { finish(.words) }
            case .sessionDone(let kind):
                SessionDoneView(scene: scene, kind: kind, isReplay: isReplay, onContinue: start, onClose: onClose)
            case .sceneDone:
                SceneDoneView(scene: scene, onBackToList: onBackToList)
            case nil:
                Color(.systemBackground)
            }
        }
        .fadeOnChange(of: stage)
        .onAppear {
            if stage == nil { start(initialKind) }
        }
    }

    private func start(_ kind: SessionKind) {
        isReplay = store.beginSession(kind, sceneID: scene.id, kana: scene.kana)
        stage = .running(kind)
    }

    /// 세션의 마지막 항목을 끝낸 뒤에 불린다. 완료는 이미 저장돼 있다.
    private func finish(_ kind: SessionKind) {
        // 단어 읽기를 처음 끝냈으면 장면 완료, 그 밖에는 세션 완료를 보여 준다.
        stage = kind == .words && !isReplay ? .sceneDone : .sessionDone(kind)
    }
}
