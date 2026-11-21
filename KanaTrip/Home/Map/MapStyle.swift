import SwiftUI

/// 지도가 쓰는 색을 한곳에 모은다 (docs/design/home-map.md 7.3, "2026-11-21 재구성안" R2.3).
/// "스킨이 바꿈" 줄은 저장된 스킨(app-skin.md 4.2, 5.1)을 따른다. 지도 코드는 이 이름만 쓴다.
/// 홈은 K의 미리 보기와 상관없이 늘 저장된 스킨이라 환경값 대신 `SkinStore.shared`를 읽는다.
/// 읽은 화면은 착용 상태가 바뀌면 다시 그려진다(Observation). 다크·대비 증가는 Color가 스스로 따른다.
enum MapPalette {
    // 스킨이 바꿈
    /// 지도 바탕, 아래 고정 영역 바탕, 잠긴 칸 안. 대비 증가면 `AppBackgroundQuiet`(app-skin.md 2.5).
    static var ground: Color { SkinStore.shared.current.dynamicBackground(level: .strong) }
    /// 지도 뒤 층: 바탕색 + 화면에 고정된 무늬(강 단계 × 1, app-skin.md 4.2).
    static var groundLayer: some View { SkinBackdrop(level: .strong).environment(\.skin, SkinStore.shared.current) }
    /// 점선, 잠김 칸 테.
    static var ahead: Color { SkinStore.shared.current.dynamicColor(.pathEdge) }

    // 고정
    /// 완료 칸 테 (R2.3).
    static let passed = Color.inkSecondary
    /// 지금 칸 바탕. 지도에서 유일한 노랑 면 (R2.3).
    static let current = Color.highlight
    /// 지금 칸의 가나.
    static let onCurrent = Color.onHighlight
    /// 완료 칸·말풍선 바탕.
    static let card = Color.cardBackground
    /// 말풍선과 지금 장면 띠 그림의 테두리. 지도에서 이 두 곳만 쓴다(R2.3 예산).
    static let outline = Color.outline
    static let ink = Color.ink
    /// 잠긴 칸 글자, 띠의 글자 줄, 자물쇠.
    static let quietInk = Color.inkSecondary
    /// 완료 체크.
    static let done = Color.correct
    /// 꾸미기 입구의 엔 배지.
    static let yenBadge = Color.highlightStrong
    /// 꾸미기 입구·"지금 칸으로" 바탕(강조색 위에 불투명도). 스킨을 따른다.
    static var softAccent: Color { SkinStore.shared.current.dynamicColor(.accentText) }

    static let softAccentOpacity = 0.12
}

/// 코드로 정하는 지도 부품의 모양 값 가운데 map.json `metrics`에 없는 것 (home-map.md R2.3, 3.2, 5.1, "구현 메모").
enum MapShape {
    /// 말풍선·지금 장면 띠 그림의 굵은 외곽선.
    static let outlineWidth = AppStyle.outlineWidth
    /// 칸 안 가나 20pt, 글자 사이 4 (R2.3).
    static let nodeKanaSize: CGFloat = 20
    static let nodeKanaSpacing: CGFloat = 4
    /// 칸 안 상태 아이콘 17pt, 아이콘과 가나 사이 6, 캡슐 안쪽 좌우 12.
    static let nodeIcon: CGFloat = 17
    static let nodeIconGap: CGFloat = 6
    static let nodePadding: CGFloat = 12
    /// 띠의 가나 줄 17pt, 글자 사이 4.
    static let bandKanaSize: CGFloat = 17
    static let bandKanaSpacing: CGFloat = 4
    static let bandArtCorner: CGFloat = 12
    /// 띠 그림 오른쪽 변에서 글자까지.
    static let bandTextGap: CGFloat = 12
    /// 띠 글자와 스티커 칸 사이에 남길 최소 간격(구현 값).
    static let bandStickerClear: CGFloat = 12
    static let nameIconGap: CGFloat = 4
    /// 칸·라벨의 최소 누르는 높이.
    static let minTapHeight: CGFloat = 44
    static let customizeCorner: CGFloat = 16
    static let yenBadge: CGFloat = 18
    static let yenBadgeInset: CGFloat = 6
    static let screenMargin: CGFloat = 16
    /// 한 줄 말풍선: 모서리 14, 글자 좌우 안쪽 14(구현 값), 꼬리 밑변 14·길이 8 (R2.3).
    static let bubbleCorner: CGFloat = 14
    static let bubblePadding: CGFloat = 14
    static let bubbleTailBase: CGFloat = 14
    static let bubbleTailLength: CGFloat = 8
    static let bottomFade: CGFloat = 16
    /// "지금 칸으로" 원 버튼의 화살표 17pt, 아래 고정 영역 위 12 (R2.3).
    static let jumpIcon: CGFloat = 17
    static let jumpBottom: CGFloat = 12
}
