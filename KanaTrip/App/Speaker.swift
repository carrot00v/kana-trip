import AVFoundation

/// 기기 내장 일본어 음성으로 글자나 단어를 읽는다. 켜짐 여부는 부르는 쪽(`ProgressStore.soundOn`)에서 확인한다.
final class Speaker {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        synthesizer.speak(utterance)
    }
}
