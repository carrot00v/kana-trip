# 가나 한 글자 발음 소리의 대안 조사

조사한 날짜: 2026-11-16 (모든 출처를 이 날 확인했다)

## 조사 질문

가나 한 글자(한 박) 소리를 0.3~0.45초로, 떨림·끊김·기계음 없이 낼 방법을 찾는다. 조건은 Mac에서 로컬로 만들 수 있을 것, 외부 클라우드 TTS를 쓰지 않을 것, 만든 소리를 상업 앱에 m4a로 넣을 수 있을 것이다. 배경과 지금까지의 시험은 [docs/design/voice/README.md](../design/voice/README.md) 3차·4차에 있다.

1. VOICEVOX 노래(ソング·ハミング) 합성을 지금 쓰는 voicevox_core 0.17.1에서 쓸 수 있는가.
2. 다른 로컬 일본어 TTS와 기본 제공 목소리의 라이선스.
3. 앱에 넣을 수 있는 라이선스의 사람 녹음 가나 음원.
4. macOS `say`·iOS 내장 음성의 결과를 파일로 넣는 것이 Apple 약관상 되는가.

## 요약과 추천

아무것도 내려받거나 합성하지 않았다. 아래의 "될 것이다"는 모두 문서에서 읽은 것이고, 소리 품질은 확인하지 않았다.

### 추천 1: VOICEVOX 노래 합성(ハミング)으로 春日部つむぎ 한 음 내기

- 확인: voicevox_core는 0.16.4부터 노래 합성 API가 있고, 지금 쓰는 0.17.1 파이썬 API에 `create_sing_frame_audio_query`, `create_sing_frame_f0`, `create_sing_frame_volume`, `frame_synthesis`가 있다 [V1][V2][V3].
- 확인: 노래용 모델은 `s0.vvm` 하나이고, 春日部つむぎ ノーマル의 노래 스타일 id는 3008이다 [V4][V5].
- 확인: 음표 하나에 가나 한 박(`カ`)과 길이(프레임, 1초 = 93.75프레임)와 높이(MIDI 번호)를 준다. 0.4초는 약 38프레임이다. 만들어진 쿼리의 프레임별 `f0` 목록은 합성 전에 고칠 수 있다 [V3].
- 확인: 春日部つむぎ 권리자 약관은 "VOICEVOX로 만든 春日部つむぎ의 음성"에 적용되고, 말소리와 노래를 나누지 않는다. 크레딧은 지금과 같은 `VOICEVOX:春日部つむぎ`다 [V6]. VOICEVOX 소프트웨어 약관과 VVM 약관에도 노래용 조항은 따로 없다 [V4][V7].
- 이유: 단어 소리와 같은 목소리·같은 약관·같은 도구(`tools/gen_voice.py`)로 끝난다. 노래 모델은 음을 길게 끄는 데 맞춰 학습된 모델이라, 말소리 모델에서 모음을 억지로 늘릴 때 생긴 떨림이 줄 가능성이 있다(추측, 시험 필요).
- 위험: 한 음 0.4초짜리 품질에 대한 사용자 보고는 찾지 못했다. 노래 합성은 비브라토를 자동으로 붙인다고 소개돼 있다 [V8]. 짧은 음에서 어떻게 나오는지는 모르며, `f0`를 직접 평평하게 고쳐 피할 수 있을 것으로 본다(추측).

### 추천 2: 사람 녹음으로 바꾸기 (Lingua Libre, 화자 Fukujinzuke, CC BY 4.0)

- 확인: Wikimedia Commons에 한 화자가 녹음한 가나 73개(기본 46자, ゐ·ゑ, 탁음·반탁음 25자)가 있다. 앱이 쓰는 58자가 모두 들어 있다 [H1].
- 확인: 라이선스는 CC BY 4.0이다. 상업 이용과 편집이 되고, 저작자 표시·라이선스 링크·변경 여부 표시가 조건이다 [H2].
- 확인: WAV, 파일당 약 65KB(768kbps), し는 0.7초다. 2026-10-05~11-06에 올라왔다 [H2].
- 이유: 합성의 떨림·기계음 문제가 원리상 없다. 3차 결론에 적은 "글자 46개만 사람 녹음" 대안에 해당한다.
- 위험: 글자와 단어의 목소리가 달라진다. 화자의 성별, 원어민 여부, 녹음 환경은 페이지에 없다 [H3]. 귀로 듣지 않았다. 0.3~0.45초로 맞추려면 앞뒤 무음을 자르는 편집이 필요하다.

추천 순서는 1 → 2다. 1은 받을 것이 파일 하나이고 목소리가 유지된다. 1이 귀에 맞지 않으면 2로 간다.

### 사용자에게 받아야 할 동의·다운로드

| 추천 | 받을 파일 | 크기 | 필요한 동의 |
|---|---|---|---|
| 1 | `s0.vvm` (voicevox_vvm 0.17.1). sha256 `e97971e3d9c0feaf7a373a5b13b905a885731ce61eef489857055a6631030038` [V5] | 130,412,376 B (약 124MB) | 다운로드 승인. 다운로더로 받으면 VVM 약관 동의 프롬프트가 다시 뜨므로 사용자가 직접 답한다(2026-11-15에 동의한 약관과 같은지 비교) |
| 1 | (추가 없음) 코어 0.17.1, ONNX Runtime, 사전은 이미 있다 | - | - |
| 2 | Commons의 `LL-Q5287 (jpn)-Fukujinzuke-{가나}.wav` 58~73개 | 개당 약 65KB, 합쳐 약 4~5MB | 다운로드 승인. 앱 정보 화면에 크레딧 한 줄 추가(예: `가나 발음: Fukujinzuke, Lingua Libre / Wikimedia Commons, CC BY 4.0, 길이·음량 편집`)에 대한 동의 |

- 1을 쓸 때 확인이 남은 것: 쿼리를 만들 때 넣는 "노래 선생" 스타일이 공식 예제에서는 波音リツ(id 6000)다 [V3]. 이 경우 波音リツ 크레딧이 필요한지 확인하지 못했다. 아래 "확인하지 못한 것" 참고.

## 1. VOICEVOX 노래 합성

| 항목 | 내용 | 구분 | 출처 |
|---|---|---|---|
| 코어 지원 | 0.16.4(2026-02-19)에서 노래 합성 추가. 0.17.x 릴리스 노트에는 노래 관련 변경이 없다 | 확인 | [V1] |
| 파이썬 API | `Synthesizer.create_sing_frame_audio_query(score, style_id)`, `create_sing_frame_f0`, `create_sing_frame_volume`, `frame_synthesis(frame_audio_query, style_id) -> bytes(WAV)`. `Score`, `Note` 클래스 | 확인(문서에 버전 표기는 없음) | [V2] |
| 모델 파일 | `s0.vvm` 130,412,376 B. 다운로더는 `--models-pattern`으로 고를 수 있다 | 확인 | [V1][V5] |
| 春日部つむぎ | 노래 스타일 ノーマル id 3008(말소리 id 8 + 3000). 공식 사이트는 波音リツ만 "ソング", 나머지 29명은 "ハミング"(말소리 데이터로 만든 노래 목소리)로 소개한다 | 확인 | [V4][V8] |
| 스타일 종류 | 쿼리 생성은 `singing_teacher` 또는 `sing` 종류, 합성은 `frame_decode` 또는 `sing` 종류의 스타일을 받는다. 공식 예제는 선생 6000(波音リツ) + 가수 3000(四国めたん あまあま) | 확인 | [V3] |
| 3008의 종류 | `frame_decode`일 것으로 본다. `gen_voice.py metas`로 s0.vvm을 열면 확인된다 | 추측 | - |
| 악보 | `Note(frame_length, lyric, key=…)`. 가사는 음표마다 가나 한 박. 첫 음표는 쉼표여야 한다. 자음은 앞 음표(쉼표)를 깎아 들어가고 모음이 음표 시작에 맞는다 | 확인 | [V3] |
| 길이 | 93.75프레임/초. 0.30초 = 28프레임, 0.40초 = 38프레임, 0.45초 = 42프레임 | 확인(계산) | [V3] |
| 높이 | MIDI 번호로 준다. 가수와 선생의 음역이 다르면 key를 옮기고 `f0`에 `2 ** (n/12)`를 곱하는 조정을 문서가 안내한다. `f0`는 프레임별 목록이라 직접 고칠 수 있다 | 확인 | [V3] |
| 한 음 0.4초 품질 | 사용자 보고를 찾지 못했다 | 확인 못 함 | - |
| ん, を | `Note.lyric`에 `ン`, `ヲ`를 넣을 수 있는지 확인하지 못했다 | 확인 못 함 | - |
| 약관 | VVM 약관·소프트웨어 약관·春日部つむぎ 약관 모두 노래를 따로 다루지 않는다. 春日部つむぎ 약관 1항은 VOICEVOX로 만든 음성 전체가 대상이다 | 확인 | [V4][V6][V7] |

짧은 인용 [V6] 2항: 「商用・非商用問わず利用することが出来ます」

해석:
- 말소리에서 떨림이 생긴 것은 0.15초 안팎으로 학습된 모음을 0.3초 넘게 늘렸기 때문으로 정리돼 있다(3차 결론). 노래 모델은 긴 음이 학습 범위 안이라 같은 문제가 덜할 수 있다. 다만 말하는 "か"가 아니라 노래하는 "か"처럼 들릴 수 있다. 끝을 자연스럽게 잦아들게 하려면 `volume` 목록의 끝을 내리거나 뒤 쉼표 길이로 조절하는 시험이 필요하다.
- 높이는 단어 소리 속 春日部つむぎ의 평균 높이에 맞는 MIDI 번호를 고르고, 필요하면 `f0`를 살짝 내려가는 직선으로 덮어쓰면 말소리에 가깝게 만들 수 있을 것으로 본다(추측).

## 2. 다른 로컬 일본어 TTS

"합성 음성을 상업 앱에 넣기"는 엔진 라이선스가 아니라 모델·목소리 조건으로 갈린다.

| 후보 | 엔진 라이선스 | 기본 목소리와 조건 | 상업 앱 번들 | 크레딧 | 받을 크기 | 한 음절 품질 보고 | 출처 |
|---|---|---|---|---|---|---|---|
| Kokoro-82M | Apache 2.0(가중치 포함) | 일본어 목소리 5개(jf_alpha, jf_gongitsune, jf_nezumi, jf_tebukuro, jm_kumo). 학습 자료에 CC BY 3.0인 Koniwa `tnc`가 들어 있다 | 가능 | 의무 없음(해석: 학습 자료의 CC BY 표기는 모델 카드가 하고 있다) | `kokoro-v1_0.pth` 327,212,226 B + 목소리 파일, 일본어 G2P 패키지 | **모델 카드가 짧은 발화에 약하다고 밝힌다**(10~20토큰 미만). 일본어 목소리 등급은 C+~C- | [T1][T2] |
| Style-Bert-VITS2 (JP-Extra) | AGPL-3.0 | JVNV 4종(jvnv-F1/F2/M1/M2): CC BY-SA 4.0을 이어받음. koharune-ami·amitaro: あみたろの声素材工房 규약 | JVNV: 합성 음성에 동일조건이 걸리는지 불분명. あみたろ: 규약을 지키면 상업 가능 | あみたろ는 필수(`Style-BertVITS2モデル: あみたろ、あみたろの声素材工房`) | 확인 못 함 | 찾지 못함 | [T3][T4] |
| AivisSpeech (Aivis 모델) | LGPL-3.0 | 공식 모델 まお·コハク 등. AivisHub 모델은 ACML 1.0 / ACML-NC 1.0 / CC0 또는 독자 라이선스. ACML 1.0은 상업 이용 가능, 크레딧 임의 | ACML 1.0 모델이면 가능. **まお가 어느 라이선스인지는 확인 못 함** | ACML 1.0은 임의 | 기본 모델 약 250MB + BERT 약 650MB | 찾지 못함 | [T5][T6][T7] |
| MeloTTS-Japanese | MIT(상업·비상업 모두 가능이라고 명시) | 일본어 화자 1명(이름 없음) | 가능 | 의무 없음 | 확인 못 함 | 찾지 못함 | [T8] |
| Piper | MIT(확인 안 함) | **공식 목소리 목록에 일본어가 없다**(37개 언어). 파생 프로젝트 piper-plus 쪽 일본어 모델은 라이선스가 "other" | 해당 없음 | - | - | - | [T9] |
| COEIROINK | 독자 약관 | 목소리마다 약관이 다르다 | 목소리 약관에 따름. **만든 음성을 불특정 다수가 소재로 다시 쓸 수 있게 공개하는 것은 금지** | 필수(`COEIROINK:목소리 이름`) | 확인 못 함 | 찾지 못함 | [T10] |
| Open JTalk + HTS (mei) | Modified BSD | `mei_normal.htsvoice`: CC BY 3.0, © 2009-2013 Nagoya Institute of Technology | 가능 | 필수(CC BY) | 사전은 이미 있음(VOICEVOX용). htsvoice는 수 MB(확인 안 함) | 찾지 못함 | [T11] |

해석:
- Kokoro는 모델 카드가 스스로 짧은 발화에 약하다고 적어, 한 박 용도에는 맞지 않을 가능성이 크다.
- Style-Bert-VITS2·AivisSpeech·MeloTTS는 문장 단위 자연스러움을 겨냥한 VITS 계열이다. 한 박 입력의 품질 보고는 찾지 못했고, VOICEVOX에서 본 "학습 범위 밖의 긴 모음" 문제가 같은 식으로 나올 수 있다(추측).
- Open JTalk + HTS는 통계 파라메트릭 합성이라 길이를 늘려도 주기가 흔들리지 않는다(원리상). 대신 소리가 버저처럼 평평하다. 사용자가 `P-loop`을 "기계음"이라며 거절한 것과 같은 반응이 나올 수 있다(추측).
- 어느 쪽이든 단어 소리(春日部つむぎ)와 목소리가 달라진다. 이 점은 추천 2와 같고, 사람 녹음보다 나을 근거를 찾지 못해 추천에 넣지 않았다.

## 3. 사람이 녹음한 가나 음원

| 음원 | 화자 | 범위 | 라이선스 | 형식·길이 | 표기 조건 | 비고 | 출처 |
|---|---|---|---|---|---|---|---|
| Lingua Libre, 화자 **Fukujinzuke** | 한 명(녹음자와 같음) | 73개: 기본 46자, ゐ·ゑ, 탁음·반탁음 25자 | CC BY 4.0 | WAV, 약 65KB, し 0.7초. 2026-10~11 녹음 | 저작자, 라이선스 링크, 변경 여부 | 같은 화자의 파일이 4,503개 있다. 화자 정보(성별·원어민 여부)는 없음 | [H1][H2][H3] |
| Commons, **Hakatanoshio117117** 묶음 | 한 명(자작) | 71개 확인: 분류 안 69개 + `Ja-Ka.oga`, `Ja-So.oga`. 기본 46자와 탁음·반탁음 | 퍼블릭 도메인(PD-self) | Ogg Vorbis 68~74kbps, 13~42KB, あ 2.5초·し 3.5초. 2009년 | 없음 | 파일이 2.5~3.5초라 한 글자를 여러 번 말했거나 길게 끈 것으로 보인다(추측, 듣지 않음). 녹음 방식 설명 없음. 비트레이트가 낮다 | [H4][H5] |
| Commons, Spacecat2 낱글자 | "원어민"이라고 설명 | 일부만(う お し つ ふ ろ 등) | 퍼블릭 도메인 | Ogg, 7~10KB. 2007년 | 없음 | 46자가 다 있지 않다. 다른 화자의 파일(`Ja-Chi.oga`는 CC BY-SA 3.0)과 섞여 있다 | [H6] |
| あみたろの声素材工房 | 한 명(성우) | 대사·숫자·시간 등. **가나 낱글자 묶음은 규약 페이지에서 확인되지 않음** | 독자 규약: 상업 가능, 게임·앱 동봉 가능, 크레딧 필수 | - | `音声素材：あみたろの声素材工房（https://amitaro.net/）` | 낱글자 소재가 있는지 내려받기 페이지를 따로 봐야 한다 | [H7] |
| UTAU 단독음 음원 | 음원마다 한 명 | 가나 전체(노래용 녹음) | 음원마다 독자 규약. CC0·CC BY로 공개된 것은 찾지 못함 | wav | 음원마다 다름 | 대개 UTAU 밖 이용·재배포에 조건이 있다. 쓰려면 음원 하나를 골라 규약을 따로 읽어야 한다 | [H8] |
| 공개 음성 코퍼스(Kokoro Speech Dataset, Common Voice 등) | 한 명 / 여러 명 | 문장 낭독. 낱글자 없음 | CC0 | wav | 없음 | 문장에서 박을 잘라 내야 해서 3차의 "단어 속 박 자르기"와 같은 짧음 문제가 남는다 | [H9] |

해석:
- 조건(한 화자, 46자+탁음, 상업 가능, 음질)에 가장 맞는 것은 Lingua Libre Fukujinzuke 묶음이다. 최근 WAV 녹음이고 한 파일에 한 번 발음한 길이(0.7초)다.
- Hakatanoshio 묶음은 조건이 가장 자유롭지만(퍼블릭 도메인) 2009년 저비트레이트이고 파일 구성이 불명확하다. 예비로 둔다.
- Lingua Libre 파일은 화자가 지우거나 바꿀 수 있다(し는 이미 한 번 다시 올라왔다). 쓰기로 하면 받은 날짜와 파일 페이지 주소를 기록해 둔다.

## 4. Apple 내장 음성 (`say`, AVSpeechSynthesizer)

- 확인: macOS Tahoe 26 소프트웨어 사용권 계약 2절 F항 "Voices; Live Captions"는 시스템 음성을 (1) Apple 소프트웨어를 실행하는 동안 쓰는 것과 (2) 개인적·비상업적 용도의 자기 콘텐츠를 만드는 것만 허락한다. 그 밖의 이용, 곧 영리·비영리·공개 공유·상업적 맥락에서의 녹음·공개·재배포는 허락하지 않는다고 적혀 있다 [A1].
- 짧은 인용 [A1]: "for your personal, non-commercial use"
- 결론: `say`로 만든 파일을 상업 앱에 넣는 것은 **허용되지 않는다.**
- 확인: iOS에서 `AVSpeechSynthesizer` 출력을 파일로 저장해 쓰는 것에 대한 개발자 포럼 질문에는 Apple 직원의 답이 없다. 달린 답은 "음성은 Apple의 지적 재산"이라는 한 줄이다 [A2].
- 해석: 앱 실행 중에 `AVSpeechSynthesizer`로 바로 읽는 것(이전 방식)은 "소프트웨어를 실행하는 동안의 이용"이라 문제가 없다. 미리 뽑아 번들에 넣는 것은 피한다.

## 영향

- 영향: 추천 1을 시험하려면 `s0.vvm` 다운로드와 약관 동의가 필요하다. 사용자 승인 뒤 developer가 `tools/gen_voice.py`에 노래 합성 경로를 추가해 4차와 같은 10자로 미리듣기를 만든다.
- 영향: 추천 1을 채택하면 크레딧과 약관 검토는 지금 그대로다. 波音リツ를 선생으로 쓰는 경우의 표기만 정해야 한다.
- 영향: 추천 2를 채택하면 글자와 단어의 목소리가 달라진다. "기리의 목소리" 설정(docs/design/giri-companion.md)과 맞는지는 기획·디자인 판단이다. 앱 정보 화면에 CC BY 4.0 표기가 한 줄 늘어난다.
- 영향: `say`·내장 음성을 미리 뽑아 넣는 방안은 후보에서 뺀다.

## 확인하지 못한 것

- 노래 합성으로 낸 한 음(0.3~0.45초)의 실제 소리. 떨림이 없는지, 말소리처럼 들리는지, 끝이 자연스럽게 잦아드는지. 사용자 보고도 찾지 못했다.
- 春日部つむぎ 3008의 스타일 종류(`frame_decode`인지)와, 波音リツ 6000 말고 다른 선생 스타일이 s0.vvm에 있는지.
- 波音リツ를 선생으로만 쓸 때(소리는 春日部つむぎ) 波音リツ의 크레딧·약관이 적용되는지. VOICEVOX Q&A와 약관에 노래·ハミング 항목이 없다 [V7][V9]. 波音リツ 권리자 약관은 읽지 않았다.
- 노래 가사로 `ン`, `ヲ`, 탁음을 넣을 수 있는지.
- 春日部つむぎ FAQ에 노래 관련 항목이 있는지(약관 본문만 다시 읽었다).
- Lingua Libre 화자 Fukujinzuke의 성별, 원어민 여부, 녹음 환경, 46자 각각의 음질과 길이. 파일을 받거나 듣지 않았다.
- Hakatanoshio 묶음의 파일 내용(반복인지, 길게 끈 것인지).
- AivisSpeech 공식 모델(まお 등) 각각의 라이선스, Style-Bert-VITS2·MeloTTS·COEIROINK의 모델 크기.
- JVNV(CC BY-SA 4.0) 모델로 만든 음성에 동일조건이 걸리는지.
- あみたろの声素材工房에 가나 낱글자 소재가 있는지, CC0·CC BY로 공개된 UTAU 단독음 음원이 있는지.
- iOS 사용권 계약의 해당 조항 원문(macOS 계약만 읽었다).
- Piper 본체 라이선스, mei htsvoice 파일 크기.

## 출처

VOICEVOX
- [V1] voicevox_core 릴리스 목록(0.16.1: s0.vvm 지원, 0.16.4: 노래 합성, 0.17.0, 0.17.1): https://github.com/VOICEVOX/voicevox_core/releases
- [V2] voicevox_core Python API 문서(blocking.Synthesizer): https://voicevox.github.io/voicevox_core/apis/python_api/autoapi/voicevox_core/blocking/index.html
- [V3] VOICEVOX CORE 歌唱音声合成 안내: https://github.com/VOICEVOX/voicevox_core/blob/main/docs/guide/user/song.md
- [V4] voicevox_vvm README(노래 스타일 id 표, 음성 모델 약관, 목소리별 요약): https://github.com/VOICEVOX/voicevox_vvm/blob/main/README.md
- [V5] voicevox_vvm 릴리스 0.17.1(s0.vvm 크기·digest는 GitHub 릴리스 API로 확인): https://github.com/VOICEVOX/voicevox_vvm/releases/tag/0.17.1
- [V6] 春日部つむぎ公式サイト RULE(브라우저로 렌더링해 원문 확인): https://tsumugi-official.studio.site/rule
- [V7] VOICEVOX ソフトウェア利用規約: https://voicevox.hiroshiba.jp/term/
- [V8] VOICEVOX ソング 소개 페이지(ソング·ハミング 구분, 캐릭터 목록): https://voicevox.hiroshiba.jp/song/ . 비브라토 자동 부가는 기사에서 확인(출처 하나): https://forest.watch.impress.co.jp/docs/news/1567478.html
- [V9] VOICEVOX Q&A: https://voicevox.hiroshiba.jp/qa/

다른 TTS
- [T1] Kokoro-82M 모델 카드, 파일 목록: https://huggingface.co/hexgrad/Kokoro-82M
- [T2] Kokoro-82M VOICES.md(일본어 목소리, 짧은 발화 약점): https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md
- [T3] Style-Bert-VITS2 저장소: https://github.com/litagin02/Style-Bert-VITS2
- [T4] Style-Bert-VITS2 お願いとデフォルトモデルの利用規約: https://github.com/litagin02/Style-Bert-VITS2/blob/master/docs/TERMS_OF_USE.md
- [T5] AivisSpeech Engine 저장소: https://github.com/Aivis-Project/AivisSpeech-Engine
- [T6] ACML(Aivis Common Model License) 저장소와 ACML 1.0 본문: https://github.com/Aivis-Project/ACML
- [T7] AivisHub(공식 모델 목록): https://hub.aivis-project.com/
- [T8] MeloTTS 저장소: https://github.com/myshell-ai/MeloTTS
- [T9] Piper VOICES.md(일본어 없음): https://github.com/rhasspy/piper/blob/master/VOICES.md
- [T10] COEIROINK 利用規約: https://coeiroink.com/terms
- [T11] `LICENSE_mei_normal.htsvoice`(pyopenjtalk에 든 사본을 제3자 저장소에서 확인, 출처 약함): https://huggingface.co/spaces/soiz/VOICEVOX-Engine/tree/main/linux-cpu/pyopenjtalk/htsvoice

사람 녹음
- [H1] Commons 파일 검색(API)으로 확인한 `LL-Q5287 (jpn)-Fukujinzuke-{가나}.wav` 73개. 분류: https://commons.wikimedia.org/wiki/Category:Lingua_Libre_pronunciation_by_Fukujinzuke
- [H2] 파일 페이지 예: https://commons.wikimedia.org/wiki/File:LL-Q5287_(jpn)-Fukujinzuke-し.wav , https://commons.wikimedia.org/wiki/File:LL-Q5287_(jpn)-Fukujinzuke-か.wav
- [H3] 화자 사용자 페이지: https://commons.wikimedia.org/wiki/User:Fukujinzuke
- [H4] Category:Audio files of hiragana (set by Hakatanoshio117117): https://commons.wikimedia.org/wiki/Category:Audio_files_of_hiragana_(set_by_Hakatanoshio117117)
- [H5] 파일 페이지 예: https://commons.wikimedia.org/wiki/File:Ja-A.oga , https://commons.wikimedia.org/wiki/File:Japanese_shi.ogg . 묶음 색인: https://ja.wikipedia.org/wiki/利用者:Hakatanoshio117117/ファイル-日本語発音サンプル
- [H6] Category:Pronunciation of Japanese syllables: https://commons.wikimedia.org/wiki/Category:Pronunciation_of_Japanese_syllables
- [H7] あみたろの声素材工房 규약: https://amitaro.net/voice/voice_rule/
- [H8] UTAU 음원 배포 페이지 검색 결과(음원마다 독자 규약, 예: https://booth.pm/ja/items/4978162 ). 출처 약함
- [H9] Kokoro Speech Dataset: https://www.kaggle.com/datasets/kaiida/kokoro-speech-dataset-v11-small

Apple
- [A1] Software License Agreement for macOS Tahoe 26, 2절 F항: https://www.apple.com/legal/sla/docs/macOSTahoe.pdf
- [A2] Apple Developer Forums 스레드 812285: https://developer.apple.com/forums/thread/812285
