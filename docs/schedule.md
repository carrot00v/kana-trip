# 일정

PM(메인 세션)이 관리한다. 기획 결정과 미정 항목은 [PLAN.md](../PLAN.md)에 두고, 이 문서에는 일정과 우선순위, 보류 작업만 둔다.

## 보류 작업

지금 할 수 없어 미룬 작업이다. 조건이 갖춰지면 위에서부터 처리하고, 끝난 줄은 지운다(기록은 git에 남는다).

| 올린 날 | 작업 | 미룬 이유 | 다시 할 조건 | 참고 |
|---|---|---|---|---|
| 2026-11-15 | 단어 그림 word-okame 그리기 (2차 검수 뒤 남은 단어 그림은 이것 하나) | 고명 구성(어묵·표고·달걀 등)이 해설 기사 한 곳뿐이라 확인 전(tools/word_art.json `hold`, word-images.md 2.3) | researcher가 おかめそば 고명 구성을 확인하고 planner가 Subject를 정함 | hold를 지우고 `.venv/bin/python tools/gen_word_art.py --only word-okame --count 2` → `tools/clean_word_art.py`로 다듬어 확정 → `place_word_art.py okame`, `build_word_lottie.py okame`(김 기준점 측정). 앱은 그때까지 빈 자리 |
