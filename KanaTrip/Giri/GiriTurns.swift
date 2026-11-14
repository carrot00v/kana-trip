import Foundation

// 진도에서 홈(H)과 장면 진입(S)의 기리 대사 상태를 고른다 (giri-companion.md 3.2, 3.3, 3.11).
// 주 버튼이 시작하는 세션과 같은 기준을 쓴다.

extension ProgressStore {
    /// 홈 주 버튼이 시작할 장면과 세션: 열린(끝내지 않은) 첫 장면의 다음 세션.
    func homeTarget(in library: ContentLibrary = .shared) -> (scene: TripScene, session: TripSession)? {
        guard let scene = library.scenes.first(where: { !isSceneCompleted($0) && isSceneUnlocked($0) }),
              scene.hasContent,
              let session = nextSession(in: scene)
        else { return nil }
        return (scene, session)
    }

    func giriHomeTurn(in library: ContentLibrary = .shared) -> GiriSpeech.HomeTurn {
        if !library.scenes.isEmpty, library.scenes.allSatisfy(isSceneCompleted) { return .allDone }
        guard let (scene, session) = homeTarget(in: library) else { return .comingSoon }
        if isInProgress(session) { return .resume(scene: scene.name, session: L.sessionName(session)) }
        guard let step = session.step else { return .quiz(scene: scene.name) }
        if step.index > 0 { return .stepB(scene: scene.name, step: step.name) }
        if scene.order == library.scenes.first?.order { return .first(scene: scene.name) }
        return .newScene(scene: scene.name, step: step.name)
    }

    func giriSceneTurn(_ scene: TripScene) -> GiriSpeech.SceneTurn {
        if isSceneCompleted(scene) { return .done(scene: scene.name) }
        guard let session = nextSession(in: scene) else {
            return .stepA(scene: scene.name, step: scene.steps.first?.name ?? "", intro: scene.giriIntro)
        }
        if isInProgress(session) { return .resume(session: L.sessionName(session)) }
        guard let step = session.step else { return .quiz }
        if step.index > 0 { return .stepB(step: step.name) }
        return .stepA(scene: scene.name, step: step.name, intro: scene.giriIntro)
    }
}
