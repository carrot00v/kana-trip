import AVFoundation
import UIKit

/// 무엇을 읽는지. 글자 하나와 단어는 속도와 읽는 방식이 다르다.
enum SpeechKind {
    /// 글자 하나(す, へ 등). 느리게 두 번 읽는다.
    case kana
    /// 단어 전체(すし, かつ丼 등). 조금 느리게 한 번 읽는다.
    case word
}

/// 발음 속도와 읽는 방식. 값은 iPhone 17 Pro 시뮬레이터(iOS 26.5, Kyoko super-compact)에서
/// `AVSpeechSynthesizer.write`로 합성 길이를 재서 정했다.
///
/// - 기본 속도(0.5)에서 す는 소리 0.18초, あ는 0.08초로 순식간에 끝난다.
/// - 이 음성은 속도를 낮춰도 길이가 조금만 늘어난다(0.35에서 す 0.22초, 0.0에서도 0.36초).
///   그래서 글자 하나는 속도만 낮추지 않고 0.4초 쉬고 한 번 더 읽는다.
/// - 장음 기호(すー)로 늘이면 발음이 달라지므로 쓰지 않는다.
enum SpeechStyle {
    static let kanaRate: Float = 0.35
    static let wordRate: Float = 0.42
    /// 글자 하나를 읽는 횟수와 그 사이 쉬는 시간.
    static let kanaRepeats = 2
    static let kanaGap: TimeInterval = 0.4
    /// 첫 음 앞에 두는 여백. 오디오 경로가 열리는 동안 앞이 잘리지 않게 한다.
    static let leadIn: TimeInterval = 0.1

    /// 혼자 읽으면 다르게 읽히는 글자를 같은 소리의 다른 표기로 바꾼다.
    /// へ는 조사처럼 え(e)로 읽혀 ヘ로 읽는다. は는 ハ와 같은 소리(ha), を는 お(o)로 맞게 읽혀 그대로 둔다.
    static let kanaOverrides: [String: String] = ["へ": "ヘ"]

    static func spokenText(_ text: String, as kind: SpeechKind) -> String {
        switch kind {
        case .kana: kanaOverrides[text] ?? text
        case .word: text
        }
    }

    /// 쓸 수 있는 일본어 음성 하나. 고르는 규칙만 따로 떼어 시험한다.
    struct VoiceCandidate: Equatable {
        let identifier: String
        /// premium 3 > enhanced 2 > default 1 (`AVSpeechSynthesisVoiceQuality.rawValue`).
        let quality: Int
        /// 장난감 음성, 개인 음성, Eloquence(Grandpa 등)처럼 학습용으로 맞지 않는 음성.
        let excluded: Bool
    }

    /// 품질이 가장 높은 음성을 고른다. 같은 품질이면 시스템 기본 음성, 그다음 식별자 순서로 고른다.
    /// 고를 것이 없으면 nil이고, 그때는 시스템 기본 음성을 쓴다.
    static func pickVoice(_ candidates: [VoiceCandidate], systemDefault: String?) -> String? {
        let usable = candidates.filter { !$0.excluded }
        guard let top = usable.map(\.quality).max() else { return nil }
        let best = usable.filter { $0.quality == top }
        if let systemDefault, best.contains(where: { $0.identifier == systemDefault }) { return systemDefault }
        return best.map(\.identifier).sorted().first
    }
}

/// 기기 내장 일본어 음성으로 글자나 단어를 읽는다. 켜짐 여부는 부르는 쪽(`ProgressStore.soundOn`)에서 확인한다.
/// 다시 누르면 하던 소리를 끊고 처음부터 읽는다. 읽기를 시작한 화면이 사라지면 멈춘다.
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()
    private lazy var voice: AVSpeechSynthesisVoice? = Self.preferredVoice()
    /// 지금 읽는 소리를 시작한 화면. 그 화면이 사라질 때만 멈춘다.
    private var owner: UUID?
    private var lastUtterance: AVSpeechUtterance?
    private var sessionConfigured = false

    override init() {
        super.init()
        synthesizer.delegate = self
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.stop()
        }
    }

    func speak(_ text: String, as kind: SpeechKind, owner: UUID? = nil) {
        synthesizer.stopSpeaking(at: .immediate)
        activateSession()
        self.owner = owner

        let spoken = SpeechStyle.spokenText(text, as: kind)
        let count = kind == .kana ? SpeechStyle.kanaRepeats : 1
        for index in 0..<count {
            let utterance = AVSpeechUtterance(string: spoken)
            utterance.voice = voice
            utterance.rate = kind == .kana ? SpeechStyle.kanaRate : SpeechStyle.wordRate
            if index == 0 { utterance.preUtteranceDelay = SpeechStyle.leadIn }
            if index < count - 1 { utterance.postUtteranceDelay = SpeechStyle.kanaGap }
            lastUtterance = utterance
            synthesizer.speak(utterance)
        }
    }

    /// `owner`가 주어지면 그 화면이 시작한 소리일 때만 멈춘다.
    func stop(owner: UUID? = nil) {
        if let owner, owner != self.owner { return }
        self.owner = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: 오디오 세션

    /// 발음은 사용자가 소리를 켜고 직접 눌러야 나므로 무음 스위치와 상관없이 들리게 한다(.playback).
    /// 다른 앱의 음악은 읽는 동안만 줄인다.
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        if !sessionConfigured {
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            sessionConfigured = true
        }
        try? session.setActive(true)
    }

    private func finished(_ utterance: AVSpeechUtterance) {
        guard utterance === lastUtterance, !synthesizer.isSpeaking else { return }
        lastUtterance = nil
        owner = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finished(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finished(utterance)
    }

    // MARK: 음성 고르기

    private static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }
        let candidates = voices.map { voice in
            SpeechStyle.VoiceCandidate(
                identifier: voice.identifier,
                quality: voice.quality.rawValue,
                excluded: voice.voiceTraits.contains(.isNoveltyVoice)
                    || voice.voiceTraits.contains(.isPersonalVoice)
                    || voice.identifier.contains("eloquence"))
        }
        let fallback = AVSpeechSynthesisVoice(language: "ja-JP")
        guard let id = SpeechStyle.pickVoice(candidates, systemDefault: fallback?.identifier) else { return fallback }
        return AVSpeechSynthesisVoice(identifier: id) ?? fallback
    }
}
