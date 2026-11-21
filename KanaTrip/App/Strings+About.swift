import Foundation

/// 앱 정보 화면의 문구 (홈 "더 보기" 메뉴 → 앱 정보).
/// 크레딧과 라이선스 표기는 권리자가 정한 문구를 그대로 쓴다. 고치기 전에 출처 문서를 확인한다.
/// - 발음 소리: 글자와 단어는 Qwen3-TTS(Apache 2.0)로 만들었다(docs/research/qwen-tts.md. 표기 의무는 없지만
///   출처를 밝힌다, docs/design/voice/README.md "최종 적용 3"·"최종 적용 4"·"최종 적용 5"). 2026-11-21 たこ까지
///   Serena로 바꿔 번들에 VOICEVOX 소리는 없어, 같은 날 사용자 결정(이슈 #6)으로 VOICEVOX 표기 줄과 문장을 지웠다.
/// - 획 데이터: KanjiVG (CC BY-SA 3.0, Ulrich Apel), tools/build_kana_strokes.py
/// - 움직임: lottie-ios (Apache License 2.0), 라이선스 전문은 Resources/Licenses/lottie-ios-LICENSE.txt
extension L {
    static let about = "앱 정보"
    static func appVersion(_ version: String, build: String) -> String { "버전 \(version) (\(build))" }

    static let aboutVoiceHeader = "발음 소리"
    /// 글자와 단어 발음은 Qwen3-TTS(Alibaba Cloud Qwen 팀, Apache 2.0)의 프리셋 화자로 만들었다(2026-11-21부터 단어도).
    static let qwenVoiceCredit = "Qwen3-TTS (Apache 2.0)"
    /// 정보 화면의 표기 줄과 설명 한 줄.
    static let qwenVoiceCreditLine = "글자·단어 발음: \(qwenVoiceCredit)"
    static let voiceCreditNote = "글자와 단어 발음은 Qwen3-TTS 음성으로 만들었어요"

    static let aboutStrokeHeader = "획 데이터"
    static let kanjiVG = "KanjiVG"
    static let kanjiVGCopyright = "© Ulrich Apel"
    static let kanjiVGLicense = "CC BY-SA 3.0"
    static let kanjiVGNote = "가나 획 좌표를 앱에 맞게 바꿔 썼어요. 바꾼 획 데이터도 같은 CC BY-SA 3.0을 따라요"
    static let kanjiVGURL = URL(string: "https://kanjivg.tagaini.net")!
    static let kanjiVGLicenseURL = URL(string: "https://creativecommons.org/licenses/by-sa/3.0/")!

    static let aboutMotionHeader = "움직임"
    static let lottie = "lottie-ios"
    static let lottieCopyright = "Copyright 2018 Airbnb, Inc."
    static let lottieLicense = "Apache License 2.0"
    static let lottieURL = URL(string: "https://github.com/airbnb/lottie-ios")!

    static let website = "웹사이트"
    static let licenseOnline = "라이선스 보기"
    static let licenseFullText = "라이선스 전문"
}
