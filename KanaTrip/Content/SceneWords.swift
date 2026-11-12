import Foundation

// 장면 단어를 "배운 글자"에 맞춰 나누고 고르는 계산 (docs/design/scene-flow.md 5.1, 6.1).
// 새로 저장하는 값 없이 장면 데이터와 진도에서 계산한다.

/// 목표 단어 카드에 싣는 단어 묶음.
struct SceneWordGroups {
    /// 이 장면까지의 글자만으로 읽을 수 있는 단어.
    let goal: [TripWord]
    /// 아직 못 읽는 글자가 있는 단어.
    let rest: [TripWord]
}

/// 글자 소개에 보여 줄 단어와, 그 글자까지 배웠을 때 아는 글자.
struct IntroWord {
    let word: TripWord
    let known: Set<String>
}

extension TripWord {
    /// `units` 가운데 `kana`에 드는 칸의 수. 같은 글자가 두 번 나오면 두 번 센다.
    func count(in kana: Set<String>) -> Int {
        units.count { kana.contains($0.kana) }
    }
}

extension ContentLibrary {
    /// 이 장면보다 앞 장면들의 새 글자.
    func kana(before scene: TripScene) -> Set<String> {
        Set(scenes.filter { $0.order < scene.order }.flatMap(\.kana))
    }

    /// 배운 글자: 이전 장면들의 새 글자 전부 + 이 장면에서 배우기를 끝낸 글자.
    /// 배우기 완료 여부를 먼저 본다. 끝낸 배우기를 다시 하는 동안 `learnDone`이 비어도 도로 줄지 않는다.
    func learnedKana(in scene: TripScene, progress: SceneProgress) -> Set<String> {
        let current = progress.completed.contains(.learn) ? scene.kana : progress.learnDone
        return kana(before: scene).union(current)
    }

    /// 이 장면의 단어를 목표 단어와 나머지로 나눈다. 데이터 순서를 유지한다.
    func wordGroups(for scene: TripScene) -> SceneWordGroups {
        let reachable = learnedKana(through: scene)
        var goal: [TripWord] = []
        var rest: [TripWord] = []
        for word in scene.words {
            if word.count(in: reachable) == word.units.count {
                goal.append(word)
            } else {
                rest.append(word)
            }
        }
        return SceneWordGroups(goal: goal, rest: rest)
    }

    /// 글자 소개에 보여 줄 단어. 그 글자까지 배웠을 때 가장 많이 채워지는 단어를 고르고,
    /// 동점이면 데이터에서 앞에 있는 단어를 고른다. 저장된 진행은 보지 않는다.
    func introWord(for char: String, in scene: TripScene) -> IntroWord? {
        guard let index = scene.kana.firstIndex(of: char) else { return nil }
        let known = kana(before: scene).union(scene.kana[...index])

        var best: (word: TripWord, filled: Int)?
        for word in scene.words where word.units.contains(where: { $0.kana == char }) {
            let filled = word.count(in: known)
            // 채워진 비율을 나눗셈 없이 비교한다. 같으면 앞 단어를 그대로 둔다.
            if let current = best, filled * current.word.units.count <= current.filled * word.units.count {
                continue
            }
            best = (word, filled)
        }
        return best.map { IntroWord(word: $0.word, known: known) }
    }
}
