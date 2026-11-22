#if DEBUG
import SwiftUI

/// `-debugGiri 1`: 기리 Lottie 확인 화면(디버그 빌드 전용). 표정·밥·아이템 조합을 한 화면에 늘어놓고,
/// 렌더링 엔진과 값·이미지 공급자가 반영되는지 본다 (giri-companion.md 5.7 끝 줄). 진도는 메모리에만 둔다.
///
///   xcrun simctl launch <기기> <번들 id> -debugGiri 1
enum DebugGiri {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("-debugGiri") }
}

struct DebugGiriPreview: View {
    @State private var pose: GiriPose = .think
    @State private var outfitIndex = 0
    @State private var breathes = false
    @State private var engine = "?"

    private let store = ProgressStore(storage: DebugGiriStorage())

    private static let outfits: [GiriOutfit] = [
        .standard,
        GiriOutfit(top: "hachimaki", filling: "shake", rice: "yakionigiri"),
        GiriOutfit(top: "tamago", filling: "umeboshi", rice: "goma"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("엔진 \(engine)").font(.caption.monospaced())
                    .task {
                        try? await Task.sleep(for: .seconds(1))
                        engine = GiriRendering.engineLabel
                    }
                HStack(spacing: 24) {
                    GiriView(pose: .normal, outfit: .standard, side: 150)
                    Image("OnigiriDefault").resizable().frame(width: 150, height: 150)
                }
                HStack(spacing: 16) {
                    ForEach([GiriPose.happy, .point, .talk, .sorry], id: \.self) { p in
                        GiriView(pose: p, outfit: .standard, side: 80)
                    }
                }
                HStack(spacing: 16) {
                    GiriView(pose: .normal, outfit: Self.outfits[1], side: 110)
                    GiriView(pose: .happy, outfit: Self.outfits[2], side: 110)
                    GiriView(pose: .think, outfit: GiriOutfit(top: "omen", rice: "goma"), side: 110)
                }
                Divider()
                GiriView(pose: pose, outfit: Self.outfits[outfitIndex], side: 160, breathes: breathes)
                    .padding(.top, 40)
                HStack {
                    Button("생각") { pose = .think }
                    Button("웃음") { pose = .happy }
                    Button("손") { pose = .point }
                    Button("아쉬움") { pose = .sorry }
                    Button("차림") { outfitIndex = (outfitIndex + 1) % Self.outfits.count }
                    Toggle("숨", isOn: $breathes).fixedSize()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            .padding()
        }
        .environment(store)
    }
}

private final class DebugGiriStorage: ProgressStorage {
    private var state: ProgressState?
    func load() -> ProgressState? { state }
    func save(_ state: ProgressState) { self.state = state }
}
#endif
