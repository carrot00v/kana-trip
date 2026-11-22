import SwiftUI

// 보상 연동: 재화 지급 키는 세션 id(`sushi-a`, `sushi-b`, `sushi-quiz`)이고, 세션을 처음 끝낼 때마다 100엔이다.
// 장면의 아이템은 종합 퀴즈를 처음 통과할 때 열린다. 지급 자리는 `SessionRun.complete()` → `ProgressStore.complete(_:quizWrong:)`.

/// C1 세션 완료 (scene-flow.md 13번). 단계 a·b를 처음 끝냈을 때와 끝낸 세션을 다시 했을 때 나온다.
struct StepDoneView: View {
    let run: SessionRun
    /// 이번 지급. 다시 한 세션이면 받은 엔이 0이라 받은 엔 줄을 그리지 않는다.
    let grant: RewardGrant
    /// 같은 덮개 안에서 다음 세션을 시작한다.
    let onContinue: (TripSession) -> Void
    let onClose: () -> Void

    @State private var appearTick = 0

    var body: some View {
        let library = ContentLibrary.shared
        let next = run.isReplay ? nil : library.session(after: run.session)
        CompletionLayout(giriLine: giriLine, level: .medium) {
            Text(title).font(.title2.bold())
            Text(summary).font(.body).foregroundStyle(Color.inkSecondary)
        } detail: {
            if let step = run.step {
                KanaRow(kana: step.kana, marked: [])
                let goalWords = library.shownGoalWords(for: step)
                if !goalWords.isEmpty {
                    GoalWordsBlock(title: L.nowReadable, words: goalWords)
                }
            } else {
                // 다시 한 종합 퀴즈: 이번에 틀린 글자 밑에 점과 안내 한 줄 (scene-flow.md 11번 3).
                let wrong = run.scene.kana.filter(run.progress.quizWrong.contains)
                VStack(spacing: 16) {
                    KanaRow(kana: run.scene.kana, marked: Set(wrong))
                    if !run.progress.quizWrong.isEmpty {
                        Text(L.confusedThisTime(run.progress.quizWrong))
                            .font(.subheadline)
                            .foregroundStyle(Color.ink)
                    }
                }
                let goalWords = library.goalWords(for: run.scene)
                if !goalWords.isEmpty {
                    GoalWordsBlock(title: L.nowReadable, words: goalWords)
                }
            }
            if grant.coins > 0 {
                CoinsReceivedLine(received: grant.coins, balance: grant.balance)
            }
        } buttons: {
            if let next {
                PrimaryButton(title: next.isQuiz ? L.quizSessionStart : L.stepAction(next.step?.name ?? "", resume: false)) {
                    onContinue(next)
                }
                Button(action: onClose) {
                    Text(L.stopHere)
                        .font(.headline)
                        .foregroundStyle(SkinColor.accentText)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                // 세션을 닫으면 늘 지도로 돌아간다 (home-map.md 3.4).
                PrimaryButton(title: L.backToSceneList, action: onClose)
            }
        }
        .sensoryFeedback(.success, trigger: appearTick)
        .onAppear { appearTick += 1 }
    }

    /// 같이 다녀온 느낌만 더한다. 제목·요약과 같은 말을 되풀이하지 않는다 (giri-companion.md 3.9, 3.11).
    private var giriLine: String {
        let completion: GiriSpeech.Completion
        if run.isReplay {
            completion = run.session.isQuiz ? .quizReplay : .stepReplay
        } else if let step = run.step, step.index == 0, let next = ContentLibrary.shared.step(after: step) {
            completion = .stepA(step: step.name, next: next.name)
        } else {
            completion = .stepB
        }
        return GiriSpeech.completion(completion)
    }

    private var title: String {
        L.stepDone(scene: run.scene.name, step: run.step?.name ?? L.quizSessionName)
    }

    private var summary: String {
        guard let step = run.step else { return L.quizAllCorrect(run.progress.quiz?.totalCount ?? 0) }
        return L.stepSummary(kana: step.kana.count, words: step.words.count)
    }
}

/// C2 장면 완료 (scene-flow.md 14번). 종합 퀴즈를 처음 통과했을 때만 나온다.
/// 배운 글자 줄과 다음 장면의 새 글자 줄은 빼고 리워드 묶음을 넣는다 (reward-flow.md 6번).
struct SceneDoneView: View {
    let scene: TripScene
    /// 이번 종합 퀴즈에서 틀린 글자. 다음 장면 퀴즈에 다시 나온다.
    let quizWrong: [String]
    let grant: RewardGrant
    let onBackToList: () -> Void
    let onCustomize: () -> Void

    @Environment(ProgressStore.self) private var store
    @State private var appearTick = 0

    var body: some View {
        let library = ContentLibrary.shared
        let next = library.scene(after: scene)
        let goalWords = library.goalWords(for: scene)
        let items = store.rewardCatalog.items(forScene: scene.id)
        // 살 수 있는 아이템이 있거나 이번에 아이템을 받았을 때만 "기리 꾸미기"를 둔다.
        let showsCustomize = store.canBuyAnyItem || !grant.grantedItemIDs.isEmpty
        let giriLine = GiriSpeech.completion(.scene(scene: scene.name, hadWrong: !quizWrong.isEmpty, isLastScene: next == nil))
        CompletionLayout(giriLine: giriLine, level: .strong) {
            Text(L.sceneDone(scene.name)).font(.title2.bold())
            Text(L.sceneSummary(scene.kana.count)).font(.body).foregroundStyle(Color.inkSecondary)
            // 틀린 글자 줄 (scene-flow.md 14번). 다음 장면이 있으면 그 퀴즈에 다시 나온다.
            if !quizWrong.isEmpty {
                Text(next == nil ? L.confusedKana(quizWrong) : L.wrongKanaReturns(quizWrong))
                    .font(.subheadline)
                    .foregroundStyle(Color.ink)
                    .padding(.top, -4)
            }
        } detail: {
            if !goalWords.isEmpty {
                GoalWordsBlock(title: L.readableWords(scene.name), words: goalWords)
            }
            if grant.coins > 0 || !items.isEmpty {
                rewards(items: items)
            }
            if let next {
                Text(L.nextSceneOpened(next.name)).font(.body)
            }
        } buttons: {
            PrimaryButton(title: L.backToSceneList, action: onBackToList)
            if showsCustomize {
                Button(action: onCustomize) {
                    Text(L.customize)
                        .font(.headline)
                        .foregroundStyle(SkinColor.accentText)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.success, trigger: appearTick)
        .onAppear { appearTick += 1 }
    }

    /// 받은 엔 줄, 마일스톤 줄, 열린 아이템 (reward-flow.md 6.2의 6번).
    private func rewards(items: [RewardItem]) -> some View {
        let learned = ContentLibrary.shared.kana(before: scene).union(scene.kana)
        let header = grant.grantedItemIDs.isEmpty ? L.itemsUnlocked(items.count) : L.itemsGranted(grant.grantedItemIDs.count)
        return VStack(spacing: 0) {
            if grant.coins > 0 {
                CoinsReceivedLine(received: grant.coins, balance: grant.balance)
            }
            if grant.milestoneCoins > 0 {
                Text(L.hiraganaMilestone(grant.milestoneCoins))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.top, 4)
            }
            if !items.isEmpty {
                VStack(spacing: 8) {
                    Text(header)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                    CenteredFlow(spacing: 16, lineSpacing: 8) {
                        ForEach(items) { item in
                            VStack(spacing: 2) {
                                Group {
                                    if item.slot == SkinPolicy.slot {
                                        // 색 아이템은 44pt 칸 가운데 견본 30pt (app-skin.md 5.4).
                                        SkinSwatch(skin: SkinCatalog.shared.skin(itemID: item.id), size: 30)
                                            .frame(width: 44, height: 44)
                                    } else {
                                        ItemThumbnail(item: item, size: 44)
                                    }
                                }
                                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                                .cardOutline(cornerRadius: 10)
                                if item.slot == SkinPolicy.slot {
                                    // 발음 표기 줄은 비우고 "{색 이름} 색" (5.4).
                                    VStack(spacing: 0) {
                                        Color.clear.frame(height: 12)
                                        Text(L.skinColorName(SkinCatalog.shared.skin(itemID: item.id).nameKo))
                                            .font(.system(size: 15))
                                            .frame(height: 20)
                                    }
                                } else {
                                    ItemNameRuby(item: item, learned: learned)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(itemsLabel(header: header, items: items)))
            }
        }
    }

    private func itemsLabel(header: String, items: [RewardItem]) -> AttributedString {
        items.reduce(AttributedString(header)) { label, item in
            if item.slot == SkinPolicy.slot {
                // 색 아이템은 "{색 이름} 색" (app-skin.md 5.4).
                return label + AttributedString(", " + L.skinColorName(SkinCatalog.shared.skin(itemID: item.id).nameKo))
            }
            return label + AttributedString(", ") + KanaText.japanese(item.kana ?? "") + AttributedString(" \(item.nameKo)")
        }
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
                .foregroundStyle(Color.inkSecondary)
            CenteredFlow(spacing: 16, lineSpacing: 8) {
                ForEach(words) { word in
                    KanaText(text: word.text, size: 22, weight: .bold)
                        .foregroundStyle(Color.ink)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(AttributedString("\(title), ") + KanaText.japanese(words.map(\.text).joined(separator: ", "))))
    }
}

/// 완료 화면의 배치. 캐릭터 아래 끝이 내용 영역 높이의 위에서 3분의 1에 오고 버튼은 아래에 고정된다.
private struct CompletionLayout<Texts: View, Detail: View, Buttons: View>: View {
    /// 기리 말풍선 (3.11의 C1, C2).
    let giriLine: String
    /// 스킨 강도: C1 중, C2 강 (app-skin.md 4.1).
    let level: SkinLevel
    @ViewBuilder let texts: Texts
    @ViewBuilder let detail: Detail
    @ViewBuilder let buttons: Buttons

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        // 접근성 글자 크기에서는 캐릭터를 줄여 글자 자리를 먼저 지킨다 (visual-rules.md 8.1).
        let characterSide: CGFloat = typeSize.isAccessibilitySize ? 80 : 120
        VStack(spacing: 0) {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 24) {
                        giri(side: characterSide)
                        VStack(spacing: 24) {
                            VStack(spacing: 8) { texts }
                                .multilineTextAlignment(.center)
                            detail
                        }
                        .padding(.horizontal, 20)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                    // 캐릭터 아래 끝을 위에서 3분의 1에 두되, 모자라면 위 여백부터 줄인다. 최소 24pt (reward-flow.md 6.2).
                    // 내용 영역은 아래 버튼 영역(버튼 사이 4pt 포함)을 뺀 실제 높이다.
                    .padding(.top, max(min(geo.size.height / 3 - characterSide, geo.size.height - contentHeight), 24))
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            VStack(spacing: 4) { buttons }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .skinBackground(level)
    }

    /// 기리는 왼쪽(여백 16pt), 말풍선은 오른쪽. 말풍선은 등장 0.15초 뒤 뜬다 (giri-companion.md 3.9, 5.2).
    /// 큰 글자 크기에서는 기리 80pt를 가운데 두고 말풍선을 그 아래 8pt에 전체 폭으로 둔다 (6.2).
    @ViewBuilder
    private func giri(side: CGFloat) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                CelebrationCharacter(side: side)
                GiriSpeechRow(pose: .happy, text: giriLine, size: side, maxLines: 3, breathes: false)
            }
        } else {
            GiriSpeechRow(pose: .happy, text: giriLine, size: side, maxLines: 3, breathes: false, bubbleDelay: 0.15,
                          customFigure: AnyView(CelebrationCharacter(side: side)))
        }
    }
}

/// 완료 화면의 웃는 캐릭터와 체크 배지. 장식이라 VoiceOver에서 읽지 않는다.
/// 나타날 때 한 번 나온다: 크기와 팔은 Lottie `appear` 마커, 불투명도는 SwiftUI 0 → 1(0.2초 easeOut) (giri-companion.md 5.2.7).
/// "동작 줄이기"가 켜져 있으면 처음부터 제 모습이다 (visual-rules.md 6.2, 7.2).
private struct CelebrationCharacter: View {
    let side: CGFloat

    @Environment(ProgressStore.self) private var store

    /// 배지 지름과, 캐릭터 사각형의 오른쪽 아래 꼭짓점에서 배지 중심까지의 거리.
    private static let badgeSize: CGFloat = 32
    private static let badgeInset: CGFloat = 16
    private static let badgeRing: CGFloat = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        let shown = appeared || reduceMotion
        GiriView(pose: .happy, outfit: store.giriOutfit, side: side, entrance: true)
            .overlay {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: Self.badgeSize, height: Self.badgeSize)
                    .foregroundStyle(Color.correct)
                    .padding(Self.badgeRing)
                    .background(SkinColor.background, in: Circle())
                    .position(x: side - Self.badgeInset, y: side - Self.badgeInset)
            }
            .opacity(shown ? 1 : 0)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.2)) { appeared = true }
            }
    }
}

/// 글자 줄(34pt). 표시할 글자 아래에는 `HighlightStrong` 점을 붙인다.
struct KanaRow: View {
    let kana: [String]
    let marked: Set<String>

    var body: some View {
        HStack(spacing: 16) {
            ForEach(kana, id: \.self) { char in
                VStack(spacing: 4) {
                    KanaText(text: char, size: 34)
                    Circle()
                        .fill(Color.highlightStrong)
                        .frame(width: 6, height: 6)
                        .opacity(marked.contains(char) ? 1 : 0)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}
