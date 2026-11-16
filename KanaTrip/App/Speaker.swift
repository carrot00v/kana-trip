import AVFoundation
import os
import UIKit

/// 무엇을 읽는지. 글자 하나와 단어는 속도와 읽는 방식이 다르다.
enum SpeechKind {
    /// 글자 하나(す, へ 등). 한 번 읽는다.
    case kana
    /// 단어 전체(すし, かつ丼 등). 한 번 읽는다.
    case word
}

/// 앱에 넣은 발음 소리 목록 (`Resources/Voice/voice_index.json`, `tools/gen_voice.py final`이 만든다).
/// VOICEVOX 春日部つむぎ로 미리 합성한 m4a 파일의 이름을 글자·단어 표기로 찾는다.
/// 목록에 없는 글자·단어는 기기 내장 음성으로 읽는다.
struct VoiceIndex: Decodable {
    /// 크레딧 문구 (`VOICEVOX:春日部つむぎ`). 정보 화면에 그대로 쓴다.
    let credit: String
    /// 글자 → 파일 이름(확장자 제외).
    let kana: [String: String]
    /// 단어 표기(かつ丼처럼 한자가 붙은 그대로) → 파일 이름.
    let word: [String: String]
    /// 혼자서는 소리가 없는 글자(っ). 눌러도 아무것도 읽지 않는다.
    let silentKana: [String]
    /// 합성이 깨져 파일을 만들지 않은 글자·단어. 내장 음성으로 읽는다.
    let missingKana: [String]
    let missingWords: [String]

    static let resourceName = "voice_index"
    static let fileExtension = "m4a"

    static let bundled: VoiceIndex? = load(from: .main)

    static func load(from bundle: Bundle) -> VoiceIndex? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json")
            ?? bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Voice"),
            let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(VoiceIndex.self, from: data)
    }

    func fileName(for text: String, as kind: SpeechKind) -> String? {
        switch kind {
        case .kana: kana[text]
        case .word: word[text]
        }
    }

    func isSilent(_ text: String, as kind: SpeechKind) -> Bool {
        kind == .kana && silentKana.contains(text)
    }

    /// 번들 안 파일 위치. Xcode가 폴더를 풀어 넣는 경우와 폴더째 넣는 경우를 모두 찾는다.
    static func url(of name: String, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: name, withExtension: fileExtension)
            ?? bundle.url(forResource: name, withExtension: fileExtension, subdirectory: "Voice")
    }
}

/// 한 번 누를 때 무엇을 어떻게 읽을지.
enum SpeechPlan: Equatable {
    /// 소리를 내지 않는다(っ).
    case silent
    /// 번들의 음성 파일을 `repeats`번 재생한다.
    case file(name: String, repeats: Int)
    /// 기기 내장 음성으로 `repeats`번 읽는다.
    case synthesized(text: String, repeats: Int)
}

/// 발음 속도와 읽는 방식.
///
/// 번들 음성(VOICEVOX)이 있으면 그것을 쓰고, 없으면 기기 내장 음성으로 읽는다.
/// 글자 하나는 노래 합성으로 0.4초 안팎의 한 박을 만들어 넣었으므로(docs/design/voice/README.md
/// "최종 적용 2") 한 번만 읽는다. 짧은 말소리를 두 번 읽던 방식(2026-11-15)은 그만두었다.
///
/// 내장 음성의 속도 값은 iPhone 17 Pro 시뮬레이터(iOS 26.5, Kyoko super-compact)에서
/// `AVSpeechSynthesizer.write`로 합성 길이를 재서 정했다.
/// - 기본 속도(0.5)에서 す는 소리 0.18초, あ는 0.08초로 순식간에 끝난다.
/// - 이 음성은 속도를 낮춰도 길이가 조금만 늘어난다(0.35에서 す 0.22초, 0.0에서도 0.36초).
/// - 장음 기호(すー)로 늘이면 발음이 달라지므로 쓰지 않는다.
enum SpeechStyle {
    static let kanaRate: Float = 0.35
    static let wordRate: Float = 0.42
    /// 글자 하나를 읽는 횟수. 2 이상이면 내장 음성은 `kanaGap`만큼 쉬고, 파일은 이어서(파일 앞뒤 무음만큼 쉬고) 다시 읽는다.
    static let kanaRepeats = 1
    static let kanaGap: TimeInterval = 0.4
    /// 첫 음 앞에 두는 여백. 오디오 경로가 열리는 동안 앞이 잘리지 않게 한다.
    /// 실기기는 세션을 켠 뒤 출력이 열리기까지 시간이 걸려, 짧은 글자 소리의 앞이 묻힐 수 있다.
    static let leadIn: TimeInterval = 0.3
    /// 읽기가 끝난 뒤 세션을 닫기까지 기다리는 시간. 이어서 누르면 출력을 다시 열지 않는다.
    static let sessionLinger: TimeInterval = 3

    static func repeats(for kind: SpeechKind) -> Int {
        kind == .kana ? kanaRepeats : 1
    }

    /// 무엇으로 읽을지 정한다. `fileExists`는 번들에 그 이름의 파일이 있는지 확인한다.
    static func plan(for text: String, as kind: SpeechKind, index: VoiceIndex?,
                     fileExists: (String) -> Bool) -> SpeechPlan {
        let count = repeats(for: kind)
        if let index {
            if index.isSilent(text, as: kind) { return .silent }
            if let name = index.fileName(for: text, as: kind), fileExists(name) {
                return .file(name: name, repeats: count)
            }
        }
        return .synthesized(text: spokenText(text, as: kind), repeats: count)
    }

    /// 내장 음성에서 혼자 읽으면 다르게 읽히는 글자를 같은 소리의 다른 표기로 바꾼다.
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

/// 글자나 단어를 읽는다. 켜짐 여부는 부르는 쪽(`ProgressStore.soundOn`)에서 확인한다.
/// 번들 음성 파일이 있으면 `AVAudioPlayer`로, 없으면 기기 내장 일본어 음성으로 읽는다.
/// 다시 누르면 하던 소리를 끊고 처음부터 읽는다. 읽기를 시작한 화면이 사라지면 멈춘다.
/// 음성 파일은 앱 안에서 재생만 한다. 앱 밖으로 내보내는 기능(공유, 저장)은 두지 않는다(VOICEVOX 春日部つむぎ 약관).
final class Speaker: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()
    private lazy var voice: AVSpeechSynthesisVoice? = Self.preferredVoice()
    private let index = VoiceIndex.bundled
    /// 지금 읽는 소리를 시작한 화면. 그 화면이 사라질 때만 멈춘다.
    private var owner: UUID?
    private var lastUtterance: AVSpeechUtterance?
    /// 지금 재생 중인 음성 파일.
    private var player: AVAudioPlayer?
    private var sessionConfigured = false
    /// 예약한 재생과 세션 닫기를 무효로 만드는 번호. 새로 읽거나 멈출 때마다 올린다.
    private var generation = 0
    private static let log = Logger(subsystem: "com.carrotlab.kanatrip", category: "Speaker")

    override init() {
        super.init()
        synthesizer.delegate = self
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.stop()
        }
    }

    func speak(_ text: String, as kind: SpeechKind, owner: UUID? = nil) {
        haltAll()
        self.owner = owner

        let plan = SpeechStyle.plan(for: text, as: kind, index: index) { VoiceIndex.url(of: $0) != nil }
        switch plan {
        case .silent:
            // 끊은 내장 음성의 didCancel이 늦게 와도 세션은 여기서 닫는다.
            lastUtterance = nil
            self.owner = nil
            deactivateSession(force: true)
        case .file(let name, let repeats):
            guard let url = VoiceIndex.url(of: name), let player = try? AVAudioPlayer(contentsOf: url) else {
                speakSynthesized(SpeechStyle.spokenText(text, as: kind), kind: kind,
                                 repeats: SpeechStyle.repeats(for: kind))
                return
            }
            // 끊은 내장 음성의 didCancel이 파일 재생 중에 세션을 닫지 않게 한다.
            lastUtterance = nil
            activateSession()
            player.delegate = self
            player.numberOfLoops = max(0, repeats - 1)
            player.prepareToPlay()
            self.player = player
            play(player, after: SpeechStyle.leadIn)
        case .synthesized(let spoken, let repeats):
            speakSynthesized(spoken, kind: kind, repeats: repeats)
        }
    }

    /// `owner`가 주어지면 그 화면이 시작한 소리일 때만 멈춘다.
    func stop(owner: UUID? = nil) {
        if let owner, owner != self.owner { return }
        self.owner = nil
        let wasPlayingFile = player != nil
        haltAll()
        if wasPlayingFile { deactivateSession(force: true) }
    }

    /// 하던 소리를 모두 끊는다. 끊긴 내장 음성은 `didCancel`에서 세션을 정리한다.
    private func haltAll() {
        generation += 1
        player?.stop()
        player = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: 음성 파일

    /// `delay`만큼 기다렸다가 재생한다. 오디오 경로가 열리는 동안 앞이 잘리지 않게 한다.
    private func play(_ player: AVAudioPlayer, after delay: TimeInterval) {
        let token = generation
        // play(atTime:)은 출력 장치 시계에 기대므로 쓰지 않고, 기다렸다가 바로 재생한다.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, token == self.generation, player === self.player else { return }
            if !player.play() {
                Self.log.error("음성 파일 재생을 시작하지 못함")
                self.player = nil
                self.deactivateSession()
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === self.player else { return }  // 다시 눌러 바뀐 뒤 늦게 온 알림
        self.player = nil
        owner = nil
        deactivateSession()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard player === self.player else { return }
        self.player = nil
        owner = nil
        deactivateSession()
    }

    // MARK: 내장 음성

    private func speakSynthesized(_ spoken: String, kind: SpeechKind, repeats: Int) {
        activateSession()
        for index in 0..<repeats {
            let utterance = AVSpeechUtterance(string: spoken)
            utterance.voice = voice
            utterance.rate = kind == .kana ? SpeechStyle.kanaRate : SpeechStyle.wordRate
            if index == 0 { utterance.preUtteranceDelay = SpeechStyle.leadIn }
            if index < repeats - 1 { utterance.postUtteranceDelay = SpeechStyle.kanaGap }
            lastUtterance = utterance
            synthesizer.speak(utterance)
        }
    }

    private func finished(_ utterance: AVSpeechUtterance) {
        guard utterance === lastUtterance, !synthesizer.isSpeaking else { return }
        lastUtterance = nil
        owner = nil
        deactivateSession()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finished(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finished(utterance)
    }

    // MARK: 오디오 세션

    /// 발음은 사용자가 소리를 켜고 직접 눌러야 나므로 무음 스위치와 상관없이 들리게 한다(.playback).
    /// 다른 앱의 음악은 읽는 동안만 줄인다.
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        if !sessionConfigured {
            do {
                try session.setCategory(.playback, mode: .default, options: [.duckOthers])
                sessionConfigured = true
            } catch {
                Self.log.error("오디오 세션 설정 실패: \(error.localizedDescription)")
            }
        }
        do { try session.setActive(true) } catch {
            Self.log.error("오디오 세션 켜기 실패: \(error.localizedDescription)")
        }
    }

    /// 읽는 것이 없을 때 세션을 닫아 줄였던 다른 앱 소리를 되돌린다.
    /// `force`는 방금 모두 끊은 직후에 쓴다(끊은 내장 음성이 아직 말하는 중으로 보일 수 있다).
    private func deactivateSession(force: Bool = false) {
        guard force || (player == nil && !synthesizer.isSpeaking) else { return }
        if force {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            return
        }
        // 바로 닫지 않는다. 이어서 누를 때마다 출력을 다시 열면 짧은 소리의 앞이 잘린다.
        let token = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + SpeechStyle.sessionLinger) { [weak self] in
            guard let self, token == self.generation, self.player == nil, !self.synthesizer.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
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
