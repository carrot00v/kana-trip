import SwiftUI

/// C1 세션 완료.
struct SessionDoneView: View {
    let scene: TripScene
    let kind: SessionKind
    /// 이미 끝냈던 세션을 다시 한 것인지.
    let isReplay: Bool
    let onContinue: (SessionKind) -> Void
    let onClose: () -> Void

    @Environment(ProgressStore.self) private var store
    @State private var appearTick = 0

    private var wrongKana: [String] {
        guard kind == .quiz else { return [] }
        // 아래 글자 줄과 같은 순서로 보여 준다.
        let wrong = store.progress(for: scene.id).wrongKana
        return scene.kana.filter { wrong.contains($0) }
    }

    private var summary: String {
        switch kind {
        case .learn: L.learnSummary(scene.kana.count)
        case .quiz: wrongKana.isEmpty ? L.quizSummaryPerfect(scene.kana.count) : L.quizSummaryWrong(wrongKana)
        case .words: L.wordsSummary(scene: scene.name, count: scene.words.count)
        }
    }

    var body: some View {
        CompletionLayout {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
        } texts: {
            Text(L.sessionDone(kind)).font(.title2.bold())
            Text(summary).font(.body).foregroundStyle(.secondary)
        } detail: {
            KanaRow(kana: scene.kana, marked: Set(wrongKana))
        } buttons: {
            if !isReplay, let next = kind.next {
                PrimaryButton(title: L.sessionAction(next, resume: false)) { onContinue(next) }
                Button(action: onClose) {
                    Text(L.stopHere)
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                PrimaryButton(title: L.backToScene, action: onClose)
            }
        }
        .sensoryFeedback(.success, trigger: appearTick)
        .onAppear { appearTick += 1 }
    }
}

/// C2 장면 완료.
struct SceneDoneView: View {
    let scene: TripScene
    let onBackToList: () -> Void

    @State private var appearTick = 0

    var body: some View {
        let next = ContentLibrary.shared.scene(after: scene)
        CompletionLayout {
            Image(systemName: scene.icon ?? "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                        .background(Color(.systemBackground), in: Circle())
                        .offset(x: 8, y: 4)
                }
                .accessibilityHidden(true)
        } texts: {
            Text(L.sceneDone(scene.name)).font(.title2.bold())
            Text(L.sceneSummary(scene.kana.count)).font(.body).foregroundStyle(.secondary)
        } detail: {
            KanaRow(kana: scene.kana, marked: [])
            if let next {
                VStack(spacing: 8) {
                    Text(L.nextSceneOpened(next.name)).font(.body)
                    Text(KanaText.japanese(next.kana.joined(separator: " ")))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .environment(\.locale, Locale(identifier: "ja"))
                }
                .padding(.top, 24)
            }
        } buttons: {
            PrimaryButton(title: L.backToSceneList, action: onBackToList)
        }
        .sensoryFeedback(.success, trigger: appearTick)
        .onAppear { appearTick += 1 }
    }
}

/// 완료 화면의 배치. 아이콘이 화면 높이의 위에서 3분의 1쯤에 오고 버튼은 아래에 고정된다.
private struct CompletionLayout<Icon: View, Texts: View, Detail: View, Buttons: View>: View {
    @ViewBuilder let icon: Icon
    @ViewBuilder let texts: Texts
    @ViewBuilder let detail: Detail
    @ViewBuilder let buttons: Buttons

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 24) {
                        icon
                        VStack(spacing: 8) { texts }
                            .multilineTextAlignment(.center)
                        detail
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geo.size.height / 3 - 64, 24))
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            VStack(spacing: 4) { buttons }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
}

/// 글자 줄(34pt). 표시할 글자 아래에는 주황 점을 붙인다.
struct KanaRow: View {
    let kana: [String]
    let marked: Set<String>

    var body: some View {
        HStack(spacing: 16) {
            ForEach(kana, id: \.self) { char in
                VStack(spacing: 4) {
                    KanaText(text: char, size: 34)
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                        .opacity(marked.contains(char) ? 1 : 0)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}
