import SwiftUI

/// 색 견본 (app-skin.md 5.2, 5.4). K 스킨 탭 52pt, C2 열린 아이템 30pt.
/// 채움은 그 색의 `AccentColor`(지금 모드 값), 안쪽 테 1pt `Ink` 15%. 아이콘은 그 색의 `AccentForeground`.
/// 화면이 미리 보는 스킨과 상관없이 늘 견본 자신의 색으로 그린다.
struct SkinSwatch: View {
    enum Mark {
        case none, check, lock

        var symbol: String? {
            switch self {
            case .none: nil
            case .check: "checkmark"
            case .lock: "lock.fill"
            }
        }
    }

    let skin: Skin
    /// 52(K) 또는 30(C2).
    let size: CGFloat
    var mark: Mark = .none

    @Environment(\.colorScheme) private var scheme

    /// 원 안 아이콘 크기: 52pt에서 20pt (5.2).
    private var iconSize: CGFloat { (size * 20 / 52).rounded() }

    var body: some View {
        let mode = SkinMode(scheme)
        Circle()
            .fill(skin.paint(.accentColor, mode: mode))
            .overlay {
                Circle().strokeBorder(Color.ink.opacity(0.15), lineWidth: 1)
            }
            .overlay {
                if let symbol = mark.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundStyle(skin.paint(.accentForeground, mode: mode))
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
