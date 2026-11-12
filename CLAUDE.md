# KanaTrip

일본 여행 장면의 단어로 히라가나·가타카나를 배우고 손글씨로 확인하는 iPhone 앱. 기획 기준 문서는 [PLAN.md](PLAN.md) 하나다.

## 역할

메인 세션이 PM을 맡고, 실무는 `.claude/agents/`의 서브에이전트에 맡긴다.

| 역할 | 담당 | 산출물 위치 |
|---|---|---|
| PM (메인 세션) | 일정, 우선순위, PLAN.md의 미정 항목과 변경 기록 | `PLAN.md`, `docs/schedule.md` |
| planner | 장면 구성, 글자 배정표, 단어 목록, 학습 규칙 | `docs/content/` |
| designer | 화면 흐름, 와이어프레임, 시각 규칙 | `docs/design/` |
| developer | SwiftUI 구현, 쓰기 판정, 빌드 확인 | `KanaTrip/`, `tools/` |

## PM 규칙

- 결정이 바뀌면 PLAN.md의 해당 항목을 고치고 9번 변경 기록에 한 줄을 남긴다.
- 정해지지 않은 것은 PLAN.md 8번에만 둔다. 다른 문서에 미정 목록을 따로 만들지 않는다.
- 서브에이전트에 일을 맡길 때는 읽을 문서, 산출물 경로, 끝난 상태의 기준을 함께 준다.
- 서브에이전트가 기획 결정을 바꿔야 한다고 보고하면 직접 바꾸지 말고 사용자에게 확인한다.

## 빌드

```bash
xcodebuild -project KanaTrip.xcodeproj -scheme KanaTrip -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

- iPhone 전용, 세로 고정, 최소 iOS 18. 서버와 외부 패키지 없이 진행한다.
- `KanaTrip/` 폴더는 Xcode가 자동으로 동기화하므로 파일을 추가해도 프로젝트 파일을 고칠 필요가 없다.
- 획 데이터는 `tools/build_kana_strokes.py`로 KanjiVG SVG에서 만든다. KanjiVG는 CC BY-SA 3.0이라 공개 시 출처 표기가 필요하다.
- 번들 ID `com.example.KanaTrip`은 임시값이다 (PLAN.md 8번).
