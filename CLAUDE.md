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
- 지금 할 수 없어 미룬 작업은 `docs/schedule.md`의 "보류 작업"에 올린다. 무엇을, 왜 미뤘는지, 어떤 조건에서 다시 하는지를 함께 적는다. 다시 할 수 있게 되면 그 목록부터 확인한다.

## 그림 생성

장면 이미지, 기리 꾸미기 공간과 소품, 리워드 아이템, 아이콘 시안 같은 그림 재료와 그 콘셉트는 로컬 이미지 모델로 만든다. 외부 이미지 서비스는 쓰지 않는다.

- 대상이 아닌 것: 화면 배치, 컴포넌트, 색·글꼴 같은 UI 레이아웃. 이런 작업은 `docs/design/`의 규칙을 기준으로 SwiftUI로 구현하고 시뮬레이터 스크린샷으로 확인한다. 이미지 모델로 화면 목업을 만들지 않는다.
- 환경: Comfy Desktop의 ComfyUI(`127.0.0.1:8188`)와 Z-Image Turbo(Apache 2.0). 모델 파일은 `~/ComfyUI-Shared/models` 아래 `diffusion_models/z_image_turbo_bf16.safetensors`, `text_encoders/qwen_3_4b.safetensors`, `vae/ae.safetensors`다.
- 도구: `tools/gen_image.py`(한 장 생성), `tools/remove_bg.py`(단색 바탕을 투명으로), `tools/gen_item_art.py`(리워드 아이템 일괄 생성), `tools/place_item_art.py`(아이템 배치·썸네일·가나 합성). 이미지 도구는 안드로이드 확장을 위해 파이썬 + Pillow로 통일한다. 처음 한 번 `python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt`로 준비하고, `.venv/bin/python`으로 실행한다.
- 화풍 기준은 캐릭터 기리다. 그리기 전에 `docs/design/visual-rules.md`와 `docs/design/item-art/brief.md`를 읽는다.
- 생성은 한 번에 하나씩, 오래 걸리면 백그라운드로 돌린다. 기준 Mac(M4 Pro 24GB)에서 1024px 한 장에 3.5~5분 걸린다.
- 다른 모델을 받거나 클라우드 GPU·외부 API를 쓰려면 사용자에게 먼저 묻는다.
- **로컬 환경이 없으면 그림 작업은 보류한다.** 시작 전에 `curl -s -m 2 http://127.0.0.1:8188/system_stats`가 응답하는지와 모델 파일이 있는지 본다. 하나라도 없으면 그림을 대신 만들지 않는다. 다른 방법(SVG 직접 그리기, 외부 서비스)으로 바꾸지도 않는다. 할 그림과 프롬프트 초안을 `docs/schedule.md`의 보류 작업에 올리고, 그림이 필요 없는 나머지 작업을 이어 간다.

## 빌드

```bash
xcodebuild -project KanaTrip.xcodeproj -scheme KanaTrip -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

- iPhone 전용, 세로 고정, 최소 iOS 18. 서버와 외부 패키지 없이 진행한다.
- `KanaTrip/` 폴더는 Xcode가 자동으로 동기화하므로 파일을 추가해도 프로젝트 파일을 고칠 필요가 없다.
- 획 데이터는 `tools/build_kana_strokes.py`로 KanjiVG SVG에서 만든다. KanjiVG는 CC BY-SA 3.0이라 공개 시 출처 표기가 필요하다.
- 번들 ID `com.example.KanaTrip`은 임시값이다 (PLAN.md 8번).
