import Foundation

// 단계 단어를 "배운 글자"에 맞춰 나누고 고르는 계산 (docs/design/scene-flow.md 4.4, 8.1).
// 새로 저장하는 값 없이 장면 데이터와 진도에서 계산한다.

/// 단계의 단어 묶음.
struct StepWordGroups {
    /// 목표 단어: 이 단계까지의 글자만으로 읽을 수 있는 단어. 데이터 순서.
    let goal: [TripWord]
    /// 아직 못 읽는 글자가 있는 단어. 데이터 순서.
    let rest: [TripWord]
}

/// 글자 소개에 보여 줄 단어와, 그 글자까지 배웠을 때 아는 글자.
struct IntroWord {
    let word: TripWord
    /// 단어가 실린 단계. 대개 지금 단계이고, 후보가 없을 때만 같은 장면의 다른 단계다.
    let step: TripStep
    let known: Set<String>
}

extension TripWord {
    /// 가나 칸 가운데 `kana`에 드는 칸의 수. 같은 글자가 두 번 나오면 두 번 센다. 한자 칸은 세지 않는다.
    func count(in kana: Set<String>) -> Int {
        kanaUnits.count { kana.contains($0.kana) }
    }

    func isReadable(with kana: Set<String>) -> Bool {
        count(in: kana) == kanaUnits.count
    }
}

extension ContentLibrary {
    /// 단계의 단어를 목표 단어와 나머지로 나눈다.
    func wordGroups(for step: TripStep) -> StepWordGroups {
        let reachable = kana(through: step)
        return StepWordGroups(
            goal: step.words.filter { $0.isReadable(with: reachable) },
            rest: step.words.filter { !$0.isReadable(with: reachable) }
        )
    }

    /// 화면에 목표 단어로 보여 줄 단어. 전부 읽히는 단어가 없는 단계(3a うどん, そば)는 단어를 그대로 보여 준다
    /// (hiragana-allocation.md 8번: 빈 목록이 나오지 않게 한다).
    func shownGoalWords(for step: TripStep) -> [TripWord] {
        let groups = wordGroups(for: step)
        return groups.goal.isEmpty ? step.words : groups.goal
    }

    /// 장면 진입의 못 읽는 단어 줄. `shownGoalWords`에 든 단어는 빼고 데이터 순서로.
    func shownRestWords(for step: TripStep) -> [TripWord] {
        let goal = Set(shownGoalWords(for: step).map(\.text))
        return step.words.filter { !goal.contains($0.text) }
    }

    /// 장면의 목표 단어: 두 단계의 목표 단어를 단계 순서대로 이은 것 (C2).
    func goalWords(for scene: TripScene) -> [TripWord] {
        scene.steps.flatMap { shownGoalWords(for: $0) }
    }

    /// 글자 소개에 보여 줄 단어 (scene-flow.md 8.1).
    /// 후보는 이 단계 단어 가운데 지금 글자가 있는 단어, 없으면 같은 장면의 다른 단계 단어.
    /// 아는 글자 비율이 가장 높은 단어를 고르고, 같으면 데이터에서 앞 단어. 저장된 진행은 보지 않는다.
    func introWord(for char: String, in step: TripStep) -> IntroWord? {
        guard let index = step.kana.firstIndex(of: char) else { return nil }
        let known = kana(before: step).union(step.kana[...index])

        let others = scene(of: step)?.steps.filter { $0.id != step.id } ?? []
        for candidates in [[step]] + others.map({ [$0] }) {
            var best: (word: TripWord, step: TripStep, filled: Int)?
            for source in candidates {
                for word in source.words where word.kanaUnits.contains(where: { $0.kana == char }) {
                    let filled = word.count(in: known)
                    // 채워진 비율을 나눗셈 없이 비교한다. 같으면 앞 단어를 그대로 둔다.
                    if let current = best, filled * current.word.kanaUnits.count <= current.filled * word.kanaUnits.count {
                        continue
                    }
                    best = (word, source, filled)
                }
            }
            if let best { return IntroWord(word: best.word, step: best.step, known: known) }
        }
        return nil
    }
}
