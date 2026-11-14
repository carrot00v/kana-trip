import SwiftUI

// 보상 연동: C1·C2의 기리 캐릭터, 받은 엔 줄, 아이템 줄, "기리 꾸미기" 버튼은 보상 브랜치(reward-flow.md)가 들어오면 붙인다.
// 재화 지급 키는 단계 id(`TripStep.id`, 예: sushi-a)다. 지급 자리는 `StepRun.complete()` → `ProgressStore.complete(_:quizWrong:)`.

/// C1 단계 완료 (scene-flow.md 13번). 단계 a를 처음 끝냈을 때와 끝낸 단계를 다시 했을 때 나온다.
struct StepDoneView: View {
    let run: StepRun
    /// 같은 덮개 안에서 다음 단계를 시작한다.
    let onContinue: (TripStep) -> Void
    let onClose: () -> Void

    @State private var appearTick = 0

    var body: some View {
        let library = ContentLibrary.shared
        let step = run.step
        let next = run.isReplay ? nil : library.step(after: step)
        let goalWords = library.shownGoalWords(for: step)
        CompletionLayout {
            // 보상 브랜치가 들어오기 전에는 기리 대신 체크 아이콘을 둔다.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
        } texts: {
            Text(L.stepDone(scene: run.scene.name, step: step.name)).font(.title2.bold())
            Text(L.stepSummary(kana: step.kana.count, words: step.words.count)).font(.body).foregroundStyle(.secondary)
        } detail: {
            KanaRow(kana: step.kana, marked: Set(run.progress.quizWrong))
            if !goalWords.isEmpty {
                GoalWordsBlock(title: L.nowReadable, words: goalWords)
            }
        } buttons: {
            if let next {
                PrimaryButton(title: L.stepAction(next.name, resume: false)) { onContinue(next) }
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

/// C2 장면 완료 (scene-flow.md 14번). 단계 b를 처음 끝냈을 때만 나온다.
struct SceneDoneView: View {
    let scene: TripScene
    let onBackToList: () -> Void

    @State private var appearTick = 0

    var body: some View {
        let library = ContentLibrary.shared
        let next = library.scene(after: scene)
        let goalWords = library.goalWords(for: scene)
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
            if !goalWords.isEmpty {
                GoalWordsBlock(title: L.readableWords(scene.name), words: goalWords)
            }
            if let next {
                Text(L.nextSceneOpened(next.name))
                    .font(.body)
                    .padding(.top, 8)
            }
        } buttons: {
            PrimaryButton(title: L.backToSceneList, action: onBackToList)
        }
        .sensoryFeedback(.success, trigger: appearTick)
        .onAppear { appearTick += 1 }
    }
}

/// "이제 읽을 수 있는 단어"와 단어 묶음(22pt, 굵게). 넘치면 줄을 바꾼다. 누를 수 없다.
private struct GoalWordsBlock: View {
    let title: String
    let words: [TripWord]

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            CenteredFlow(spacing: 16, lineSpacing: 8) {
                ForEach(words) { word in
                    KanaText(text: word.text, size: 22, weight: .bold)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(AttributedString("\(title), ") + KanaText.japanese(words.map(\.text).joined(separator: ", "))))
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
