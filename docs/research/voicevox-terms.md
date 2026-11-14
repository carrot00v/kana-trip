# VOICEVOX 약관·배포 파일·길이 조절 조사

조사한 날짜: 2026-11-15 (모든 출처를 이 날 확인했다)

## 조사 질문

1. VOICEVOX 소프트웨어 약관과 엔진·코어 라이선스. 만든 음성을 상업 앱에 파일로 넣어 배포해도 되는지, 크레딧 조건.
2. 목소리(캐릭터)별 약관과 추천 순서.
3. macOS Apple Silicon용 공식 배포 파일(이름, 크기, URL, 압축 형식, 실행 방법, 체크섬)과 더 가벼운 대안.
4. API로 한 박짜리 가나를 또렷하고 길게 읽게 하는 방법, 가나를 그대로 읽히는 방법.
5. speaker(style) id를 얻는 방법과 후보들의 id.

## 요약

VOICEVOX로 만든 음성은 크레딧을 적으면 상업 이용이 가능하고, 실제 조건은 목소리마다 다른 "음성 라이브러리 약관"이 정한다. 소프트웨어 약관이 금지하는 재배포는 소프트웨어 자체에 대한 것이고, 앱에는 음성 파일만 넣으므로 엔진의 LGPL도 적용 대상이 아니다(해석). 후보 가운데 四国めたん(약관 주체 SSS LLC)이 가장 명확하다. 약관에 "앱에서 쓸 때는 앱 소개 화면 등에 크레딧"이라고 적혀 있고 개인·법인을 가르지 않는다. No.7은 상업 이용과 교육 이용 모두 사전 확인이 필요해 제외하는 편이 맞고, ナースロボ＿タイプＴ는 "AI로 생성한 그림에 목소리를 입히는 것"을 금지해 로컬 이미지 모델로 그림을 만드는 KanaTrip과 충돌할 수 있다. 春日部つむぎ, WhiteCUL, 青山龍星은 권리자 약관 페이지를 읽지 못해 "확인 필요"다. 엔진은 0.26.1(1.89GB, 7z 한 조각)이고, 코어 0.17.1 + 필요한 `.vvm` 하나만 받는 방법은 약 70MB로 끝난다. 길이는 `speedScale`(전체)과 박별 `vowel_length`(초)로 조절하고, 가나 그대로 읽히기는 `is_kana=true`의 AquesTalk 풍 표기로 한다.

## 1. 소프트웨어 약관과 라이선스

| 대상 | 확인한 내용 | 짧은 인용 | 출처 |
|---|---|---|---|
| VOICEVOX 소프트웨어 이용 약관 | 허락 3항: (1) 상업·비상업 이용 가능 (2) 만든 음성은 각 음성 라이브러리 약관을 따름 (3) 만든 음성의 이용을 남에게 허락할 때는 2·3항 준수를 의무로 지움. 금지: 소프트웨어 전부·일부의 무단 재배포, 역컴파일·리버스 엔지니어링, 제작자·제3자에게 불이익을 주는 행위, 공서양속 위반. 기타: VOICEVOX를 썼음을 알 수 있는 크레딧 표기 필요 | 「商用・非商用問わず利用することができます」 | [S1] |
| VOICEVOX ENGINE | LGPL v3와, 소스 공개가 필요 없는 별도 라이선스의 듀얼 라이선스. 별도 라이선스는 제작자(ヒホ)에게 요청 | 「LGPL v3 と、ソースコードの公開が不要な別ライセンスのデュアルライセンスです」 | [S2] |
| VOICEVOX CORE | 소스와 빌드 산출물 모두 MIT. 0.16 미만의 빌드된 코어는 다른 라이선스 | 「ソースコード及びビルド成果物のライセンスは MIT LICENSE です」 | [S3] |
| VOICEVOX 음성 모델(VVM) 약관 | 상업·비상업 이용 가능, 앱에 넣어 재배포 가능, 만든 음성은 각 음성 라이브러리 약관을 따름, 크레딧 필요. 금지 항목에 "무단 재배포"가 없다 | 「アプリケーションに組み込んで再配布することができます」 | [S4] |
| 공식 Q&A | 회사·학교에서도 크레딧을 적으면 상업·비상업 모두 가능. 음성만 쓰는 경우 등 크레딧 위치 안내. 캐릭터 약관에 안내가 있으면 그쪽이 우선. 크레딧 생략은 캐릭터 권리자가 창구인 유상 라이선스. 약관 준수 여부 질문에는 원칙적으로 답하지 않음 | (5번 출처 인용은 4절에 사용) | [S5] |

해석:
- 앱 번들에 넣는 것은 엔진·코어·모델이 아니라 만들어진 음성 파일(wav/m4a)뿐이다. 소프트웨어 약관의 "무단 재배포 금지"와 엔진의 LGPL은 소프트웨어 자체에 걸리므로 KanaTrip에는 적용되지 않는다. 생성 음성에 걸리는 조건은 (a) VOICEVOX 크레딧, (b) 목소리별 약관 두 가지다.
- 소프트웨어 약관 3항("음성 이용을 남에게 허락할 때")은 음성을 소재로 넘겨줄 때의 조건이다. 앱 사용자는 앱 안에서 듣기만 하므로 해당하지 않는다고 본다. 다만 약관에 "앱 번들에 넣은 음성 파일"을 직접 다룬 문장은 없다. 공식 Q&A가 준수 여부 질문에 답하지 않는다고 밝히고 있어 공식 확답을 받기는 어렵다.
- 크레딧 위치는 소프트웨어 약관이 정하지 않는다. 목소리 약관(아래 四国めたん)이 "앱 소개 화면 등, 조금 찾으면 알 수 있는 곳"이라고 정한다.

## 2. 목소리별 약관

"VOICEVOX 요약"은 VOICEVOX가 공식 저장소(voicevox_vvm README, voicevox_resource의 policy.md)에 적어 둔 목소리별 요약이고, "권리자 약관"은 각 권리자 사이트의 원문이다.

| 순위 | 목소리 (권리자 약관 주체) | VOICEVOX 요약 [S4] | 권리자 약관에서 확인한 것 | 크레딧 문구 | 걸릴 만한 금지·주의 | 권리자 약관 확인 |
|---|---|---|---|---|---|---|
| 1 | 四国めたん (SSS LLC, zunko.jp). 같은 약관: 九州そら, 東北ずん子, 東北きりたん, 東北イタコ, ずんだもん, 中国うさぎ, 中部つるぎ | 크레딧을 적으면 상업·비상업 가능 | 상업·비상업 가능. 개인·법인 구분 없음. 앱은 소개 화면 등에 크레딧. 크레딧 없는 상업 이용은 캐릭터당 40만 엔(+세) 계약 | `VOICEVOX:四国めたん` | 공서양속, 정치·종교, 특정 개인·단체(국가 포함) 비난·응원, 정보상재, 허위 정보, 풍속 영업, 반사회 세력. 학습 앱에 걸릴 항목은 보이지 않음(해석). 음성 소재 재배포·AI 학습에 관한 문장은 없음 | 원문 직접 확인 [S6] |
| 2 | 冥鳴ひまり (meimeihimari.com) | 크레딧을 적으면 상업·비상업 가능 | 상업·비상업 가능, 개인·법인 모두 신청·보고 불필요, 크레딧 필요 | `VOICEVOX:冥鳴ひまり` | 공서양속, 제3자에게 불이익, 특정 사상·단체, "冥鳴ひまり가 부적절하다고 판단하는 행위"(범위가 열려 있음). 앱·게임에 넣는 경우를 직접 다룬 문장은 없음 | 요약 도구를 거쳐 확인(원문 대조는 못 함) [S7] |
| 3 | 春歌ナナ (nanahira.jp) | 크레딧을 적으면 상업·비상업 가능 | 상업·비상업 가능. FAQ에서 게임·앱 등 동영상·악곡 외 사용 가능, 사용자가 볼 수 있는 곳에 크레딧. 노래 음원의 상업 이용만 사전 연락 필수 | `VOICEVOX:春歌ナナ` | 공식 제작물로 오해될 형태의 공개 금지, "ななひら" 명의 크레딧 금지, 성인·그로 금지, 특정 사상·단체, 제작팀이 부적절하다고 판단하는 행위 | 요약 도구를 거쳐 확인 [S8] |
| 4 | ナースロボ＿タイプＴ (krnr.top) | 크레딧을 적으면 상업·비상업 가능 | 개인·법인·단체의 상업·비상업 이용 허락(표기 필수) | `VOICEVOX:ナースロボ＿タイプＴ` | **AI로 생성한 그림·영상에 목소리를 입히는 것 금지**, 출력 음성을 다른 AI에 학습시키는 것 금지, 남이 쓸 음성 소재로 무단 판매 금지, 의료 지식 오류 유포 금지. 약관이 2026-11-07에 고쳐졌다(자주 바뀜) | 원문 직접 확인 [S9] |
| 5 | 春日部つむぎ (tsumugi-official.studio.site) | 크레딧을 적으면 상업·비상업 가능 | 확인 필요 (페이지가 스크립트로만 그려져 본문을 읽지 못함) | `VOICEVOX:春日部つむぎ` | 확인 필요 | 못 함 [S10] |
| 6 | WhiteCUL (whitecul.com) | 크레딧을 적으면 상업·비상업 가능 | 확인 필요 (약관 주소가 `/lander`로 넘어가고 본문이 비어 있음. 도메인 상태부터 확인 필요) | `VOICEVOX:WhiteCUL` | 확인 필요 | 못 함 [S11] |
| 7 | 青山龍星 (virvoxproject.com / ななはぴ) | **개인**은 크레딧을 적으면 상업·비상업 가능. **기업이 관여하는 형태**는 ななはぴ에 사전 확인 필요 | 확인 필요 (사이트 점검 중, HTTP 503) | `VOICEVOX:青山龍星` | 사업자·법인 명의로 내면 사전 확인 대상 | 못 함 [S12] |
| 제외 | No.7 (No.7 製作委員会, voiceseven.com) | 개인의 **비상업**(동인·방송 수익은 가능)만 크레딧으로 가능. 그 밖의 상업 이용은 사전 확인 필요 | 게임은 상업 이용으로 상담 대상, 크레딧 있는 상업 라이선스는 유료(1만 5천 엔부터라고 안내), 크레딧 없는 상업 이용은 25만 엔(+세). **교육 목적 이용은 사전 상담** | `VOICEVOX:No.7` | 유료 앱·교육 앱 둘 다 사전 확인 대상 | 요약 도구를 거쳐 확인 [S13] |

짧은 인용:
- [S6] 四国めたん: 「アプリの紹介画面などに記載をお願いします」
- [S7] 冥鳴ひまり: 「個人、法人問わずご利用いただけます」
- [S9] ナースロボ＿タイプＴ 금지 항목: 「AIで生成した画像・動画に声を当てること」

해석과 추천 순서:
1. **四国めたん ノーマル(id 2)**. 앱 이용과 크레딧 위치가 약관에 적혀 있고, 개인·법인 구분이 없으며, 원문을 직접 읽었다. 같은 약관 아래 九州そら ノーマル(16), 東北ずん子 ノーマル(107), 東北イタコ ノーマル(109)도 있어 목소리를 바꿔도 약관 검토를 다시 할 필요가 없다.
2. **冥鳴ひまり ノーマル(id 14)**. 개인·법인 모두 신청 불필요. 앱을 직접 언급하지는 않는다.
3. **春歌ナナ ノーマル(id 54)**. 앱·게임 사용이 FAQ에 적혀 있다. 공식 제작물로 오해받지 않게 하는 조건이 붙는다.
4. 春日部つむぎ(8), WhiteCUL(23): VOICEVOX 요약상으로는 1~3과 같은 조건이지만 권리자 원문을 읽기 전에는 쓰지 않는 편이 안전하다.
5. ナースロボ＿タイプＴ(47): KanaTrip은 단어 그림과 장면 그림을 로컬 이미지 모델로 만든다. 그 그림이 뜬 화면에서 이 목소리를 재생하면 금지 항목에 해당할 수 있다. 쓰려면 권리자에게 물어야 한다.
6. 青山龍星(13): 판매자가 개인이면 가능하지만, 사업자·법인 명의가 되면 사전 확인이 필요하다.
7. No.7(29 ノーマル / 30 アナウンス / 31 読み聞かせ): 스타일은 낭독·안내에 맞지만 상업·교육 이용 모두 사전 확인 대상이라 시험 단계에서는 제외.

"차분한 낭독에 어울리는가"는 실제로 들어 보지 않았다. 음색 평가는 이 조사에 없다(확인 필요, 시험에서 판단).

## 3. 공식 배포 파일

### 3-1. VOICEVOX ENGINE 0.26.1 (2026-10-31 공개, 최신 안정 릴리스)

| 항목 | 내용 | 출처 |
|---|---|---|
| 파일 이름 | `voicevox_engine-macos-arm64-0.26.1.7z.001` | [S14] |
| 크기 | 1,893,750,133 바이트 (약 1.89GB) | [S14] |
| URL | https://github.com/VOICEVOX/voicevox_engine/releases/download/0.26.1/voicevox_engine-macos-arm64-0.26.1.7z.001 | [S14] |
| 압축 형식 | 7z. 이름은 `.7z.001`이지만 조각은 하나뿐이다. 조각 목록 파일 `voicevox_engine-macos-arm64-0.26.1.7z.txt`(42바이트)에 이 파일 한 줄만 있다 | [S14] |
| 체크섬 | 릴리스 본문에 체크섬 파일은 없다. GitHub 릴리스 API의 `digest` 값: `sha256:4ef177c2fd6dcc39d68a14e2c4b6c568d65dbd6b19f704e734b30166aae272ed` | [S14] |
| 같은 릴리스의 다른 Mac 파일 | `voicevox_engine-macos-arm64-0.26.1.vvpp`(1,986,328,782바이트)는 에디터에 꽂는 플러그인 묶음이라 필요 없다 | [S14] |
| 실행 | 압축을 푼 폴더의 `run` 실행 파일. 기본 주소는 `127.0.0.1:50021`. 옵션: `--host`, `--port`, `--cpu_num_threads`, `--load_all_models`, `--output_log_utf8` | 옵션은 [S15]. `./run`으로 실행한다는 것은 공식 README가 아니라 이슈 보고자의 재현 절차에서 확인(출처 약함) [S16] |
| GPU | Mac 판은 GPU 모드를 지원하지 않는다(CPU 합성) | [S5] |
| 동작 환경 | macOS 14 이상 (에디터 기준 공식 Q&A) | [S5] |
| quarantine | 공식 문서에 안내 없음. 확인 필요. 해석: 브라우저로 받으면 격리 속성이 붙어 첫 실행이 막힐 수 있고, `curl`로 받으면 보통 붙지 않는다. 속성을 지우는 것은 보안 설정을 건드리는 일이라 사용자가 직접 판단해야 한다 | - |
| 7z 풀기 | macOS에는 7z 전용 도구가 기본으로 없다. 기본 `tar`(libarchive)가 7z를 읽는지, `.7z.001` 이름 그대로 풀리는지는 확인 필요. 안 되면 7-Zip 설치가 필요하다(설치 여부는 PM·사용자 결정) | - |
| 메모리 | 공식 수치 없음. macOS arm64에서 `/synthesis` 반복 시 메모리가 계속 늘고 긴 글에서 수 GB가 잡힌다는 이슈가 열려 있다(0.23.0 기준 보고). 한 박~몇 박짜리 106개 합성에는 영향이 작을 것으로 본다(해석, 확인 필요) | [S16] |

### 3-2. 더 가벼운 대안: VOICEVOX CORE 0.17.1 + 필요한 `.vvm`만

엔진(HTTP 서버) 없이 파이썬에서 바로 합성한다. 코어는 MIT, 모델은 3절 위 표의 VVM 약관(앱에 넣어 재배포 가능, 크레딧 필요)이다.

| 받을 것 | 파일 이름 | 크기 | 받는 곳 / sha256 |
|---|---|---|---|
| 다운로더 | `download-osx-arm64` | 4,921,744 B | voicevox_core 릴리스 0.17.1 [S17]. `0ccc1c52…2055e02` |
| Python wheel | `voicevox_core-0.17.1-cp310-abi3-macosx_11_0_arm64.whl` | 1,604,204 B | 같은 릴리스 [S17]. `1c3a1c01…ca26e2ef`. Python 3.10 이상용(abi3) |
| ONNX Runtime | `voicevox_onnxruntime-osx-arm64-1.17.3.tgz` | 5,061,505 B | VOICEVOX/onnxruntime-builder 릴리스 [S18]. 다운로더가 자동으로 받는다. 다운로더가 고르는 버전이 이 파일과 같은지는 확인 필요 |
| Open JTalk 사전 | `open_jtalk_dic_utf_8-1.11.tar.gz` | 확인 필요 | 다운로더가 자동으로 받는다 [S19] |
| 음성 모델 | `0.vvm` (四国めたん, ずんだもん, 春日部つむぎ, 雨晴はう) | 59,308,488 B | voicevox_vvm 릴리스 0.17.1 [S20]. `ecd35374…34bb1318` |
| (목소리를 바꿀 때) | `1.vvm` 冥鳴ひまり 60,571,189 B / `2.vvm` 九州そら 59,308,683 B / `13.vvm` 春歌ナナ 61,686,018 B / `21.vvm` 東北ずん子·きりたん·イタコ 63,195,138 B | - | [S20] |

받는 방법(공식 안내 [S19] [S21]):

```sh
chmod +x download
./download --exclude c-api --models-pattern 0.vvm   # voicevox_core/ 아래에 onnxruntime, dict, models가 생긴다
pip install https://github.com/VOICEVOX/voicevox_core/releases/download/0.17.1/voicevox_core-0.17.1-cp310-abi3-macosx_11_0_arm64.whl
```

- 합쳐서 약 70MB(사전 크기 제외)로, 엔진 1.89GB의 4% 수준이다.
- 파이썬 API에 `create_audio_query_from_kana`, `tts_from_kana`, `create_accent_phrases_from_kana`, `replace_mora_data`, `replace_phoneme_length`가 있다 [S22]. 4절의 방법을 HTTP 없이 그대로 쓸 수 있다.
- 코어의 AudioQuery 필드 이름은 스네이크 케이스(`speed_scale`, `pitch_scale` 등)다 [S21].
- 프로젝트의 이미지 도구가 이미 파이썬 + venv라 같은 방식으로 `tools/`에 둘 수 있다(해석).

## 4. 길이와 읽기 조절

### 4-1. AudioQuery 필드 (엔진 API 스키마 [S23])

| 필드 | 뜻 | 한 박 가나에 쓸 때 |
|---|---|---|
| `speedScale` | 전체 말 빠르기 | 1보다 작게 하면 전체가 느려진다. 박 길이를 직접 고치지 않고 가장 간단히 늘이는 방법 |
| `accent_phrases[].moras[].vowel_length` | 모음 길이(초) | 한 박의 길이를 직접 정한다. 코어 문서 예시에서 보통 박의 모음은 0.08~0.13초다 [S21]. す·し를 길게 하려면 이 값을 키운다 |
| `accent_phrases[].moras[].consonant_length` | 자음 길이(초) | す·し의 마찰음(s, sh)이 또렷하게 들리게 조금 키울 수 있다. 너무 키우면 부자연스럽다(해석) |
| `accent_phrases[].moras[].pitch` | 박의 높이 | 무성화된 박은 높이가 0으로 나온다(확인 필요). 0이면 아래 무성화 항목 참고 |
| `prePhonemeLength` / `postPhonemeLength` | 음성 앞·뒤 무음 시간 | 앞뒤가 잘리지 않게 여유를 둔다. 앱에서 연달아 재생할 때 간격이 여기서 정해진다 |
| `pauseLength` / `pauseLengthScale` | 구두점 무음 시간(절대값, null이면 무시) / 배율(기본 1) | 한 박·한 단어에는 영향 없음 |
| `intonationScale` | 전체 억양 | 한 박에서는 차이가 작다. 단어에서 억양이 과하면 낮춘다 |
| `pitchScale`, `volumeScale` | 전체 높이, 음량 | 106개 파일의 음량을 맞추려면 값을 고정한다 |
| `outputSamplingRate`, `outputStereo` | 출력 샘플링 레이트, 스테레오 여부 | 기본값은 `/audio_query` 응답에서 확인(확인 필요). 번들 크기를 생각하면 모노 유지 |
| `kana` | 읽기 전용. 엔진이 판단한 읽기(AquesTalk 풍). 합성 때는 무시된다 | 읽기가 맞는지 검수용으로 쓴다 |

주의점:
- 공식 Q&A에 "、로 끊은 짧은 문절이 읽히지 않을 때가 있다"는 항목이 있고, 대책으로 앞뒤 무음을 늘리라고 한다. 인용: 「前後の無音の長さを長くすると改善することがあります」 [S5]. 한 박짜리 합성은 이 경우에 가까우므로 46자 전부를 귀로 검수해야 한다.
- `/mora_data`, `/mora_length`는 액센트 구에서 길이·높이를 다시 계산해 돌려준다 [S23]. 길이를 손으로 고친 뒤에 호출하면 고친 값이 덮인다(해석). 순서는 "읽기 확정 → 길이 수정 → `/synthesis`"로 한다.
- `speedScale`이 앞뒤 무음 길이에도 영향을 주는지는 확인 필요.
- 값의 허용 범위는 스키마에 없다(`pauseLength`만 0 이상). 에디터 UI의 범위는 확인 필요.
- 무성화: 표준 일본어에서 す·し는 무성 자음 사이나 어말에서 모음이 빠지기 쉽다. AquesTalk 풍 표기에서는 가나 앞에 `_`를 붙여야 무성화되므로 [S15], `is_kana=true`로 `_` 없이 넣으면 유성으로 나올 것으로 본다(해석, 확인 필요). 일반 텍스트(`/audio_query`)로 넣으면 엔진이 알아서 무성화할 수 있으니, 응답의 `kana`에 `_`가 붙었는지 본다.

### 4-2. 가나를 그대로 읽히기

| 방법 | 내용 | 출처 |
|---|---|---|
| `POST /accent_phrases?speaker={id}&is_kana=true` | 텍스트를 AquesTalk 풍 표기로 해석한다. 규칙: 전부 가타카나, 액센트 구는 `/` 또는 `、`로 나눔(`、`만 무음 삽입), 가나 앞 `_`는 무성화, 액센트 위치는 `'`로 지정하며 **액센트 구마다 하나가 필수**, 구 끝 `？`(전각)는 의문문 | [S15] [S23] |
| 조합 순서 | `/audio_query`로 기본 쿼리를 받고, 그 `accent_phrases`를 `is_kana=true`로 얻은 것으로 바꾼 뒤 `/synthesis`에 보낸다 | [S15] |
| 코어 | `create_audio_query_from_kana(kana, style_id)` 또는 `tts_from_kana` | [S22] |
| 사용자 사전 | `POST /user_dict_word`(surface, pronunciation, accent_type)로 읽기와 액센트를 등록 | [S23] |

は·へ·を:
- AquesTalk 풍 표기는 철자가 아니라 발음을 적는 표기다. 공식 예시에서 조사 は가 `ワ`로 적힌다(`…ラ'アニングワ/…`) [S15]. 따라서 `ハ'`, `ヘ'`로 넣으면 조사 읽기(わ, え)가 아니라 は(ha), へ(he)로 읽힌다(해석: 표기 규칙에서 따라 나오는 결론이고, 실제 출력은 시험에서 확인).
- を는 표준 발음이 お와 같다. `ヲ'`가 표기로 받아들여지는지는 확인 필요. 안 되면 `オ'`로 만든 소리를 を에 쓴다.
- 일반 텍스트로 "は" 한 글자를 넣었을 때 わ로 읽히는지는 확인하지 않았다. `is_kana=true`를 쓰면 이 문제를 피한다.

단어 60개:
- `is_kana=true`는 단어마다 액센트 위치(`'`)가 필요하다. 지금 단어 목록에 액센트 정보가 없으면, 일반 텍스트로 `/audio_query`를 부르고 응답의 `kana`로 읽기와 액센트를 검수한 뒤 틀린 것만 AquesTalk 풍 표기로 고치는 순서가 손이 덜 간다(해석).

## 5. speaker(style) id

- `GET /speakers`가 캐릭터 목록을 돌려준다 [S23]. 캐릭터마다 스타일 목록이 있고, API의 `speaker` 파라미터에는 스타일 id를 넣는다. 스타일을 미리 올려 두려면 `POST /initialize_speaker?speaker={id}`.
- 코어에서는 `VoiceModelFile.open(...).metas`로 같은 정보를 본다 [S21].
- 아래 id는 voicevox_vvm README의 대응표에서 확인했다 [S4]. 엔진의 `/speakers` 출력과 같은지는 실행해서 대조해야 한다(확인 필요, 다를 가능성은 낮음).

| 목소리 | 스타일 | 스타일 id | VVM 파일 |
|---|---|---|---|
| 四国めたん | ノーマル / あまあま / ツンツン / セクシー | 2 / 0 / 6 / 4 | 0.vvm |
| 四国めたん | ささやき / ヒソヒソ | 36 / 37 | 5.vvm |
| 春日部つむぎ | ノーマル | 8 | 0.vvm |
| 冥鳴ひまり | ノーマル | 14 | 1.vvm |
| 九州そら | ノーマル / あまあま / ツンツン / セクシー | 16 / 15 / 18 / 17 | 2.vvm |
| No.7 | ノーマル / アナウンス / 読み聞かせ | 29 / 30 / 31 | 6.vvm |
| WhiteCUL | ノーマル / たのしい / かなしい / びえーん | 23 / 24 / 25 / 26 | 8.vvm |
| ナースロボ＿タイプＴ | ノーマル / 楽々 / 恐怖 / 内緒話 | 47 / 48 / 49 / 50 | 11.vvm |
| 春歌ナナ | ノーマル | 54 | 13.vvm |
| 青山龍星 | ノーマル / しっとり | 13 / 84 | 15.vvm |
| 東北ずん子 / 東北きりたん / 東北イタコ | ノーマル | 107 / 108 / 109 | 21.vvm |

## 해석과 프로젝트 영향

- 영향: 상업 앱 번들에 생성 음성을 넣는 것은, 약관이 명확한 목소리를 고르고 크레딧을 적는 조건으로 가능하다고 본다. 四国めたん이면 앱 안 정보(크레딧) 화면에 `VOICEVOX:四国めたん`을 적는다. 앱에 그런 화면이 아직 없으면 화면이 하나 필요하다(designer·PLAN.md 사안). App Store 설명란에도 적으면 "조금 찾으면 알 수 있는 곳" 조건을 더 확실히 채운다.
- 영향: KanjiVG(CC BY-SA 3.0) 출처 표기와 같은 화면에 모을 수 있다.
- 영향: 판매자 명의가 개인인지 사업자·법인인지에 따라 青山龍星 같은 목소리는 조건이 달라진다. 四国めたん, 冥鳴ひまり는 영향이 없다.
- 영향: 그림을 이미지 모델로 만드는 프로젝트라, "AI 생성 그림에 목소리 금지" 조항이 있는 목소리(ナースロボ＿タイプＴ)는 피한다. 다른 목소리로 바꿀 때도 이 조항이 있는지 먼저 본다.
- 영향: 약관은 권리자가 예고 없이 바꿀 수 있다(春歌ナナ 약관에 명시, ナースロボ는 1주일 전에 개정). 음성을 만든 날의 약관 페이지를 저장해 두고, 공개 직전에 다시 확인하는 절차가 필요하다.
- 영향: 시험에는 엔진(1.89GB)보다 코어 + `0.vvm`(약 70MB)이 가볍고 파이썬 도구 체계와 맞는다. 다만 어느 쪽이든 내려받기와 설치가 필요하므로 사용자 승인 뒤에 진행한다. 엔진을 쓰면 7z 푸는 도구 문제가 추가된다.
- 영향: 한 박 가나는 짧은 문절이 읽히지 않는 알려진 현상에 가깝다. 46자 전수 청취 검수를 시험 기준에 넣어야 한다.
- 해석: 엔진 약관·LGPL 검토는 앱에 엔진을 넣지 않는 한 필요 없다. 나중에 앱 안에서 실시간 합성을 하려면(코어 MIT + VVM 약관) 별도 검토가 된다.

## 확인하지 못한 것

- 春日部つむぎ, WhiteCUL, 青山龍星(VirVox)의 권리자 약관 원문. 각각 스크립트 렌더링, `/lander` 리다이렉트, 사이트 점검으로 읽지 못했다. 브라우저로 직접 열어 확인해야 한다.
- 冥鳴ひまり, 春歌ナナ, No.7 약관은 페이지 요약 도구를 거쳐 읽었다. 채택 전에 원문을 직접 대조해야 한다.
- 생성 음성 파일을 앱 번들에 넣는 것이 "음성 소재 배포"로 해석될 여지. 어느 약관에도 직접 다룬 문장이 없다.
- macOS에서 엔진 `run`의 quarantine·Gatekeeper 동작, 7z 푸는 방법, 메모리 사용량.
- `ヲ'` 입력 가능 여부, 한 글자 は의 기본 읽기, `speedScale`과 앞뒤 무음의 관계, 각 필드의 허용 범위와 기본값.
- 엔진 `/speakers`의 id가 VVM 대응표와 같은지.
- 후보 목소리의 실제 음색(들어 보지 않음).
- Open JTalk 사전 파일 크기, 다운로더가 받는 ONNX Runtime 버전.

## 출처

- [S1] VOICEVOX ソフトウェア利用規約: https://voicevox.hiroshiba.jp/term/
- [S2] voicevox_engine LICENSE: https://github.com/VOICEVOX/voicevox_engine/blob/master/LICENSE
- [S3] voicevox_core README·LICENSE: https://github.com/VOICEVOX/voicevox_core/blob/main/README.md , https://github.com/VOICEVOX/voicevox_core/blob/main/LICENSE
- [S4] voicevox_vvm README(음성 모델 약관, 목소리별 요약, 스타일 id 대응표): https://github.com/VOICEVOX/voicevox_vvm/blob/main/README.md . 같은 요약의 원본: https://github.com/VOICEVOX/voicevox_resource/tree/main/character_info (각 폴더의 policy.md)
- [S5] VOICEVOX Q&A: https://voicevox.hiroshiba.jp/qa/
- [S6] SSS LLC 音源利用ガイドライン(四国めたん 등): https://zunko.jp/con_ongen_kiyaku.html
- [S7] 冥鳴ひまり 利用規約: https://www.meimeihimari.com/terms-of-use (VOICEVOX가 적어 둔 옛 주소 https://meimeihimari.wixsite.com/himari/terms-of-use 에서 넘어감)
- [S8] 春歌ナナ ガイドライン: https://nanahira.jp/haruka_nana/guideline.html
- [S9] 倉成町私立病院 規約(ナースロボ＿タイプＴ): https://www.krnr.top/rules
- [S10] 春日部つむぎ 規約(본문 읽지 못함): https://tsumugi-official.studio.site/rule
- [S11] WhiteCUL ガイドライン(본문 읽지 못함): https://www.whitecul.com/guideline
- [S12] VirVox Project VOICEVOXの利用規約(점검 중, 읽지 못함): https://www.virvoxproject.com/voicevoxの利用規約
- [S13] No.7 公式サイト 利用規約: https://voiceseven.com/#j0200
- [S14] voicevox_engine 릴리스 0.26.1(파일 이름·크기·digest는 GitHub 릴리스 API로 확인): https://github.com/VOICEVOX/voicevox_engine/releases/tag/0.26.1
- [S15] voicevox_engine README(AquesTalk 풍 표기, 실행 옵션, 샘플 코드): https://github.com/VOICEVOX/voicevox_engine/blob/master/README.md
- [S16] voicevox_engine 이슈 #1691(메모리 증가 보고, `./run` 실행 예. 사용자 보고라 출처 약함): https://github.com/VOICEVOX/voicevox_engine/issues/1691
- [S17] voicevox_core 릴리스 0.17.1(2026-10-22): https://github.com/VOICEVOX/voicevox_core/releases/tag/0.17.1
- [S18] VOICEVOX onnxruntime-builder 릴리스: https://github.com/VOICEVOX/onnxruntime-builder/releases
- [S19] VOICEVOX CORE Downloader 안내: https://github.com/VOICEVOX/voicevox_core/blob/main/docs/guide/user/downloader.md
- [S20] voicevox_vvm 릴리스 0.17.1(2026-10-31): https://github.com/VOICEVOX/voicevox_vvm/releases/tag/0.17.1
- [S21] VOICEVOX コア ユーザーガイド: https://github.com/VOICEVOX/voicevox_core/blob/main/docs/guide/user/usage.md
- [S22] voicevox_core Python API 문서: https://voicevox.github.io/voicevox_core/apis/python_api/autoapi/voicevox_core/blocking/index.html
- [S23] VOICEVOX ENGINE API 문서(OpenAPI 스키마): https://voicevox.github.io/voicevox_engine/api/
