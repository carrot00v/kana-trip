import SwiftUI

// 세션 화면이 함께 쓰는 뼈대와 작은 부품.

/// 상단 바: 닫기 버튼, 진행 막대, 진행 숫자.
struct SessionTopBar: View {
    let done: Int
    let total: Int
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.close)
            .accessibilityHint(L.closeHint)

            HStack(spacing: 0) {
                ProgressView(value: Double(min(done, total)), total: Double(max(total, 1)))
                    .tint(Color.accent)
                Text("\(done) / \(total)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 56, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.progressLabel(done: done, total: total))
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
        .frame(height: 44)
    }
}

/// 세션 화면의 공통 배치: 상단 바, 내용, 아래 버튼 영역.
struct SessionScaffold<Content: View, Bottom: View>: View {
    let done: Int
    let total: Int
    let onClose: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let bottom: Bottom

    var body: some View {
        VStack(spacing: 0) {
            SessionTopBar(done: done, total: total, onClose: onClose)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            BottomBar { bottom }
        }
        .background(Color.appBackground)
    }
}

/// 아래 버튼 영역. 모든 세션 화면에서 같은 자리에 둔다.
struct BottomBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) { content }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
}

struct PrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: ButtonMetrics.labelHeight)
                // `.borderedProminent`는 다크에서도 글자를 흰색으로 그려 크림색 강조색 위에서 보이지 않는다.
                .foregroundStyle(Color.accentForeground)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: ButtonMetrics.cornerRadius))
        .tint(Color.accent)
        .controlSize(.large)
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: ButtonMetrics.secondaryLabelWidth)
                .frame(minHeight: ButtonMetrics.labelHeight)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: ButtonMetrics.cornerRadius))
        .tint(Color.accent)
        .controlSize(.large)
        .disabled(!enabled)
    }
}

enum ButtonMetrics {
    /// `.controlSize(.large)`의 위아래 여백과 합쳐 버튼 높이가 56pt가 되게 하는 글자 영역 높이.
    static let labelHeight: CGFloat = 28
    /// 보조 버튼의 폭 112pt에서 좌우 여백을 뺀 글자 영역 폭.
    static let secondaryLabelWidth: CGFloat = 72
    /// 주 버튼과 보조 버튼의 모서리 반지름.
    static let cornerRadius: CGFloat = 16
}

/// 쓰기 포인트 상자. 카드 바탕 위에 노랑을 옅게 깔고 외곽선은 두지 않는다.
struct TipBox: View {
    let text: String
    var lineLimit: Int? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color.highlightStrong)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(Color.ink)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.highlight.opacity(AppStyle.tipFillOpacity(colorScheme)))
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L.tipPrefix), \(text)")
    }
}

/// 시스템 글꼴로 쓰는 가나. 한국어 기기에서도 일본어 글꼴로 그리고 VoiceOver가 일본어로 읽게 한다.
struct KanaText: View {
    let text: String
    let size: CGFloat
    var weight: Font.Weight = .regular

    var body: some View {
        Text(Self.japanese(text))
            .font(.system(size: size, weight: weight))
            .environment(\.locale, Locale(identifier: "ja"))
    }

    static func japanese(_ text: String) -> AttributedString {
        var string = AttributedString(text)
        string.languageIdentifier = "ja"
        return string
    }
}

/// 발음 소리가 켜져 있을 때 글자 옆에 붙는 아이콘.
struct SpeakerBadge: View {
    var body: some View {
        Image(systemName: "speaker.wave.2.fill")
            .font(.subheadline)
            .foregroundStyle(Color.inkSecondary)
            .accessibilityHidden(true)
    }
}

extension View {
    /// 세션 안에서 항목이 바뀔 때 내용만 0.2초 페이드로 바꾼다. "동작 줄이기"가 켜져 있으면 바로 바꾼다.
    func fadeOnChange<Key: Hashable>(of key: Key) -> some View {
        modifier(FadeOnChange(key: key))
    }

    /// 발음 소리가 켜져 있고 `enabled`일 때만 눌러서 들을 수 있게 한다.
    func speaks(_ text: String, enabled: Bool) -> some View {
        modifier(SpeakOnTap(text: text, enabled: enabled))
    }
}

private struct FadeOnChange<Key: Hashable>: ViewModifier {
    let key: Key
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
                .id(key)
                .transition(.opacity)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: key)
    }
}

private struct SpeakOnTap: ViewModifier {
    let text: String
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .contentShape(Rectangle())
                .onTapGesture { Speaker.shared.speak(text) }
        } else {
            content
        }
    }
}
