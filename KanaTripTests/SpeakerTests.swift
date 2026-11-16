import AVFoundation
import Foundation
import Testing
@testable import KanaTrip

// 발음 소리의 읽는 방식과 음성 고르기 (App/Speaker.swift).

@Suite("발음 소리")
struct SpeakerTests {
    /// へ는 혼자 읽으면 え로 읽혀 ヘ로 바꿔 읽는다. は·を는 맞게 읽혀 그대로 둔다.
    @Test func kanaOverrides() {
        #expect(SpeechStyle.spokenText("へ", as: .kana) == "ヘ")
        #expect(SpeechStyle.spokenText("は", as: .kana) == "は")
        #expect(SpeechStyle.spokenText("を", as: .kana) == "を")
        #expect(SpeechStyle.spokenText("す", as: .kana) == "す")
    }

    /// 단어 안의 へ(おへや)는 바꾸지 않는다. 단어는 한자 표기도 그대로 넘긴다.
    @Test func wordsAreUnchanged() {
        #expect(SpeechStyle.spokenText("おへや", as: .word) == "おへや")
        #expect(SpeechStyle.spokenText("かつ丼", as: .word) == "かつ丼")
    }

    /// 바꿔 읽는 글자는 같은 소리의 가타카나여야 한다(장음 기호 등으로 늘이지 않는다).
    @Test func overridesKeepTheSameSound() {
        for (hira, spoken) in SpeechStyle.kanaOverrides {
            let shifted = hira.unicodeScalars.first!.value + 0x60
            #expect(spoken == String(UnicodeScalar(shifted)!), "\(hira) → \(spoken)")
        }
    }

    /// 글자는 단어보다 느리고, 둘 다 기본 속도(0.5)보다 느리다. 글자도 단어도 한 번 읽는다(노래 합성 한 박).
    @Test func ratesAreSlowerForKana() {
        #expect(SpeechStyle.kanaRate < SpeechStyle.wordRate)
        #expect(SpeechStyle.wordRate < 0.5)
        #expect(SpeechStyle.kanaRepeats == 1)
        #expect(SpeechStyle.repeats(for: .kana) == 1)
        #expect(SpeechStyle.repeats(for: .word) == 1)
    }

    @Test func voicePrefersHigherQuality() {
        typealias C = SpeechStyle.VoiceCandidate
        let compact = C(identifier: "ja.kyoko.compact", quality: 1, excluded: false)
        let enhanced = C(identifier: "ja.kyoko.enhanced", quality: 2, excluded: false)
        let premium = C(identifier: "ja.kyoko.premium", quality: 3, excluded: false)
        let toy = C(identifier: "ja.eloquence.grandpa", quality: 3, excluded: true)

        #expect(SpeechStyle.pickVoice([compact, enhanced, premium], systemDefault: compact.identifier) == premium.identifier)
        #expect(SpeechStyle.pickVoice([compact, enhanced], systemDefault: compact.identifier) == enhanced.identifier)
        #expect(SpeechStyle.pickVoice([compact, toy], systemDefault: compact.identifier) == compact.identifier)
        #expect(SpeechStyle.pickVoice([toy], systemDefault: nil) == nil)
        #expect(SpeechStyle.pickVoice([], systemDefault: "x") == nil)
    }

    /// 같은 품질이면 시스템 기본 음성을 먼저 고른다.
    @Test func voicePrefersSystemDefaultWithinTier() {
        typealias C = SpeechStyle.VoiceCandidate
        let a = C(identifier: "ja.a", quality: 2, excluded: false)
        let b = C(identifier: "ja.b", quality: 2, excluded: false)
        #expect(SpeechStyle.pickVoice([a, b], systemDefault: "ja.b") == "ja.b")
        #expect(SpeechStyle.pickVoice([b, a], systemDefault: "ja.other") == "ja.a")
    }
}

// 번들 음성(VOICEVOX 春日部つむぎ)과 재생 순서.

@Suite("번들 발음 소리")
struct BundledVoiceTests {
    private let library = ContentLibrary.shared

    private func index() throws -> VoiceIndex {
        try #require(VoiceIndex.bundled, "Resources/Voice/voice_index.json을 읽지 못함")
    }

    /// 기본 46자는 모두 번들 파일이 있거나, 의도적으로 뺀 목록(missingKana)에 있다.
    @Test func everyBaseKanaHasAFileOrIsListedMissing() throws {
        let index = try index()
        let kana = KanaStrokeStore.loadHiragana().map(\.char)
        #expect(kana.count == 46)
        for char in kana {
            if index.missingKana.contains(char) { continue }
            let name = try #require(index.kana[char], "\(char): 목록에 없음")
            #expect(VoiceIndex.url(of: name) != nil, "\(char): 번들에 \(name).m4a가 없음")
        }
    }

    /// 단어 60개는 모두 번들 파일이 있거나 missingWords에 있다. 키는 화면 표기(かつ丼) 그대로다.
    @Test func everyWordHasAFileOrIsListedMissing() throws {
        let index = try index()
        let words = library.scenes.flatMap(\.words)
        #expect(words.count == 60)
        for word in words {
            if index.missingWords.contains(word.text) { continue }
            let name = try #require(index.word[word.text], "\(word.text): 목록에 없음")
            #expect(VoiceIndex.url(of: name) != nil, "\(word.text): 번들에 \(name).m4a가 없음")
        }
    }

    /// 단어 칸을 눌러 듣는 글자(탁음, 반탁음 포함)도 모두 파일이 있거나, 소리 없는 글자이거나, 뺀 목록에 있다.
    @Test func everyTappableWordUnitIsCovered() throws {
        let index = try index()
        let units = Set(library.scenes.flatMap(\.words).flatMap(\.kanaUnits).map(\.kana))
        for unit in units.sorted() {
            if index.silentKana.contains(unit) || index.missingKana.contains(unit) { continue }
            let name = try #require(index.kana[unit], "\(unit): 목록에 없음")
            #expect(VoiceIndex.url(of: name) != nil, "\(unit): 번들에 \(name).m4a가 없음")
        }
        #expect(index.silentKana == ["っ"])
    }

    /// 목록의 파일 이름은 ASCII이고 겹치지 않는다. 글자는 kana_, 단어는 word_로 시작한다.
    @Test func fileNamesAreUniqueAscii() throws {
        let index = try index()
        let names = Array(index.kana.values) + Array(index.word.values)
        #expect(Set(names).count == names.count)
        for name in names {
            #expect(name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }, "\(name)")
        }
        #expect(index.kana.values.allSatisfy { $0.hasPrefix("kana_") })
        #expect(index.word.values.allSatisfy { $0.hasPrefix("word_") })
        #expect(index.kana["を"] == "kana_wo")
        #expect(index.kana["お"] == "kana_o")
    }

    /// 번들의 m4a를 iOS가 실제로 열 수 있고, 길이가 글자 0.4~1.0초(Qwen3-TTS 소리 0.3~0.6초 + 앞 0.025초·뒤 0.1초 무음),
    /// 단어 0.3~2초 안이다.
    @Test func everyBundledFileDecodes() throws {
        let index = try index()
        for (names, range) in [(index.kana.values, 0.4...1.0), (index.word.values, 0.3...2.0)] {
            for name in names {
                let url = try #require(VoiceIndex.url(of: name), "\(name)")
                let player = try AVAudioPlayer(contentsOf: url)
                #expect(range.contains(player.duration), "\(name): \(player.duration)초")
                #expect(player.numberOfChannels == 1, "\(name)")
            }
        }
    }

    /// 크레딧 문구는 정보 화면의 문구와 같다.
    @Test func creditMatchesAboutScreen() throws {
        #expect(try index().credit == L.voiceCredit)
        #expect(L.voiceCredit == "VOICEVOX:春日部つむぎ")
    }

    /// 정보 화면의 두 줄: 단어 목소리(春日部つむぎ)와 글자 목소리(Qwen3-TTS).
    /// 기존 표기 `VOICEVOX:春日部つむぎ`는 그대로 들어 있어야 하고, 노래 합성 가창 교사(波音リツ)는 더 적지 않는다.
    @Test func creditLinesNameBothVoices() {
        #expect(L.voiceCreditLine == "音声: VOICEVOX:春日部つむぎ")
        #expect(L.voiceCreditLine.contains(L.voiceCredit))
        #expect(L.kanaVoiceCreditLine == "글자 발음: Qwen3-TTS (Apache 2.0)")
        #expect(L.voiceCreditNote.contains("春日部つむぎ") && L.voiceCreditNote.contains("Qwen3-TTS"))
        #expect(!L.voiceCreditNote.contains("波音リツ"))
    }

    // MARK: 무엇으로 읽을지

    private func sampleIndex() throws -> VoiceIndex {
        let json = """
        {"credit": "VOICEVOX:春日部つむぎ", "kana": {"す": "kana_su", "あ": "kana_a"},
         "word": {"すし": "word_sushi", "かつ丼": "word_katsudon"},
         "silentKana": ["っ"], "missingKana": ["あ"], "missingWords": []}
        """
        return try JSONDecoder().decode(VoiceIndex.self, from: Data(json.utf8))
    }

    @Test func planUsesFileWhenBundled() throws {
        let index = try sampleIndex()
        let all: (String) -> Bool = { _ in true }
        #expect(SpeechStyle.plan(for: "す", as: .kana, index: index, fileExists: all) == .file(name: "kana_su", repeats: 1))
        #expect(SpeechStyle.plan(for: "すし", as: .word, index: index, fileExists: all) == .file(name: "word_sushi", repeats: 1))
        #expect(SpeechStyle.plan(for: "かつ丼", as: .word, index: index, fileExists: all) == .file(name: "word_katsudon", repeats: 1))
    }

    /// 목록에 없거나 파일이 없으면 내장 음성으로 읽는다(へ는 ヘ로 바꿔 읽는 규칙도 그대로).
    @Test func planFallsBackToSynthesizer() throws {
        let index = try sampleIndex()
        let none: (String) -> Bool = { _ in false }
        let all: (String) -> Bool = { _ in true }
        #expect(SpeechStyle.plan(for: "へ", as: .kana, index: index, fileExists: all) == .synthesized(text: "ヘ", repeats: 1))
        #expect(SpeechStyle.plan(for: "す", as: .kana, index: index, fileExists: none) == .synthesized(text: "す", repeats: 1))
        #expect(SpeechStyle.plan(for: "いか", as: .word, index: index, fileExists: all) == .synthesized(text: "いか", repeats: 1))
        #expect(SpeechStyle.plan(for: "す", as: .kana, index: nil, fileExists: all) == .synthesized(text: "す", repeats: 1))
    }

    /// っ는 혼자 소리가 없어 아무것도 읽지 않는다. 단어로 넘어온 같은 글자는 해당하지 않는다.
    @Test func planIsSilentForSmallTsu() throws {
        let index = try sampleIndex()
        let all: (String) -> Bool = { _ in true }
        #expect(SpeechStyle.plan(for: "っ", as: .kana, index: index, fileExists: all) == .silent)
        #expect(SpeechStyle.plan(for: "っ", as: .word, index: index, fileExists: all) == .synthesized(text: "っ", repeats: 1))
    }

    // MARK: 글자 수

    /// 앱이 읽는 글자 58개(기본 46자 + 단어 칸의 탁음·반탁음 12자)가 모두 번들 파일로 있다. 빠진 글자는 없다.
    @Test func allFiftyEightKanaAreBundled() throws {
        let index = try index()
        #expect(index.kana.count == 58)
        #expect(index.missingKana.isEmpty)
        #expect(index.missingWords.isEmpty)
    }
}
