# 일정

PM(메인 세션)이 관리한다. 기획 결정과 미정 항목은 [PLAN.md](../PLAN.md)에 두고, 이 문서에는 일정과 우선순위, 보류 작업만 둔다.

## 보류 작업

지금 할 수 없어 미룬 작업이다. 조건이 갖춰지면 위에서부터 처리하고, 끝난 줄은 지운다(기록은 git에 남는다).

| 올린 날 | 작업 | 미룬 이유 | 다시 할 조건 | 참고 |
|---|---|---|---|---|
| 2026-11-15 | 단어 그림 생성 재개: 재생성 14장(soba, zaru, eki, otsuri, kippuuriba, omamori, omikuji, takoyaki, yakitori, tsukune, onigiri, yu, houjicha, futon)과 우선순위 2의 남은 9장. 그 뒤 후보 검토, 앱 배치, Lottie 기준점 조정 | 생성 도중 ComfyUI 서버(127.0.0.1:8188)가 응답을 멈춤. 스왑이 거의 차 메모리 부족으로 죽은 것으로 보임 | `curl -s -m 2 http://127.0.0.1:8188/system_stats`가 응답 | 프롬프트는 tools/word_art.json과 gen_word_art.py에 있음. `.venv/bin/python tools/gen_word_art.py --only word-soba ...`와 `--priority 2`를 다시 돌리면 이미 있는 후보는 건너뜀. 탈락 후보는 candidates/rejected/. 새 프롬프트로도 maguro(줄무늬), hirekatsu(색 점), oroshi(얼굴)는 탈락이라 단어당 2~3장씩 뽑아 고른다 |
