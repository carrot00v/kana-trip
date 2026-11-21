import SwiftUI

// 세션 화면이 함께 쓰는 뼈대와 작은 부품.

/// 상단 바에 보여 줄 진행. 칸 수, 지금 칸, 그 칸에서 끝낸 항목 수, 오른쪽 이름.
/// 단계 세션은 [배우기, 단어 읽기] 2칸(scene-flow.md 7.2), 종합 퀴즈는 부 수만큼의 칸과 이름 "퀴즈"(12.3).
struct PartProgress: Equatable {
    let segmentCount: Int
    let current: Int
    let name: String
    var done: Int
    var total: Int
    /// VoiceOver에 덧붙일 말(퀴즈의 부 이름).
    var detail: String?

    static func step(_ part: SessionPart, done: Int, total: Int) -> PartProgress {
        PartProgress(segmentCount: 2, current: part == .learn ? 0 : 1, name: L.partName(part), done: done, total: total)
    }

    static func quiz(partIndex: Int, partCount: Int, done: Int, total: Int, partName: String?) -> PartProgress {
        PartProgress(segmentCount: max(partCount, 1), current: partIndex, name: L.partName(.quiz), done: done, total: total, detail: partName)
    }

    /// 칸 하나가 차는 정도. 지금 칸 앞은 꽉 차고, 뒤는 비어 있다.
    func fill(of segment: Int) -> Double {
        if segment < current { return 1 }
        if segment > current { return 0 }
        return total > 0 ? min(Double(done) / Double(total), 1) : 0
    }
}

/// 상단 바: 닫기 버튼, 구간마다 같은 폭의 칸으로 나눈 진행 막대, 지금 구간 이름 (scene-flow.md 7.2).
struct SessionTopBar: View {
    let progress: PartProgress
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
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

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<progress.segmentCount, id: \.self) { segment in
                        SegmentBar(fill: progress.fill(of: segment))
                    }
                }
                Text(progress.name)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 72, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.progressLabel(name: progress.name, done: progress.done, total: progress.total, detail: progress.detail))
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
                Capsule().fill(Color.inkSecondary.opacity(0.2))
                Capsule().fill(SkinColor.accentText)
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
    /// 스킨 강도 (app-skin.md 4.1). 학습·퀴즈 화면은 권장안 값, QI 안내는 `.medium`.
    var level: SkinLevel = SkinPolicy.learningLevel
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
        .skinBackground(level)
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
                .foregroundStyle(SkinColor.accentForeground)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: ButtonMetrics.cornerRadius))
        .tint(SkinColor.accent)
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
                // 앱 루트의 `.foregroundStyle(Ink, …)`가 `.bordered`의 tint 글자색을 덮으므로 글자색을 직접 준다 (app-skin.md 1.1).
                .foregroundStyle(SkinColor.accentText)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: ButtonMetrics.cornerRadius))
        .tint(SkinColor.accentText)
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

    /// 발음 소리가 켜져 있고 `enabled`일 때만 눌러서 글자 하나를 들을 수 있게 한다.
    func speaks(kana text: String, enabled: Bool) -> some View {
        modifier(SpeakOnTap(text: text, kind: .kana, enabled: enabled))
    }

    /// 발음 소리가 켜져 있고 `enabled`일 때만 눌러서 단어 전체를 들을 수 있게 한다.
    func speaks(word text: String, enabled: Bool) -> some View {
        modifier(SpeakOnTap(text: text, kind: .word, enabled: enabled))
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

/// 누르면 처음부터 다시 읽고, 이 화면이 사라지면(다음 항목, 닫기) 이 화면이 시작한 소리를 멈춘다.
private struct SpeakOnTap: ViewModifier {
    let text: String
    let kind: SpeechKind
    let enabled: Bool
    @State private var owner = UUID()

    func body(content: Content) -> some View {
        Group {
            if enabled {
                content
                    .contentShape(Rectangle())
                    .onTapGesture { Speaker.shared.speak(text, as: kind, owner: owner) }
            } else {
                content
            }
        }
        .onDisappear { Speaker.shared.stop(owner: owner) }
    }
}
