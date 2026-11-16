# 일정

PM(메인 세션)이 관리한다. 기획 결정과 미정 항목은 [PLAN.md](../PLAN.md)에 두고, 이 문서에는 일정과 우선순위, 보류 작업만 둔다.

## 보류 작업

지금 할 수 없어 미룬 작업이다. 조건이 갖춰지면 위에서부터 처리하고, 끝난 줄은 지운다(기록은 git에 남는다).

| 올린 날 | 작업 | 미룬 이유 | 다시 할 조건 | 참고 |
|---|---|---|---|---|
| 2026-11-16 | 꾸미기 새 아이템 그림 7장: tamago, tonkatsu_slice, chikuwa, manjuu(머리), ebiten, shake, umeboshi(속재료). 앱에는 임시 그림이 들어가 있다. 머리 4장은 head-fit.md 3.4의 새 프롬프트(items.json에 반영됨)로 그린다 | ComfyUI(127.0.0.1:8188)가 응답하지 않음 | `curl -s -m 2 http://127.0.0.1:8188/system_stats`가 응답하고 모델 파일이 있을 때 | 프롬프트와 놓는 값: docs/design/item-art/brief.md 3.2, 2.2, 2.3.6. 다 그리면 place_item_art.py로 놓고 "가장 복잡한 조합" 비교 시트 확인 |
| 2026-11-17 | 머리 아이템 다시 그리기 2장: hachimaki(머리를 가로지르는 열린 띠 + 매듭·꼬리), tenugui(모서리 둥근 작은 접은 덩어리). omen은 지금 그림을 새 자리에 놓아 보고 검사를 통과하지 못할 때만 다시 그린다 | 음성 생성이 메모리를 쓰는 중이라 그림을 같이 돌리지 않음 | 음성 검증 작업이 끝나고 `curl -s -m 2 http://127.0.0.1:8188/system_stats`가 응답할 때 | docs/design/item-art/head-fit.md 3번, items.json |
