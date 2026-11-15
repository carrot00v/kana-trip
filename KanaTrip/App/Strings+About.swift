import Foundation

/// 앱 정보 화면의 문구 (홈 "더 보기" 메뉴 → 앱 정보).
/// 크레딧과 라이선스 표기는 권리자가 정한 문구를 그대로 쓴다. 고치기 전에 출처 문서를 확인한다.
/// - 발음 소리: docs/research/voicevox-terms.md "추가 조사: 春日部つむぎ" (크레딧 `VOICEVOX:春日部つむぎ`,
///   목소리를 직접 녹음했거나 자체 제작한 것처럼 쓰지 않는다)
/// - 획 데이터: KanjiVG (CC BY-SA 3.0, Ulrich Apel), tools/build_kana_strokes.py
/// - 움직임: lottie-ios (Apache License 2.0), 라이선스 전문은 Resources/Licenses/lottie-ios-LICENSE.txt
extension L {
    static let about = "앱 정보"
    static func appVersion(_ version: String, build: String) -> String { "버전 \(version) (\(build))" }

    static let aboutVoiceHeader = "발음 소리"
    /// VOICEVOX 春日部つむぎ 약관의 크레딧 표기 예 그대로.
    static let voiceCredit = "VOICEVOX:春日部つむぎ"
    static let voiceCreditNote = "글자와 단어 발음에 VOICEVOX의 春日部つむぎ 음성을 썼어요"

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
