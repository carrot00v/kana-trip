import SwiftUI

/// 앱 정보: 이름과 버전, 발음 소리·획 데이터·움직임 라이브러리의 크레딧과 라이선스.
/// 홈의 "더 보기" 메뉴에서 연다. 목록 모양은 홈과 같다(visual-rules.md 1.3).
struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.appTitle)
                        .font(.headline)
                    Text(L.appVersion(Self.version, build: Self.build))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .listRowBackground(Color.cardBackground)
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(KanaText.japanese(L.voiceCreditLine))
                        .font(.headline)
                    Text(L.qwenVoiceCreditLine)
                        .font(.headline)
                    Text(note(L.voiceCreditNote))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
                .accessibilityElement(children: .combine)
                .listRowBackground(Color.cardBackground)
            } header: {
                header(L.aboutVoiceHeader)
            }

            Section {
                credit(title: L.kanjiVG, lines: [L.kanjiVGCopyright, L.kanjiVGLicense], note: L.kanjiVGNote)
                link(L.website, url: L.kanjiVGURL)
                link(L.licenseOnline, url: L.kanjiVGLicenseURL)
            } header: {
                header(L.aboutStrokeHeader)
            }

            Section {
                credit(title: L.lottie, lines: [L.lottieCopyright, L.lottieLicense], note: nil)
                link(L.website, url: L.lottieURL)
                NavigationLink(value: HomeRoute.license(LicenseText.lottie)) {
                    Text(L.licenseFullText)
                        .font(.body)
                }
                .listRowBackground(Color.cardBackground)
            } header: {
                header(L.aboutMotionHeader)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .skinBackground(.medium)
        .navigationTitle(L.about)
        .navigationBarTitleDisplayMode(.inline)
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    /// 한글 문장 속 일본어(春日部つむぎ)도 일본어 글꼴로 그리고 읽게 한다.
    private func note(_ text: String) -> AttributedString {
        var string = AttributedString(text)
        for word in ["春日部つむぎ"] {
            if let range = string.range(of: word) {
                string[range].languageIdentifier = "ja"
            }
        }
        return string
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(Color.inkSecondary)
            .textCase(nil)
    }

    private func credit(title: String, lines: [String], note: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
            if let note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .listRowBackground(Color.cardBackground)
    }

    private func link(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHint(url.host() ?? "")
        .listRowBackground(Color.cardBackground)
    }
}

/// 번들에 넣은 라이선스 전문.
enum LicenseText: String, Hashable {
    case lottie = "lottie-ios-LICENSE"

    var title: String {
        switch self {
        case .lottie: L.lottie
        }
    }

    var text: String {
        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "txt")
            ?? Bundle.main.url(forResource: rawValue, withExtension: "txt", subdirectory: "Licenses"),
            let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }
}

/// 라이선스 전문을 보여 준다. 원문은 80자 폭으로 줄을 바꿔 두어 좁은 화면에서 들쭉날쭉해지므로,
/// 빈 줄로 나뉜 문단 안의 줄바꿈만 띄어쓰기로 이어 화면 폭에 맞게 다시 흐르게 한다(글 내용은 그대로).
struct LicenseTextView: View {
    let license: LicenseText

    static func reflow(_ text: String) -> String {
        text.components(separatedBy: "\n\n")
            .map { paragraph in
                paragraph.split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    var body: some View {
        ScrollView {
            Text(Self.reflow(license.text))
                .font(.footnote)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .skinBackground(.medium)
        .navigationTitle(license.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
