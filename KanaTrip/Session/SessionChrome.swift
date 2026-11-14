import SwiftUI

// 세션 화면이 함께 쓰는 뼈대와 작은 부품.

/// 상단 바에 보여 줄 진행. 지금 구간과 그 구간에서 끝낸 항목 수.
struct PartProgress: Equatable {
    let part: SessionPart
    var done: Int
    var total: Int

    /// 칸 하나가 차는 정도. 지금 구간 앞의 칸은 꽉 차고, 뒤의 칸은 비어 있다.
    func fill(of segment: SessionPart) -> Double {
        if segment.rawValue < part.rawValue { return 1 }
        if segment.rawValue > part.rawValue { return 0 }
        return total > 0 ? min(Double(done) / Double(total), 1) : 0
    }
}

/// 상단 바: 닫기 버튼, 같은 폭 3칸 진행 막대, 지금 구간 이름 (scene-flow.md 7.2).
struct SessionTopBar: View {
    let progress: PartProgress
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.close)
            .accessibilityHint(L.closeHint)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(SessionPart.allCases, id: \.self) { segment in
                        SegmentBar(fill: progress.fill(of: segment))
                    }
                }
                Text(L.partName(progress.part))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 72, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.progressLabel(part: progress.part, done: progress.done, total: progress.total))
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
        .frame(height: 44)
    }
}

/// 진행 막대의 칸 하나. 높이 4pt, 모서리 2pt.
private struct SegmentBar: View {
    let fill: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(Color.accentColor)
                    .frame(width: geo.size.width * fill)
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 0.2), value: fill)
    }
}

/// 세션 화면의 공통 배치: 상단 바, 내용, 아래 버튼 영역.
struct SessionScaffold<Content: View, Bottom: View>: View {
    let progress: PartProgress
    let onClose: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let bottom: Bottom

    var body: some View {
        VStack(spacing: 0) {
            SessionTopBar(progress: progress, onClose: onClose)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            BottomBar { bottom }
        }
        .background(Color(.systemBackground))
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
        }
        .buttonStyle(.borderedProminent)
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
        .controlSize(.large)
        .disabled(!enabled)
    }
}

enum ButtonMetrics {
    /// `.controlSize(.large)`의 위아래 여백과 합쳐 버튼 높이가 56pt가 되게 하는 글자 영역 높이.
    static let labelHeight: CGFloat = 28
    /// 보조 버튼의 폭 112pt에서 좌우 여백을 뺀 글자 영역 폭.
    static let secondaryLabelWidth: CGFloat = 72
}

/// 쓰기 포인트 상자.
struct TipBox: View {
    let text: String
    var lineLimit: Int? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(text)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
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
            .foregroundStyle(.secondary)
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
