import SwiftUI
import UIKit

// 앱의 색 토큰과 루트 모양 (docs/design/visual-rules.md 1번, 2.1).
// 색 값은 Assets.xcassets의 Color Set에 있다. 코드에서는 여기의 이름만 쓴다.

extension Color {
    /// 화면 배경.
    static let appBackground = Color("AppBackground")
    /// 카드·캔버스 배경.
    static let cardBackground = Color("CardBackground")
    /// 본문.
    static let ink = Color("Ink")
    /// 보조 글자.
    static let inkSecondary = Color("InkSecondary")
    /// 카드와 선택지의 테두리.
    static let outline = Color("Outline")
    /// 강조. 주 버튼 바탕, 진행 막대, 할 차례 번호 원, 지금 글자.
    static let accent = Color("AccentColor")
    /// 강조색 위 글자(주 버튼의 글자).
    static let accentForeground = Color("AccentForeground")
    /// 힌트·강조 노랑(바탕).
    static let highlight = Color("Highlight")
    /// 힌트 선·아이콘.
    static let highlightStrong = Color("HighlightStrong")
    /// 노랑 위 글자.
    static let onHighlight = Color("OnHighlight")
    /// 맞음.
    static let correct = Color("Correct")
    /// 틀림.
    static let wrong = Color("Wrong")
}

/// 색 토큰에 얹는 불투명도와 외곽선 굵기. 여러 화면이 같은 값을 쓰도록 한곳에 둔다.
enum AppStyle {
    /// 쓰기 포인트 상자의 노랑 옅은 바탕(라이트, 다크).
    static func tipFillOpacity(_ scheme: ColorScheme) -> Double { scheme == .dark ? 0.16 : 0.18 }
    /// 지금 글자의 형광펜 바탕.
    static let currentGlyphHighlightOpacity = 0.45
    /// 답한 뒤의 나머지 선택지.
    static let dimmedOpacity = 0.4
    /// 카드와 선택지의 외곽선.
    static let outlineWidth: CGFloat = 2
    /// 답한 뒤 정답·오답 칸의 외곽선.
    static let verdictOutlineWidth: CGFloat = 3

    /// 내비게이션 바의 제목 색과 둥근 굵은 글꼴을 정한다. 앱 시작 때 한 번 부른다.
    /// 바 배경은 따로 칠하지 않고 아래 목록의 `AppBackground`가 비치게 둔다.
    /// `UINavigationBarAppearance`(불투명·투명 배경 모두)를 넣으면 iOS 26 시뮬레이터에서 큰 제목이 그려지지 않았다.
    static func configureNavigationBar() {
        let ink = UIColor(named: "Ink") ?? .label
        let bar = UINavigationBar.appearance()
        bar.titleTextAttributes = [.foregroundColor: ink, .font: roundedBold(.headline)]
        bar.largeTitleTextAttributes = [.foregroundColor: ink, .font: roundedBold(.largeTitle)]
    }

    /// 텍스트 스타일 크기의 둥근 굵은 시스템 글꼴. Dynamic Type 배율을 따른다.
    private static func roundedBold(_ style: UIFont.TextStyle) -> UIFont {
        let size = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize
        let bold = UIFont.systemFont(ofSize: size, weight: .bold)
        let rounded = bold.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? bold
        return UIFontMetrics(forTextStyle: style).scaledFont(for: rounded)
    }
}

extension View {
    /// 앱 루트의 모양: 둥근 글꼴 디자인, 본문·보조 색, 강조색.
    /// 덮개(fullScreenCover) 안에도 다시 붙인다.
    func appStyle() -> some View {
        self
            .fontDesign(.rounded)
            .foregroundStyle(Color.ink, Color.inkSecondary)
            .tint(Color.accent)
    }

    /// 카드와 선택지의 외곽선. 안쪽으로 그려서 칸 크기를 바꾸지 않는다.
    func cardOutline(cornerRadius: CGFloat, color: Color = .outline, lineWidth: CGFloat = AppStyle.outlineWidth) -> some View {
        overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(color, lineWidth: lineWidth))
    }
}
