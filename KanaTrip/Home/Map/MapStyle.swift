import SwiftUI

/// 지도가 쓰는 색을 한곳에 모은다 (docs/design/home-map.md 7.3, app-skin.md 5.1 계약).
/// 스킨(app-skin.md)이 들어오면 "스킨이 바꿈" 줄의 값만 스킨 토큰으로 바꾼다. 지도 코드는 이 이름만 쓴다.
enum MapPalette {
    // 스킨이 바꿈
    /// 지도 바탕, 아래 고정 영역 바탕.
    static let ground = Color.appBackground
    /// 길 띠 면.
    static let pathFill = Color("PathFill")
    /// 길 띠 가장자리.
    static let pathEdge = Color("PathEdge")
    /// 지난 길 진행 선, 지금 칸 원.
    static let passed = Color.accent
    /// 지금 칸 원 안의 번호·별.
    static let onPassed = Color.accentForeground

    // 고정
    /// 앞길 진행 선(점선).
    static let ahead = Color.inkSecondary
    /// 칸·알약·카드·말풍선 바탕.
    static let card = Color.cardBackground
    static let outline = Color.outline
    static let ink = Color.ink
    /// 잠긴 칸·알약 글자, 자물쇠.
    static let lockedInk = Color.inkSecondary
    /// 완료 체크.
    static let done = Color.correct
    /// 꾸미기 입구의 엔 배지.
    static let yenBadge = Color.highlightStrong
}

/// 코드로 정하는 지도 부품의 모양 값 가운데 map.json `metrics`에 없는 것 (home-map.md 2.1~2.3, 5.1).
enum MapShape {
    static let outlineWidth = AppStyle.outlineWidth
    /// 잠긴 칸의 점선(6-4).
    static let lockedDash: [CGFloat] = [6, 4]
    static let pillGap: CGFloat = 4
    static let kanaSize: CGFloat = 20
    static let kanaSpacing: CGFloat = 6
    static let pillPadding: CGFloat = 12
    static let buildingCorner: CGFloat = 16
    static let buildingBadgeInset: CGFloat = 8
    static let buildingBadgeSymbol: CGFloat = 17
    static let customizeCorner: CGFloat = 16
    static let yenBadge: CGFloat = 18
    static let yenBadgeInset: CGFloat = 6
    static let screenMargin: CGFloat = 16
    /// 기리 쪽 변에서 말풍선 몸통까지(꼬리 포함) (2.4).
    static let bubbleGap: CGFloat = 12
    /// 기리 입 높이: 칸 가운데 위 33pt (2.4).
    static let mouthAboveNode: CGFloat = 33
    static let bottomFade: CGFloat = 16
}
