import Foundation

/// 지도가 마지막으로 기리를 세워 보여 준 칸 (docs/design/home-map.md 4.1, 4.5).
/// 진도 저장 형식(`ProgressStorage`)과 따로 둔 화면 상태라, 진도 형식이 바뀌어도 영향이 없다.
final class MapShownStore {
    static let key = "map.lastShownNodeID"

    private let defaults: UserDefaults
    /// DEBUG 실행 인자로 시작 값을 정했을 때 저장소 대신 이 값을 쓴다(실제 저장을 건드리지 않게).
    private var override: String??

    init(defaults: UserDefaults = .standard, override: String?? = nil) {
        self.defaults = defaults
        self.override = override
    }

    var shownNodeID: String? {
        get {
            if let override { return override }
            return defaults.string(forKey: Self.key)
        }
        set {
            if override != nil {
                override = .some(newValue)
                return
            }
            defaults.set(newValue, forKey: Self.key)
        }
    }
}
