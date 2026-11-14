import SwiftUI

/// C1 세션 완료.
struct SessionDoneView: View {
    let scene: TripScene
    let kind: SessionKind
    /// 이미 끝냈던 세션을 다시 한 것인지.
    let isReplay: Bool
    /// 이번 지급. 다시 한 세션이면 받은 엔이 0이라 받은 엔 줄을 그리지 않는다.
    let grant: RewardGrant
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
            Text(L.sessionDone(kind)).font(.title2.bold())
            Text(summary).font(.body).foregroundStyle(Color.inkSecondary)
        } detail: {
            KanaRow(kana: scene.kana, marked: Set(wrongKana))
            if grant.coins > 0 {
                CoinsReceivedLine(received: grant.coins, balance: grant.balance)
            }
        } buttons: {
            if !isReplay, let next = kind.next {
                PrimaryButton(title: L.sessionAction(next, resume: false)) { onContinue(next) }
                Button(action: onClose) {
                    Text(L.stopHere)
                        .font(.headline)
                        .foregroundStyle(Color.accent)
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

/// C2 장면 완료. 배운 글자 줄과 다음 장면의 새 글자 줄은 빼고 리워드 묶음을 넣는다 (reward-flow.md 6번).
struct SceneDoneView: View {
    let scene: TripScene
    let grant: RewardGrant
    let onBackToList: () -> Void
    let onCustomize: () -> Void

    @Environment(ProgressStore.self) private var store
    @State private var appearTick = 0

    var body: some View {
        let library = ContentLibrary.shared
        let next = library.scene(after: scene)
        let goalWords = library.wordGroups(for: scene).goal
        let items = store.rewardCatalog.items(forScene: scene.id)
        // 살 수 있는 아이템이 있거나 이번에 아이템을 받았을 때만 "기리 꾸미기"를 둔다.
        let showsCustomize = store.canBuyAnyItem || !grant.grantedItemIDs.isEmpty
        CompletionLayout {
            Text(L.sceneDone(scene.name)).font(.title2.bold())
            Text(L.sceneSummary(scene.kana.count)).font(.body).foregroundStyle(Color.inkSecondary)
        } detail: {
            if !goalWords.isEmpty {
                VStack(spacing: 8) {
                    Text(L.readableWords(scene.name))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                    CenteredFlow(spacing: 16, lineSpacing: 8) {
                        ForEach(goalWords) { word in
                            KanaText(text: word.text, size: 22, weight: .bold)
                        }
                    }
                }
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
                        .foregroundStyle(Color.accent)
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

    /// 받은 엔 줄, 마일스톤 줄, 열린 아이템 (6.2의 6번).
    private func rewards(items: [RewardItem]) -> some View {
        let learned = ContentLibrary.shared.learnedKana(through: scene)
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
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(items) { item in
                            VStack(spacing: 2) {
                                ItemThumbnail(item: item, size: 44)
                                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                                    .cardOutline(cornerRadius: 10)
                                ItemNameRuby(item: item, learned: learned)
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
            label + AttributedString(", ") + KanaText.japanese(item.kana ?? "") + AttributedString(" \(item.nameKo)")
        }
    }
}

/// 완료 화면의 배치. 캐릭터 아래 끝이 내용 영역 높이의 위에서 3분의 1에 오고 버튼은 아래에 고정된다.
private struct CompletionLayout<Texts: View, Detail: View, Buttons: View>: View {
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
                        CelebrationCharacter(side: characterSide)
                        VStack(spacing: 8) { texts }
                            .multilineTextAlignment(.center)
                        detail
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                    .padding(.horizontal, 20)
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
        .background(Color.appBackground)
    }
}

/// 완료 화면의 웃는 캐릭터와 체크 배지. 장식이라 VoiceOver에서 읽지 않는다.
/// 나타날 때 한 번 커지며 나온다. "동작 줄이기"가 켜져 있으면 처음부터 제 크기다 (visual-rules.md 6.2, 7.2).
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
        GiriView(face: .happy, outfit: store.rewards.equipped, side: side)
            .overlay {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: Self.badgeSize, height: Self.badgeSize)
                    .foregroundStyle(Color.correct)
                    .padding(Self.badgeRing)
                    .background(Color.appBackground, in: Circle())
                    .position(x: side - Self.badgeInset, y: side - Self.badgeInset)
            }
            .scaleEffect(shown ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { appeared = true }
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
