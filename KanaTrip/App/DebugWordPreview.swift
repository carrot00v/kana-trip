#if DEBUG
import SwiftUI

/// 디버그 빌드 전용 실행 인자. 화면 검수 스크린샷을 찍으려고 둔다(릴리스 빌드에는 들어가지 않는다).
///
/// `-debugWord <번호>`: 단어 데이터 순서(장면 → 단계 → 단어, 0부터)로 그 단어의 W 단어 읽기를 "읽기 확인" 뒤 모습으로 바로 띄운다.
/// 진도는 메모리에만 두어 기기의 progress.json을 읽거나 쓰지 않는다.
///
///   xcrun simctl launch <기기> com.carrotlab.kanatrip -debugWord 12
enum DebugLaunch {
    static var wordIndex: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let at = args.firstIndex(of: "-debugWord"), at + 1 < args.count else { return nil }
        return Int(args[at + 1])
    }
}

private final class DebugMemoryStorage: ProgressStorage {
    private var state: ProgressState?
    func load() -> ProgressState? { state }
    func save(_ state: ProgressState) { self.state = state }
}

/// `-debugWord`로 띄우는 W 화면. 그 단어가 든 단계의 세션으로 `WordSessionView`를 그대로 쓴다.
struct DebugWordPreview: View {
    @State private var store: ProgressStore
    @State private var run: SessionRun?
    private let word: String?

    init(index: Int, library: ContentLibrary = .shared) {
        let store = ProgressStore(storage: DebugMemoryStorage())
        let entries = library.scenes.flatMap { scene in scene.steps.flatMap { step in step.words.map { (step, $0) } } }
        _store = State(initialValue: store)
        if entries.indices.contains(index), let session = library.session(id: entries[index].0.id) {
            _run = State(initialValue: SessionRun(session: session, store: store, library: library))
            word = entries[index].1.text
        } else {
            _run = State(initialValue: nil)
            word = nil
        }
    }

    var body: some View {
        if let run, let word {
            WordSessionView(run: run, onClose: {}, onFinished: {}, debugWord: word)
                .environment(store)
        } else {
            Text("단어 번호가 범위를 벗어났다")
        }
    }
}
#endif
