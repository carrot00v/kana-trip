import SwiftUI

/// 지도가 쓰는 색을 한곳에 모은다 (docs/design/home-map.md 7.3, "2026-11-18 시각 정리" S3·S4).
/// "스킨이 바꿈" 줄은 저장된 스킨(app-skin.md 4.2, 5.1)을 따른다. 지도 코드는 이 이름만 쓴다.
/// 홈은 K의 미리 보기와 상관없이 늘 저장된 스킨이라 환경값 대신 `SkinStore.shared`를 읽는다.
/// 읽은 화면은 착용 상태가 바뀌면 다시 그려진다(Observation). 다크·대비 증가는 Color가 스스로 따른다.
enum MapPalette {
    // 스킨이 바꿈
    /// 지도 바탕, 아래 고정 영역 바탕, 건물 이름 가림 캡슐. 대비 증가면 `AppBackgroundQuiet`(app-skin.md 2.5).
    static var ground: Color { SkinStore.shared.current.dynamicBackground(level: .strong) }
    /// 지도 뒤 층: 바탕색 + 화면에 고정된 무늬(강 단계 × 1, app-skin.md 4.2).
    static var groundLayer: some View { SkinBackdrop(level: .strong).environment(\.skin, SkinStore.shared.current) }
    /// 앞길 선 4pt, 잠김 칸 테.
    static var ahead: Color { SkinStore.shared.current.dynamicColor(.pathEdge) }

    // 고정
    /// 지난 길 선 6pt, 완료 칸 테 (2026-11-18에 AccentColor에서 바꿈).
    static let passed = Color.inkSecondary
    /// 지금 칸 발판(`Highlight` 위에 불투명도를 얹어 쓴다).
    static let footSpot = Color.highlight
    /// 칸 원·말풍선 바탕.
    static let card = Color.cardBackground
    /// 말풍선과 지금 장면 건물 카드의 테두리. 지도에서 이 두 곳만 쓴다(S3).
    static let outline = Color.outline
    static let ink = Color.ink
    /// 칸 라벨, 잠긴 이름, 자물쇠.
    static let quietInk = Color.inkSecondary
    /// 완료 체크.
    static let done = Color.correct
    /// 꾸미기 입구의 엔 배지.
    static let yenBadge = Color.highlightStrong
    /// 꾸미기 입구·"지금 칸으로" 바탕(강조색 위에 불투명도). 스킨을 따른다.
    static var softAccent: Color { SkinStore.shared.current.dynamicColor(.accentText) }

    /// 지금 칸 발판의 불투명도 (2.1). 다크는 0.45에서 탁한 올리브색으로 보여 S8의 대안 0.6을 쓴다(구현 값).
    static func footSpotOpacity(_ scheme: ColorScheme) -> Double { scheme == .dark ? 0.6 : 0.45 }
    static let softAccentOpacity = 0.12
}

/// 코드로 정하는 지도 부품의 모양 값 가운데 map.json `metrics`에 없는 것 (home-map.md 2.1~2.3, 3.2, 5.1).
enum MapShape {
    /// 말풍선·지금 장면 건물의 굵은 외곽선.
    static let outlineWidth = AppStyle.outlineWidth
    static let kanaLabelSize: CGFloat = 17
    static let kanaLabelSpacing: CGFloat = 4
    static let lockSymbol: CGFloat = 13
    static let checkStep: CGFloat = 14
    static let checkQuiz: CGFloat = 16
    static let buildingCorner: CGFloat = 16
    static let buildingSmallCorner: CGFloat = 12
    static let nameCapsuleHeight: CGFloat = 22
    static let nameCapsulePadding: CGFloat = 8
    static let nameIconGap: CGFloat = 4
    /// 지금 칸의 누르는 영역(기리 밑, 2.1).
    static let currentTapArea: CGFloat = 56
    /// 칸·라벨의 최소 누르는 높이.
    static let minTapHeight: CGFloat = 44
    static let customizeCorner: CGFloat = 16
    static let yenBadge: CGFloat = 18
    static let yenBadgeInset: CGFloat = 6
    static let screenMargin: CGFloat = 16
    /// 기리 쪽 변에서 말풍선 몸통까지(꼬리 포함) (2.4).
    static let bubbleGap: CGFloat = 12
    /// 기리 입 높이: 칸 가운데 위 33pt (2.4).
    static let mouthAboveNode: CGFloat = 33
    static let bottomFade: CGFloat = 16
    /// "지금 칸으로": 보이는 캡슐 36, 누르는 영역 44, 좌우 안쪽 12 (3.2).
    static let jumpCapsule: CGFloat = 36
    static let jumpPadding: CGFloat = 12
}
