import SwiftUI

/// K 기리 꾸미기 (docs/design/reward-flow.md 3번, 3.0의 2026-11-16 개편).
/// 위: 미리보기와 안내 줄. 아래 절반: 슬롯 탭(머리·속재료·밥·스킨)과 아이템 격자.
/// 탭 하나 = 슬롯 하나 = "없음"(밥은 흰 밥, 스킨은 "기본") 칸 하나. 아이템이 없는 슬롯의 탭은 숨긴다.
/// 스킨 탭은 색 견본 격자다(app-skin.md 5.2, 2026-11-21 색상 선택 개정). 견본을 누르면 K 화면 전체가 그 색으로 바뀐다(5.3).
/// 미리 보기는 K 뿌리의 환경값만 덮는다.
struct CustomizeView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var slot: RewardSlot = .top
    @State private var didPickSlot = false
    /// 미리 보는 중인 아이템. 저장하지 않는다.
    @State private var trying: RewardItem?
    /// 안내 줄. nil이면 고른 슬롯의 "처음" 문구.
    @State private var info: Info?
    /// 확인 창을 띄운 아이템.
    @State private var buying: RewardItem?
    @State private var lightTick = 0
    @State private var successTick = 0

    /// 슬롯 버튼 글자 영역. `.controlSize(.regular)`의 위아래 여백과 합쳐 44pt가 된다 (iOS 26 시뮬레이터에서 잼).
    private static let slotLabelHeight: CGFloat = 30
    private static let cellHeight: CGFloat = 126
    /// 색 견본 칸 (5.2): 고리 자리 64 → 6 → 이름 20 → 2 → 상태 16 = 108.
    private static let swatchCellHeight: CGFloat = 108
    private static let swatchSize: CGFloat = 52
    private static let swatchRingSize: CGFloat = 64

    private struct Info: Equatable {
        var kana: String?
        var title: String
        var detail: String
    }

    private enum Cell: Identifiable {
        case none
        case item(RewardItem)

        var id: String {
            switch self {
            case .none: "none"
            case .item(let item): item.id
            }
        }
    }

    private enum ItemState: Equatable {
        case wearing, owned, buyable, short(Int), locked
    }

    private var catalog: RewardCatalog { store.rewardCatalog }
    private var rewards: RewardState { store.rewards }
    private let skins = SkinCatalog.shared

    /// K 화면이 입는 스킨: 스킨 탭에서 미리 보는 아이템이 있으면 그 스킨, 아니면 저장된 스킨.
    /// 저장된 스킨은 환경값 대신 `SkinStore`에서 바로 읽는다. 사기처럼 미리 보기를 끝내는 것과 저장이 한 번에 일어날 때
    /// 루트 환경값이 한 박자 늦게 와서 쓰던 스킨이 잠깐 비치는 것을 막는다.
    private var screenSkin: Skin {
        if let trying, trying.slot == SkinPolicy.slot { return skins.skin(itemID: trying.id) }
        return SkinStore.shared.current
    }

    /// 스킨이 바뀌는 조작을 0.3초 교차 페이드로 감싼다. "동작 줄이기"면 바로 바꾼다 (5.3).
    private func skinChange(_ change: () -> Void) {
        if reduceMotion {
            change()
        } else {
            withAnimation(.easeInOut(duration: skins.skinCrossfade), change)
        }
    }

    private var isSkinSlot: Bool { slot == SkinPolicy.slot }

    var body: some View {
        GeometryReader { geo in
            if typeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 0) {
                        preview(side: 160)
                        controls(columns: 2, slotColumns: 2)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    preview(side: previewSide(geo))
                    controls(columns: 3, slotColumns: 4)
                }
            }
        }
        .skinBackground(.strong)
        .environment(\.skin, screenSkin)
        .tint(screenSkin.dynamicColor(.accentText))
        .navigationTitle(L.customize)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L.resetOutfit, action: resetOutfit)
                    .disabled(rewards.isDefaultOutfit)
                    .accessibilityHint(L.resetOutfitHint)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightTick)
        .sensoryFeedback(.success, trigger: successTick)
        .onAppear(perform: pickInitialSlot)
    }

    // MARK: - 미리보기

    /// 슬롯 버튼의 위 끝이 화면 절반선에 오도록, 200~260pt 안에서 (3.3).
    private func previewSide(_ geo: GeometryProxy) -> CGFloat {
        let top = geo.frame(in: .global).minY
        let screenHeight = top + geo.size.height + geo.safeAreaInsets.bottom
        return min(260, max(200, screenHeight / 2 - top - 70))
    }

    private var previewOutfit: GiriOutfit {
        GiriOutfit(state: rewards, catalog: catalog, trying: trying)
    }

    /// 보여 줄 탭: 팔 아이템이 하나라도 있는 슬롯 (3.0 "빈 탭"). 지금 목록은 넷 모두 있다.
    private var visibleSlots: [RewardSlot] {
        RewardSlot.allCases.filter { slot in catalog.items(in: slot).contains { !$0.isDefault } }
    }

    private func preview(side: CGFloat) -> some View {
        // 머리·속재료·밥이 바뀌면 기리가 눌렸다 펴지는 `dress` 마커(giri-companion.md 5.2.8). 기리 뒤 그림은 스킨에서 뺐다(app-skin.md 5.2).
        GiriView(pose: .normal, outfit: previewOutfit, side: side)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: previewOutfit)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .cardOutline(cornerRadius: 20)
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.giri)
            .accessibilityValue(previewLabel)
            .accessibilityAddTraits(.isImage)
    }

    private var previewLabel: String {
        let parts = visibleSlots.map { slot in
            if slot == SkinPolicy.slot {
                // 마지막 항목은 "스킨 {색 이름}" (5.3).
                return L.skinPreviewPart(SkinStore.shared.current.nameKo)
            }
            return "\(L.slotName(slot)) \(rewards.equippedID(slot).flatMap(catalog.item(id:))?.nameKo ?? L.none)"
        }
        let head = trying.map { "\(L.tryingOnLabel) \(displayName($0)), " } ?? ""
        return head + parts.joined(separator: ", ")
    }

    /// 안내 줄·VoiceOver의 이름. 색 아이템은 가나 이름 대신 색 이름(3.1, P1).
    private func displayName(_ item: RewardItem) -> String {
        item.slot == SkinPolicy.slot ? skins.skin(itemID: item.id).nameKo : (item.kana ?? item.nameKo)
    }

    // MARK: - 안내 줄, 슬롯, 격자

    private func controls(columns: Int, slotColumns: Int) -> some View {
        VStack(spacing: 0) {
            infoRow
                .padding(.horizontal, 16)
                .padding(.top, 8)
            slotButtons(columns: slotColumns)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            if typeSize.isAccessibilitySize {
                Group {
                    if isSkinSlot { swatchGrid(columns: 3) } else { grid(columns: columns) }
                }
                .padding(.top, 12)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        if isSkinSlot { swatchGrid(columns: 5) } else { grid(columns: columns) }
                    }
                    .onAppear {
                        // 고른 탭에 살 수 있는 아이템이 있으면 그 칸이 다 보이게 시작한다 (3.6). 처음 2행 안이면 그대로다.
                        if let item = latestBuyable(in: slot) { proxy.scrollTo(item.id, anchor: .bottom) }
                    }
                }
                // 슬롯을 바꾸면 처음 위치에서 다시 시작한다.
                .id(slot)
                .padding(.top, 12)
            }
        }
    }

    private var shownInfo: Info { info ?? initialInfo(slot) }

    private var infoRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let kana = shownInfo.kana {
                        KanaText(text: kana, size: 17)
                    }
                    Text(shownInfo.title).font(.headline)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Text(shownInfo.detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(infoLabel))
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(L.balanceTitle)
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
                HStack(spacing: 4) {
                    Image(systemName: "yensign.circle.fill")
                        .foregroundStyle(Color.highlightStrong)
                    Text(L.yen(rewards.coins))
                        .font(.headline.monospacedDigit())
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .default, value: rewards.coins)
                }
            }
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.coinsBalance(rewards.coins))
        }
        .frame(minHeight: 42)
    }

    private var infoLabel: AttributedString {
        let info = shownInfo
        var label = AttributedString()
        if let kana = info.kana { label += KanaText.japanese(kana) + AttributedString(" ") }
        return label + AttributedString("\(info.title), \(info.detail)")
    }

    private func slotButtons(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(visibleSlots, id: \.self) { slot in
                slotButton(slot)
            }
        }
    }

    @ViewBuilder
    private func slotButton(_ slot: RewardSlot) -> some View {
        let selected = slot == self.slot
        let hasBuyable = catalog.items(in: slot).contains { itemState($0) == .buyable }
        let label = HStack(spacing: 4) {
            Text(L.slotName(slot))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if hasBuyable {
                Image(systemName: "yensign.circle.fill")
                    .font(.system(size: 13))
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.slotLabelHeight)
        Group {
            if selected {
                Button { select(slot) } label: { label.foregroundStyle(SkinColor.accentForeground) }
                    .buttonStyle(.borderedProminent)
            } else {
                // 앱 루트의 Ink 글자색이 `.bordered` tint를 덮으므로 AccentText를 직접 준다 (5.2).
                Button { select(slot) } label: { label.foregroundStyle(SkinColor.accentText) }
                    .buttonStyle(.bordered)
            }
        }
        // 고른 탭 면은 AccentColor, 나머지 탭 글자·옅은 바탕은 AccentText (5.2, 8.3).
        .tint(selected ? SkinColor.accent : SkinColor.accentText)
        .controlSize(.regular)
        .accessibilityLabel(L.slotName(slot))
        .accessibilityValue(hasBuyable ? L.canBuyInSlot : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func grid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(cells) { cell in
                cellView(cell)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// 칸 순서: 없음(밥에는 없음), 기본 차림 아이템, 나머지를 장면 순서대로 (3.5). 아이템 데이터가 그 순서다.
    private var cells: [Cell] {
        (slot.canBeEmpty ? [.none] : []) + catalog.items(in: slot).map { .item($0) }
    }

    // MARK: - 칸

    private func itemState(_ item: RewardItem) -> ItemState {
        if RewardRules.isOwned(item, state: rewards) {
            return rewards.equippedID(item.slot) == item.id ? .wearing : .owned
        }
        guard RewardRules.isUnlocked(item, state: rewards) else { return .locked }
        return RewardRules.canAfford(item, state: rewards) ? .buyable : .short(item.price - rewards.coins)
    }

    /// 아이템 이름 위 발음 표기의 기준: 지금까지 끝낸 장면들의 글자.
    private var learnedKana: Set<String> {
        Set(ContentLibrary.shared.scenes.filter { store.isSceneCompleted($0) }.flatMap(\.kana))
    }

    private func sceneName(_ item: RewardItem) -> String {
        item.sceneID.flatMap { ContentLibrary.shared.scene(id: $0)?.name } ?? ""
    }

    @ViewBuilder
    private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .none:
            let wearing = rewards.equippedID(slot) == nil
            cellFrame(wearing: wearing, trying: false) {
                Image(systemName: "circle.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 60, height: 60)
            } name: {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 12)
                    Text(L.none).font(.system(size: 15)).frame(height: 20)
                }
            } status: {
                if wearing { wearingStatus }
            } action: {
                tapNone()
            }
            .accessibilityLabel(L.none)
            .accessibilityValue(wearing ? L.wearing : L.clearSlotLabel(slot))
        case .item(let item):
            let state = itemState(item)
            let isTrying = trying?.id == item.id
            cellFrame(wearing: state == .wearing, trying: isTrying) {
                ItemThumbnail(item: item, size: 60, silhouette: state == .locked)
            } name: {
                if state == .locked {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 12)
                        Text(sceneName(item))
                            .font(.system(size: 15))
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(height: 20)
                    }
                } else {
                    ItemNameRuby(item: item, learned: learnedKana)
                }
            } status: {
                status(item, state: state)
            } action: {
                tap(item, state: state)
            }
            .accessibilityLabel(Text(cellLabel(item, state: state)))
            .accessibilityValue(cellValue(item, state: state, trying: isTrying))
            .modifier(buyDialog(item, title: L.buyQuestion(kana: item.kana ?? item.nameKo, nameKo: item.nameKo, price: item.price)))
        }
    }

    /// 사기 확인 창. 누른 칸에 붙여 띄운다. 화면 전체에 붙이면 iOS 26에서 위쪽 팝오버로 떠 미리보기를 가린다.
    private func buyDialog(_ item: RewardItem, title: String) -> BuyDialog {
        BuyDialog(
            title: title,
            price: item.price,
            isPresented: Binding(
                get: { buying?.id == item.id },
                // 창 밖을 눌러 닫으면 취소와 같다.
                set: { if !$0, buying?.id == item.id { cancelBuy() } }
            ),
            onBuy: { buy(item) },
            onCancel: cancelBuy
        )
    }

    // MARK: - 색 견본 (app-skin.md 5.2)

    /// 견본 칸: 기본 + skins.json 순서의 색. 여는 아이템이 rewards.json에 없는 색은 칸을 만들지 않는다.
    private var swatchCells: [(skin: Skin, item: RewardItem?)] {
        skins.orderedSkins.compactMap { skin in
            guard let itemID = skin.itemID else { return (skin, nil) }
            guard let item = catalog.item(id: itemID), item.slot == SkinPolicy.slot else { return nil }
            return (skin, item)
        }
    }

    private func swatchGrid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: columns), spacing: 12) {
            ForEach(swatchCells, id: \.skin.id) { cell in
                if let item = cell.item {
                    swatchCell(cell.skin, item: item)
                } else {
                    defaultSwatchCell(cell.skin)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func defaultSwatchCell(_ skin: Skin) -> some View {
        let wearing = rewards.equippedID(SkinPolicy.slot) == nil
        return swatchFrame(skin: skin, mark: wearing ? .check : .none, wearing: wearing, trying: false) {
            // 기본 칸은 쓰는 중이 아니면 상태 줄을 비운다 (5.2).
            if wearing { Text(L.wearing).foregroundStyle(Color.ink) }
        } action: {
            tapDefaultSkin()
        }
        .accessibilityLabel(L.skinDefaultLabel)
        .accessibilityValue(wearing ? L.wearing : L.skinDefaultAction)
        .accessibilityAddTraits(wearing && trying == nil ? .isSelected : [])
    }

    private func swatchCell(_ skin: Skin, item: RewardItem) -> some View {
        let state = itemState(item)
        let isTrying = trying?.id == item.id
        let mark: SkinSwatch.Mark = switch state {
        case .wearing: .check
        case .locked: .lock
        default: .none
        }
        let value = cellValue(item, state: state, trying: false)
        return swatchFrame(skin: skin, mark: mark, wearing: state == .wearing, trying: isTrying) {
            switch state {
            case .wearing:
                Text(L.wearing).foregroundStyle(Color.ink)
            case .owned:
                Text(L.owned).foregroundStyle(Color.inkSecondary)
            case .buyable:
                Image(systemName: "yensign.circle.fill").foregroundStyle(Color.highlightStrong)
                Text(L.yen(item.price)).bold().foregroundStyle(Color.ink)
            case .short:
                Image(systemName: "yensign.circle").foregroundStyle(Color.inkSecondary)
                Text(L.yen(item.price)).foregroundStyle(Color.inkSecondary)
            case .locked:
                Text(L.locked).foregroundStyle(Color.inkSecondary)
            }
        } action: {
            tap(item, state: state)
        }
        .accessibilityLabel(skin.nameKo)
        .accessibilityValue(isTrying ? L.tryingPrefix(value) : value)
        .accessibilityAddTraits(isTrying || (state == .wearing && trying == nil) ? .isSelected : [])
        .modifier(buyDialog(item, title: L.buySkinQuestion(name: skin.nameKo, price: item.price)))
    }

    /// 견본 칸 하나 (5.2): 고리 자리 64 가운데 견본 52, 이름 15pt, 상태 12pt. 칸 전체가 누르는 영역.
    private func swatchFrame<Status: View>(
        skin: Skin,
        mark: SkinSwatch.Mark,
        wearing: Bool,
        trying: Bool,
        @ViewBuilder status: () -> Status,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                SkinSwatch(skin: skin, size: Self.swatchSize, mark: mark)
                    .frame(width: Self.swatchRingSize, height: Self.swatchRingSize)
                    .overlay {
                        // 고리는 Ink로 고정한다(1.2). 쓰는 중 3pt 실선, 미리 보는 중 2pt 점선.
                        if wearing {
                            Circle().strokeBorder(Color.ink, lineWidth: 3)
                        } else if trying {
                            Circle().strokeBorder(Color.ink, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        }
                    }
                Text(skin.nameKo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .frame(minHeight: 20)
                    .padding(.top, 6)
                HStack(spacing: 2) { status() }
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(minHeight: 16)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: typeSize.isAccessibilitySize ? nil : Self.swatchCellHeight, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
    }

    private func cellFrame<Thumb: View, Name: View, Status: View>(
        wearing: Bool,
        trying: Bool,
        @ViewBuilder thumbnail: () -> Thumb,
        @ViewBuilder name: () -> Name,
        @ViewBuilder status: () -> Status,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                thumbnail()
                    .frame(width: 60, height: 60)
                    .padding(.top, 6)
                name()
                    .padding(.top, 4)
                HStack(spacing: 4) { status() }
                    .font(.footnote)
                    .frame(height: 16)
                    .padding(.top, 2)
                Spacer(minLength: 6)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: typeSize.isAccessibilitySize ? nil : Self.cellHeight)
            .frame(minHeight: Self.cellHeight)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                let shape = RoundedRectangle(cornerRadius: 12)
                if wearing {
                    shape.strokeBorder(SkinColor.accentText, lineWidth: AppStyle.verdictOutlineWidth)
                } else if trying {
                    shape.strokeBorder(SkinColor.accentText, style: StrokeStyle(lineWidth: AppStyle.outlineWidth, dash: [6, 4]))
                } else {
                    shape.strokeBorder(Color.outline, lineWidth: AppStyle.outlineWidth)
                }
            }
            .overlay(alignment: .topTrailing) {
                if wearing {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(SkinColor.accentText)
                        .background(Color.cardBackground, in: Circle().inset(by: -2))
                        // 배지 중심을 칸 꼭짓점에서 안쪽 14pt에 둔다.
                        .frame(width: 20, height: 20)
                        .padding(4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
    }

    private var wearingStatus: some View {
        Group {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold))
            Text(L.wearing)
        }
        .foregroundStyle(Color.ink)
    }

    @ViewBuilder
    private func status(_ item: RewardItem, state: ItemState) -> some View {
        switch state {
        case .wearing:
            wearingStatus
        case .owned:
            Text(L.owned).foregroundStyle(Color.inkSecondary)
        case .buyable:
            Image(systemName: "yensign.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.highlightStrong)
            Text(L.yen(item.price)).bold().foregroundStyle(Color.ink)
        case .short:
            Image(systemName: "yensign.circle")
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
            Text(L.yen(item.price)).foregroundStyle(Color.inkSecondary)
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
            Text(L.locked).foregroundStyle(Color.inkSecondary)
        }
    }

    private func cellLabel(_ item: RewardItem, state: ItemState) -> AttributedString {
        if state == .locked { return AttributedString(L.lockedItemTitle(scene: sceneName(item))) }
        guard let kana = item.kana else { return AttributedString(item.nameKo) }
        return KanaText.japanese(kana) + AttributedString(", \(item.nameKo)")
    }

    private func cellValue(_ item: RewardItem, state: ItemState, trying: Bool) -> String {
        let base: String
        switch state {
        case .wearing: base = L.wearing
        case .owned: base = L.owned
        case .buyable: base = "\(L.yen(item.price)), \(L.canBuy)"
        case .short(let n): base = "\(L.yen(item.price)), \(L.short(n))"
        case .locked: base = "\(L.locked), \(L.unlocksWith(scene: sceneName(item)))"
        }
        return trying ? "\(base), \(L.tryingOnLabel)" : base
    }

    // MARK: - 조작 (3.7)

    private func initialInfo(_ slot: RewardSlot) -> Info {
        if slot == SkinPolicy.slot {
            let skin = SkinStore.shared.current
            if skin.isDefault { return Info(kana: nil, title: L.skinDefault, detail: L.skinDefaultWearing) }
            return Info(kana: nil, title: skin.nameKo, detail: L.slotWearing(slot))
        }
        if let item = rewards.equippedID(slot).flatMap(catalog.item(id:)) {
            return Info(kana: item.kana, title: item.nameKo, detail: L.slotWearing(slot))
        }
        return Info(kana: nil, title: L.none, detail: L.slotEmpty(slot))
    }

    /// 색 아이템은 가나 없이 색 이름 (5.3).
    private func nameInfo(_ item: RewardItem, _ detail: String) -> Info {
        if item.slot == SkinPolicy.slot { return Info(kana: nil, title: skins.skin(itemID: item.id).nameKo, detail: detail) }
        return Info(kana: item.kana, title: item.nameKo, detail: detail)
    }

    private func show(_ newInfo: Info?) {
        info = newInfo
        AccessibilityNotification.Announcement((newInfo ?? initialInfo(slot)).detail).post()
    }

    /// 살 수 있는 아이템이 있으면 그중 가장 늦은 장면의 아이템이 든 탭. 같은 장면에 둘이면 탭 순서가 앞인 탭.
    /// 없으면 머리 (3.6). 그 탭에서 처음 보여 줄 칸(가장 늦은 장면의 살 수 있는 아이템)도 정한다.
    private func pickInitialSlot() {
        guard !didPickSlot else { return }
        didPickSlot = true
        slot = visibleSlots.first ?? .top
        guard let item = latestBuyable(in: nil) else { return }
        slot = item.slot
    }

    /// 살 수 있는 아이템 가운데 가장 늦은 장면의 것. 같은 장면이면 탭 순서, 같은 탭이면 데이터 순서가 앞인 것.
    private func latestBuyable(in slot: RewardSlot?) -> RewardItem? {
        let buyable = RewardRules.buyableItems(state: rewards, catalog: catalog)
            .filter { slot == nil || $0.slot == slot }
        let order = { (item: RewardItem) in
            item.sceneID.flatMap { ContentLibrary.shared.scene(id: $0)?.order } ?? 0
        }
        let tabIndex = { (item: RewardItem) in RewardSlot.allCases.firstIndex(of: item.slot) ?? 0 }
        guard let latest = buyable.map(order).max() else { return nil }
        return buyable.filter { order($0) == latest }.min { tabIndex($0) < tabIndex($1) }
    }

    private func select(_ newSlot: RewardSlot) {
        guard newSlot != slot || trying != nil else { return }
        slot = newSlot
        // 스킨을 미리 보던 중이면 쓰던 스킨으로 되돌아간다 (5.3).
        skinChange { trying = nil }
        show(nil)
    }

    private func tapNone() {
        if isSkinSlot {
            tapDefaultSkin()
            return
        }
        trying = nil
        if rewards.equippedID(slot) == nil {
            show(nil)
        } else {
            store.clearSlot(slot)
            lightTick += 1
            show(Info(kana: nil, title: L.none, detail: L.slotCleared(slot)))
        }
    }

    /// 스킨 탭의 "기본" 칸: 쓰는 중이면 안내만, 아니면 스킨 키를 지워 기본 스킨으로 (5.3).
    private func tapDefaultSkin() {
        if rewards.equippedID(slot) == nil {
            skinChange { trying = nil }
            show(Info(kana: nil, title: L.skinDefault, detail: L.wearingNow))
        } else {
            skinChange {
                trying = nil
                store.clearSlot(slot)
            }
            lightTick += 1
            show(Info(kana: nil, title: L.skinDefault, detail: L.skinDefaultRestored))
        }
    }

    private func tap(_ item: RewardItem, state: ItemState) {
        switch state {
        case .wearing:
            skinChange { trying = nil }
            show(nameInfo(item, L.wearingNow))
        case .owned:
            skinChange {
                trying = nil
                store.equip(item)
            }
            lightTick += 1
            show(nameInfo(item, item.slot == SkinPolicy.slot ? L.skinEquipped : L.equipped))
        case .buyable:
            skinChange { trying = item }
            show(nameInfo(item, L.tryingOn(price: item.price)))
            buying = item
        case .short(let n):
            // 같은 칸을 다시 누르면 미리 보기를 끝낸다.
            if trying?.id == item.id {
                skinChange { trying = nil }
                show(nil)
            } else {
                skinChange { trying = item }
                show(nameInfo(item, L.shortOf(n)))
            }
        case .locked:
            skinChange { trying = nil }
            let scene = sceneName(item)
            // 색은 잠겨도 이름을 보여 준다(글자가 없다, 5.2).
            let title = item.slot == SkinPolicy.slot ? skins.skin(itemID: item.id).nameKo : L.lockedItemTitle(scene: scene)
            show(Info(kana: nil, title: title, detail: L.unlocksWith(scene: scene)))
        }
    }

    private func buy(_ item: RewardItem) {
        buying = nil
        // 미리 본 스킨이 그대로 확정된다(미리 보던 스킨 = 새로 저장된 스킨이라 화면 색은 그대로다).
        var result = RewardRules.PurchaseResult.locked
        skinChange {
            trying = nil
            result = store.buy(item)
        }
        if result == .bought {
            successTick += 1
            show(nameInfo(item, item.slot == SkinPolicy.slot ? L.skinBought : L.bought))
        } else {
            show(nil)
        }
    }

    private func cancelBuy() {
        buying = nil
        skinChange { trying = nil }
        show(nil)
    }

    private func resetOutfit() {
        // 스킨을 미리 보던 중이면 미리 보기를 끝낸다. 저장된 스킨은 권장안대로 건드리지 않는다 (5.5).
        skinChange { trying = nil }
        store.resetOutfit()
        lightTick += 1
        show(Info(kana: nil, title: L.defaultOutfit, detail: L.outfitReset))
    }
}

/// 사기 확인 창 (reward-flow.md 3.7, app-skin.md 5.3).
private struct BuyDialog: ViewModifier {
    let title: String
    let price: Int
    @Binding var isPresented: Bool
    let onBuy: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
            Button(L.buyButton(price: price), action: onBuy)
            Button(L.cancel, role: .cancel, action: onCancel)
        } message: {
            Text(L.buyNoRefund)
        }
    }
}
