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

    /// 글자는 단어보다 느리고, 둘 다 기본 속도(0.5)보다 느리다. 글자는 두 번 읽는다.
    @Test func ratesAreSlowerForKana() {
        #expect(SpeechStyle.kanaRate < SpeechStyle.wordRate)
        #expect(SpeechStyle.wordRate < 0.5)
        #expect(SpeechStyle.kanaRepeats == 2)
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
