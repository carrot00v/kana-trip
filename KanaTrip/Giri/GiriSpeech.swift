import Foundation

// 화면마다 기리가 할 말을 고르는 규칙 (docs/design/giri-companion.md 3번, docs/content/giri-lines.md).
// SwiftUI에 의존하지 않는다. planner 대사는 데이터(단어 `giri`, 장면 `giriIntro`, hiragana_tips.json,
// confusable_pairs.json `giri`), designer 고정 대사는 Strings.swift에 있다.

/// 대사를 고를 때 필요한 데이터 조회. 앱은 `ContentLibrary`, 테스트는 작은 표를 쓴다.
protocol GiriLookup {
    /// 두 글자가 헷갈리는 쌍이면 짚는 말.
    func pairLine(_ a: String, _ b: String) -> String?
    /// 46자 가운데 이 로마자로 읽는 글자.
    func kana(forRomaji romaji: String) -> String?
}

extension ContentLibrary: GiriLookup {
    func kana(forRomaji romaji: String) -> String? {
        steps.flatMap(\.kana).first { kana($0)?.romaji == romaji }
    }
}

enum GiriSpeech {
    // MARK: 쓰기 포인트 (L1, L2, QC 가이드)

    static func writingTip(_ tip: String?) -> String {
        guard let tip, !tip.isEmpty else { return L.giriNoTip }
        return tip
    }

    /// QC에서 가이드가 켜졌을 때. 쓰기 포인트가 없으면 가이드 문구.
    static func guideTip(_ tip: String?) -> String {
        guard let tip, !tip.isEmpty else { return L.giriGuideNoTip }
        return tip
    }

    // MARK: 단어 읽기 (W)

    /// 읽기 전 안내의 상태. 위에서부터 먼저 맞는 것 하나를 쓴다 (giri-lines.md 4.2).
    enum ReadingContext: Equatable {
        /// 단계 b 맨 앞의 다시 읽기 단어. 값은 단계 a 이름.
        case reread(previousStep: String)
        /// 이 세션에서 발음 표기가 붙은 첫 단어.
        case firstRuby
        /// 붙여 쓴 한자가 있는 단어.
        case kanji
        case plain
    }

    static func readingContext(isReread: Bool, previousStep: String?, isFirstRuby: Bool, hasKanji: Bool) -> ReadingContext {
        if isReread, let previousStep { return .reread(previousStep: previousStep) }
        if isFirstRuby { return .firstRuby }
        if hasKanji { return .kanji }
        return .plain
    }

    static func beforeReading(_ context: ReadingContext) -> String {
        switch context {
        case .reread(let previous): L.giriReread(previous)
        case .firstRuby: L.giriFirstRuby
        case .kanji: L.giriKanjiWord
        case .plain: L.giriReadAloud
        }
    }

    /// "읽기 확인" 뒤. 단어 설명이 없으면 대체 문구.
    static func afterReading(_ explanation: String?, scene: String, step: String) -> String {
        guard let explanation, !explanation.isEmpty else { return L.giriWordFallback(scene: scene, step: step) }
        return explanation
    }

    // MARK: 종합 퀴즈 (QA, QD, QC)

    /// 문항이 나올 때의 말. 다시 내는 문항 → 부의 첫 문항(2부, 3부) → 질문 순서로 고른다.
    static func question(kind: QuizKind, isPartStart: Bool, isRetry: Bool) -> String {
        if isRetry { return kind == .recallWrite ? L.giriRetryWrite : L.giriRetryRead }
        switch kind {
        case .readingChoice: return L.giriAskKana
        case .wordReading: return isPartStart ? L.giriPartWord : L.giriAskWord
        case .recallWrite: return isPartStart ? L.giriPartWrite : L.giriAskWrite
        }
    }

    /// QA·QD 오답 때 짚는 말 (giri-lines.md 6.1). 헷갈리는 쌍이면 쌍의 짚는 말, 아니면 틀 문구.
    /// - Parameters:
    ///   - picked: 고른 보기의 로마자.
    ///   - word: QD의 단어. 바꾼 칸의 읽기를 쓴다.
    static func wrongAnswer(item: QuizItem, picked: String, word: TripWord?, lookup: GiriLookup) -> String? {
        let wrong = item.wrong(picked: picked)
        switch item.kind {
        case .readingChoice:
            guard let c = item.kana else { return nil }
            let k = wrong?.replacement ?? lookup.kana(forRomaji: picked)
            if let k, let line = lookup.pairLine(c, k) { return line }
            if let k {
                return L.giriWrongKana(picked: picked, pickedKana: k, correct: c, correctRomaji: item.answer)
            }
            return nil
        case .wordReading:
            guard let wrong, let k = wrong.original else { return nil }
            if let s = wrong.replacement, let line = lookup.pairLine(k, s) { return line }
            let romaji = wrong.changedIndex.flatMap { i in word?.units.indices.contains(i) == true ? word?.units[i].romaji : nil }
            guard let romaji else { return nil }
            return L.giriWrongWord(kana: k, romaji: romaji)
        case .recallWrite:
            return nil
        }
    }

    // MARK: 홈 (H)

    enum HomeTurn: Equatable {
        /// 아무것도 하지 않음 (장면 1 단계 a 처음).
        case first(scene: String)
        /// 다음 장면 단계 a 차례.
        case newScene(scene: String, step: String)
        /// 단계 b 차례.
        case stepB(scene: String, step: String)
        /// 종합 퀴즈 차례.
        case quiz(scene: String)
        /// 하던 중. `session`은 단계 이름 또는 "종합 퀴즈".
        case resume(scene: String, session: String)
        case allDone
        case comingSoon
    }

    static func home(_ turn: HomeTurn) -> String {
        switch turn {
        case .first(let scene): L.giriHomeFirst(scene)
        case .newScene(let scene, let step): L.giriHomeNewScene(scene: scene, step: step)
        case .stepB(let scene, let step): L.giriHomeStepB(scene: scene, step: step)
        case .quiz(let scene): L.giriHomeQuiz(scene)
        case .resume(let scene, let session): L.giriHomeResume(scene: scene, session: session)
        case .allDone: L.giriAllDone
        case .comingSoon: L.giriComingSoon
        }
    }

    /// 홈 지도 기리의 한 줄 대사 (home-map.md R2.5). 지도 말풍선과 큰 글자 크기의 아래 카드, VoiceOver가 쓴다.
    static func homeLine(_ turn: HomeTurn) -> String {
        switch turn {
        case .first(let scene): L.giriHomeLineFirst(scene)
        case .newScene(let scene, _): L.giriHomeLineNewScene(scene)
        case .stepB(_, let step): L.giriHomeLineStepB(step)
        case .quiz: L.giriHomeLineQuiz
        case .resume: L.giriHomeLineResume
        case .allDone: L.giriAllDone
        case .comingSoon: L.giriComingSoon
        }
    }

    // MARK: 장면 진입 (S)

    enum SceneTurn: Equatable {
        case stepA(scene: String, step: String, intro: String?)
        case stepB(step: String)
        case quiz
        case resume(session: String)
        case done(scene: String)
    }

    static func scene(_ turn: SceneTurn) -> String {
        switch turn {
        case .stepA(let scene, let step, let intro):
            if let intro, !intro.isEmpty { intro } else { L.giriSceneStepA(scene: scene, step: step) }
        case .stepB(let step): L.giriSceneStepB(step)
        case .quiz: L.giriSceneQuiz
        case .resume(let session): L.giriSceneResume(session)
        case .done(let scene): L.giriSceneDone(scene)
        }
    }

    // MARK: 퀴즈 안내 (QI)

    static func quizIntro(scene: String, isReplay: Bool) -> String {
        isReplay ? L.giriQuizIntroReplay : L.giriQuizIntro(scene)
    }

    // MARK: 완료 (C1, C2)

    enum Completion: Equatable {
        /// 단계 a를 처음 끝냄.
        case stepA(step: String, next: String)
        /// 단계 b를 처음 끝냄.
        case stepB
        /// 끝낸 단계를 다시 함.
        case stepReplay
        /// 통과한 퀴즈를 다시 함.
        case quizReplay
        /// 장면 완료(C2).
        case scene(scene: String, hadWrong: Bool, isLastScene: Bool)
    }

    static func completion(_ c: Completion) -> String {
        switch c {
        case .stepA(let step, let next): L.giriDoneStepA(step: step, next: next)
        case .stepB: L.giriDoneStepB
        case .stepReplay: L.giriDoneStepReplay
        case .quizReplay: L.giriDoneQuizReplay
        case .scene(let scene, let wrong, let last):
            if last { L.giriDoneAll } else if wrong { L.giriDoneSceneWrong } else { L.giriDoneScene(scene) }
        }
    }
}
