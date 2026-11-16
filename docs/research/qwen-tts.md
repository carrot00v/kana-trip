# Qwen TTS 로컬 실행 조사 (가나 한 글자 소리용)

조사한 날짜: 2026-11-17 (모든 출처를 이 날 확인했다)

## 조사 질문

1. 로컬에서 돌릴 수 있는 Qwen TTS 공개 가중치와 저장소 이름, 크기, 라이선스, 일본어 지원, 기능.
2. 합성한 음성 파일을 상업 앱에 번들해도 되는가. 크레딧 의무와 프리셋 화자 조건.
3. Apple Silicon(MPS·MLX)에서 도는가. 설치·실행 방법과 24GB에서의 추천 모델.
4. 한 모라처럼 아주 짧은 입력의 알려진 문제와 우회법.
5. 일본어 여성 프리셋 화자. 春日部つむぎ 음성을 참조로 복제해도 되는가.

## 결론 (맨 위에)

아무것도 내려받거나 실행하지 않았다. 소리 품질은 확인하지 않았다.

- **추천 모델: `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16`** (4.52GB, Apache 2.0). 일본어가 모어인 여성 프리셋 화자 `Ono_Anna`가 들어 있고, `instruct`로 말투를 지시할 수 있다. MLX 변환본이라 Apple Silicon에서 바로 돈다. 24GB에서 무리가 없다(가중치 4.5GB, 해석).
- 두 번째 후보: `mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16` (4.52GB). 글로 묘사한 목소리를 새로 만든다. 기리에 맞는 목소리를 따로 만들고 싶을 때 쓴다. 호출마다 목소리가 조금씩 달라진다는 보고가 있어 58자를 같은 목소리로 맞추려면 한 번 만든 소리를 Base 모델의 참조로 고정하는 절차가 필요하다 [Q7].
- **라이선스 결론: 번들 가능.** 코드와 가중치 모두 Apache 2.0이고, 모델 카드와 저장소에 생성 음성에 대한 별도 제한·크레딧 의무 문장이 없다. 다만 프리셋 화자 목소리의 권리를 직접 다룬 문장도 없다(확인 못 한 것 참고).
- **つむぎ 복제: 하지 않는다.** 春日部つむぎ 약관이 상업 이용을 허락하는 대상은 "VOICEVOX로 합성한 음성"뿐이고, つむぎ 음성으로 학습하는 것을 다룬 유일한 약관(MMVC)은 상업 이용을 금지한다.
- 짧은 입력: 한 모라 입력에 대한 직접 보고는 찾지 못했다. 관련 보고(첫 음 왜곡, 일본어 끝 단어 잘림, 지시문 때문에 없는 말이 붙음)가 있어 **문장 안에 넣어 합성한 뒤 잘라 내는 방식**을 먼저 시험하기를 권한다(4절).

### 설치와 실행 (developer용)

Python 3.10 이상이 필요하다(mlx-audio 0.6.5 기준) [Q5]. 이 Mac의 기본 `python3`는 3.15라 휠이 없을 수 있으니 3.12 가상환경을 권한다(해석. Qwen 공식도 3.12를 권한다 [Q1]).

```bash
python3.12 -m venv .venv-tts
.venv-tts/bin/pip install -U mlx-audio soundfile
```

모델은 첫 실행 때 `~/.cache/huggingface/hub/`에 받아진다(4.52GB).

```bash
# CLI (README 예제의 화자·언어만 바꾼 것. --voice Ono_Anna 대소문자 처리는 미확인)
.venv-tts/bin/mlx_audio.tts.generate \
  --model mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16 \
  --text 'あ、か、さ。' --voice Ono_Anna --lang_code Japanese --output_path ./out
```

```python
# Python (mlx-audio의 Qwen3-TTS README 형식 [Q6])
from mlx_audio.tts.utils import load_model
import numpy as np, soundfile as sf

model = load_model("mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16")
results = list(model.generate_custom_voice(
    text="あ。",
    speaker="Ono_Anna",          # 설정 파일의 키는 소문자 ono_anna다 [Q4]
    language="Japanese",
    instruct="ゆっくり、はっきり、一文字だけ読む。",  # 선택. 없이도 시험한다
))
sf.write("a.wav", np.array(results[0].audio), 24000)  # 출력은 24kHz로 알려져 있다 [Q9]
```

MLX가 안 맞으면 공식 패키지로 MPS에서 돌릴 수 있다(공식 문서에는 Mac 안내가 없고 사용자 보고다) [Q7][Q10].

```bash
pip install -U qwen-tts soundfile     # qwen-tts 0.1.1, Python >=3.9, Apache-2.0 [Q5]
brew install sox                       # 없으면 경고가 난다 [Q10]
```

```python
import torch, soundfile as sf
from qwen_tts import Qwen3TTSModel
model = Qwen3TTSModel.from_pretrained(
    "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice", device_map="mps", dtype=torch.bfloat16)
wavs, sr = model.generate_custom_voice(text="あ。", language="Japanese", speaker="Ono_Anna")
sf.write("a.wav", wavs[0], sr)
```

- `flash-attn`은 Mac에서 못 쓴다. 설치 안 됐다는 경고는 무시해도 된다는 보고다 [Q7]. `attn_implementation="flash_attention_2"`는 넣지 않는다.
- dtype 보고가 엇갈린다. M3 Ultra·M4 Pro에서 Base가 `mps` + `bfloat16`으로 돈다는 보고 [Q10], M3에서 Base는 `float16`이면 `probability tensor contains either inf, nan` 오류가 나서 `float32`가 필요했고 VoiceDesign은 `float16`으로 됐다는 보고 [Q7]. 오류가 나면 `float32`로 바꾼다.
- `device_map="cpu"`는 20분 넘게 끝나지 않았다는 보고가 있다 [Q10].

## 1. 공개 가중치

Hugging Face의 `Qwen` 계정에서 이름에 TTS가 들어간 저장소는 아래 6개뿐이다(API 목록으로 확인) [Q3]. ModelScope에도 같은 이름(`Qwen/...`)으로 있다 [Q2]. 2026-01-22에 공개됐다 [Q2].

| 저장소 | 크기(저장소 전체) | 라이선스 표기 | 기능 | 지시(instruct) |
|---|---|---|---|---|
| `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice` | 4.52GB | apache-2.0 | 프리셋 화자 9명 | 됨 |
| `Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign` | 4.52GB | apache-2.0 | 글로 묘사한 목소리 만들기 | 됨 |
| `Qwen/Qwen3-TTS-12Hz-1.7B-Base` | 4.54GB | apache-2.0 | 3초 참조 음성 복제, 미세 조정용 | 안 됨 |
| `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice` | 2.50GB | apache-2.0 | 프리셋 화자 9명 | 안 됨 |
| `Qwen/Qwen3-TTS-12Hz-0.6B-Base` | 2.52GB | apache-2.0 | 3초 참조 음성 복제 | 안 됨 |
| `Qwen/Qwen3-TTS-Tokenizer-12Hz` | 0.68GB | apache-2.0 | 음성 코덱(위 모델들에 이미 들어 있다) | - |

- 크기는 `model.safetensors`(1.7B는 3.83GB, 0.6B는 1.81GB)와 `speech_tokenizer/model.safetensors`(0.68GB)의 합이다 [Q3].
- 지원 언어 10개: 중국어, 영어, **일본어**, 한국어, 독일어, 프랑스어, 러시아어, 포르투갈어, 스페인어, 이탈리아어 [Q1].
- 25Hz 모델은 평가표에만 나오고 공개 목록에는 없다 [Q2].
- 생성 기본값: `temperature 0.9`, `top_k 50`, `repetition_penalty 1.05`, 샘플링 켜짐 [Q4]. 같은 입력도 실행마다 결과가 다르다(해석).

MLX 변환본(`mlx-community`, 모두 apache-2.0 표기) [Q3]:

| 저장소 | 크기 |
|---|---|
| `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16` | 4.52GB |
| `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit` | 3.08GB |
| `mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16` | 4.52GB |
| `mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16` | 4.54GB |
| `mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-bf16` | 2.50GB |

같은 이름에 `-4bit`, `-5bit`, `-6bit`, `-8bit`가 붙은 양자화본이 다섯 모델 모두에 있다. 24GB에서는 양자화가 필요 없으므로 bf16을 쓴다(해석).

Qwen의 다른 음성 출력 모델은 이번 용도에 맞지 않는다.

| 모델 | 크기 | 라이선스 표기 | 일본어 음성 출력 | 화자 | 판단 |
|---|---|---|---|---|---|
| `Qwen/Qwen2.5-Omni-7B` | 22.4GB | `license: other`, `license_name: apache-2.0` | 모델 카드에 적혀 있지 않다 | Chelsie(여), Ethan(남) | BF16 최소 31GB로 적혀 있어 24GB에 무리 [Q11] |
| `Qwen/Qwen3-Omni-30B-A3B-Instruct` | 70.5GB | 같은 표기 | 지원한다고 적혀 있다 | Ethan, Chelsie, Aiden | 최소 약 79GB. 불가 [Q12] |
| Qwen-TTS, Qwen3-TTS-Flash 등 | - | - | - | - | 공개 가중치를 찾지 못했다. Alibaba Cloud API 전용으로 알고 있으나 이번에 원문으로 확인하지 않았다 |

## 2. 상업 앱 번들

| 항목 | 확인한 내용 | 출처 |
|---|---|---|
| 코드 라이선스 | GitHub `QwenLM/Qwen3-TTS` 저장소가 Apache-2.0 | [Q2] |
| 가중치 라이선스 | 모델 카드 메타데이터가 `license: apache-2.0`. 6개 저장소 모두 같다. HF 저장소에 `LICENSE` 파일은 따로 없었다(`raw/main/LICENSE`가 404) | [Q1][Q3] |
| 생성 음성에 대한 제한 | 모델 카드와 GitHub README에 면책·이용 제한·음성 복제 제한 문장이 없다 | [Q1][Q2] |
| 크레딧 의무 | 생성 음성에 표기를 요구하는 문장이 없다 | [Q1][Q2] |
| 프리셋 화자 조건 | 화자별 조건 문장이 없다. 화자의 실제 음원 제공자나 권리에 대한 설명도 없다 | [Q1] |
| mlx-audio | MIT | [Q5] |
| 공식 답변 | 생성 음성의 상업 이용 조건을 묻는 이슈(#388, 2026-10-31)가 열려 있고 답이 달리지 않았다 | [Q13] |

해석:
- Apache 2.0은 소프트웨어(가중치 포함)의 사용·수정·재배포 조건이고, 상업 이용을 허락한다. NOTICE·라이선스 사본 의무는 소프트웨어 자체를 다시 배포할 때 걸린다. 앱에는 m4a만 들어가고 모델은 들어가지 않으므로 표기 의무는 생기지 않는다고 본다.
- 의무는 아니지만 크레딧 화면에 `Qwen3-TTS (Alibaba Cloud, Apache 2.0)` 한 줄을 적어 두면 출처가 분명해진다. 넣을지는 PM·사용자 판단이다.
- VOICEVOX 약관의 "자작 발언 금지" 같은 조항은 Qwen 쪽에 없다.

## 3. Apple Silicon

| 경로 | 상태 | 근거 |
|---|---|---|
| MLX (`mlx-audio`) | 지원 모델 목록에 Qwen3-TTS가 있다. `pip install -U mlx-audio`, Python 3.10+, Apple Silicon 전용. 0.6.5가 최신 | [Q5][Q6] |
| PyTorch MPS (`qwen-tts`) | 공식 README에는 Mac 안내가 없다. 사용자들이 `device_map="mps"`로 돌렸다고 보고한다. 공식 데모도 `--device mps --no-flash-attn`으로 실행한 로그가 있다 | [Q7][Q10][Q14] |
| 공식 지원 | macOS·MLX 지원을 넣자는 PR·이슈(#124, #345)가 열린 채다 | [Q15] |

- mlx-audio의 Qwen3-TTS 메서드: CustomVoice는 `generate_custom_voice(text, speaker, language, instruct)`, VoiceDesign은 `generate_voice_design(...)`, Base는 `generate(text, ref_audio, ref_text)` [Q6].
- mlx-audio README의 화자 목록에는 중국어·영어 화자 7명만 적혀 있다. 그러나 MLX 변환본의 `config.json`에는 `ono_anna`와 `sohee`가 들어 있다 [Q4]. 실제로 호출되는지는 developer가 확인한다.
- 메모리·속도의 실측값은 찾지 못했다. 24GB에서 넉넉하다는 것은 가중치 크기(4.5GB)에서 나온 해석이다.

## 4. 짧은 입력의 문제와 우회법

"가나 한 글자"를 넣은 보고는 찾지 못했다(GitHub 이슈 검색: short text, single word, hallucination, Japanese). 아래는 관련 보고와 거기서 끌어낸 우회법이다.

| 보고 | 내용 | 우회법 | 출처 |
|---|---|---|---|
| 첫 음 왜곡 | 짧은 구절의 첫 글자가 다른 음절로 들린다(예: 중국어 「一」). 보고자는 코덱 디코더에 앞 문맥이 없어서라고 보고 무음 코드를 앞에 붙였다가 잘라 내는 패치를 올렸다. 댓글 하나는 MP3 인코딩 탓이었다고 반박한다. 원인 미확정 | 목표 글자를 맨 앞에 두지 않는다. 앞에 다른 말을 두고 잘라 낸다. WAV로 받는다 | [Q16] |
| 일본어·한국어 끝 잘림 | 마지막 단어가 덜 나온 채 끝난다. 해결되지 않았다는 댓글이 이어진다 | 목표 글자를 맨 끝에 두지 않는다. 뒤에 말을 더 붙인다 | [Q17] |
| 없는 말·웃음이 붙음 | `instruct`("very happy")와 표현이 풍부한 화자에서 웃음이나 "OK" 같은 말이 붙었다. 개발자 답: 지시문을 고치거나 다른 화자를 쓰거나, 원하는 말투의 음성을 Base로 복제하라 | 지시문 없이 먼저 시험한다. 지시문은 중립적으로 쓴다 | [Q14] |
| 짧은 발화 불안정 | 미세 조정한 1.7B에서 짧은 발화와 첫 1~2초의 음색이 흔들린다(짧은 발화의 약 15%). 미세 조정 모델에 대한 보고다 | 여러 번 생성해 고른다 | [Q18] |
| 40ms 메아리 | 12Hz 모델 출력 전체에 약 40ms 간격의 약한 메아리가 측정된다는 보고(2026-10-22, 열림) | 우회법 없음. 귀로 확인한다 | [Q19] |
| 말 속도 흔들림 | 긴 글에서 속도가 변한다. `non_streaming_mode=True`를 기본으로 하자는 PR이 있다 | 해당 적음 | [Q15] |

시험 순서 제안(해석, 시험 필요):

1. 문장 안에서 잘라 내기: `あ、あ、あ。`처럼 같은 글자를 쉼표로 세 번 넣고 가운데 것을 자른다. 첫 음 왜곡과 끝 잘림을 둘 다 피한다. 코덱이 12.5Hz(한 프레임 80ms) [Q6]이므로 쉼표 사이 무음이 충분히 생기는지 본다.
2. 단독 입력: `あ。`와 `あ`를 비교한다.
3. 지시문: `ゆっくり、はっきり、一文字だけ。` 같은 중립 지시를 붙였을 때와 뺐을 때를 비교한다(지시는 1.7B CustomVoice·VoiceDesign만 받는다 [Q1]).
4. 샘플링이 기본이라 글자마다 3~5번 만들어 고른다. `temperature`를 낮추는 것은 공식 패키지에서는 `generate` 인자로 넘길 수 있다 [Q2]. mlx-audio에서 되는지는 확인하지 못했다.
5. は·へ·を는 조사로 읽힐 수 있다(ワ, エ). VOICEVOX 때와 같은 주의가 필요하다(해석).

## 5. 일본어 화자와 つむぎ 복제

프리셋 화자 9명 [Q1]:

| 화자 | 설명(요약) | 모어 |
|---|---|---|
| **Ono_Anna** | 장난기 있고 가벼운 여성 목소리 | **일본어** |
| Vivian | 밝고 또렷한 젊은 여성 | 중국어 |
| Serena | 따뜻하고 부드러운 젊은 여성 | 중국어 |
| Sohee | 따뜻한 여성 | 한국어 |
| Uncle_Fu, Dylan(베이징), Eric(쓰촨) | 남성 | 중국어 |
| Ryan, Aiden | 남성 | 영어 |

일본어가 모어인 화자는 Ono_Anna 하나다. 모든 화자가 10개 언어를 말할 수 있지만 모어에서 품질이 가장 좋다고 모델 카드가 안내한다 [Q1].

**つむぎ 음성을 참조로 복제하는 것: 하지 않는다(약관상 근거가 없고, 가장 가까운 조항은 금지 쪽이다).**

- VOICEVOX「春日部つむぎ」利用規約 1·2항은 "VOICEVOX로 합성한 春日部つむぎ의 음성"에만 상업 이용을 허락한다. Qwen으로 복제해 만든 소리는 여기에 들지 않는다 [Q20].
- つむぎ 음성으로 학습하는 것을 다룬 약관은 MMVC 약관 하나이고, 2항이 「商用利用できません」이라고 한다 [Q20].
- VOICEVOX 약관과 FAQ에 음성 복제·AI 학습을 직접 금지하거나 허락하는 문장은 없다(FAQ 화면에서 学習·AI·クローン으로 찾았다) [Q20][Q21]. 금지 6항의 "제3자의 권리 침해", "운영이 부적절하다고 판단하는 행위"가 걸릴 수 있다(해석).
- 영향: Qwen으로 가면 글자 소리와 단어 소리(つむぎ)의 목소리가 달라진다. 목소리를 맞추려면 단어 60개도 Qwen으로 다시 만드는 선택지가 생긴다. PLAN.md 결정 사안이므로 PM이 사용자에게 확인한다.

## 확인하지 못한 것

- 소리 품질 전부. 한 모라 입력에서 실제로 어떤 소리가 나는지.
- 프리셋 화자(Ono_Anna 등)의 음원 제공자와 권리 관계, 화자별 이용 조건. 공개 문서에 문장이 없다. 이슈 #388에 공식 답이 없다.
- Apache 2.0 라이선스 전문이 HF 가중치 저장소에 파일로 있는지. 메타데이터 표기만 확인했다.
- M4 Pro 24GB에서의 메모리 사용량과 속도 실측값.
- mlx-audio에서 `Ono_Anna`가 호출되는지, 화자 이름 대소문자, CLI에 `instruct` 옵션이 있는지, `temperature`를 바꿀 수 있는지.
- Qwen-TTS·Qwen3-TTS-Flash가 API 전용이라는 점(원문 미확인). Qwen2.5-Omni의 일본어 음성 출력 여부.
- arXiv 기술 보고서(2601.15621)는 열어 보지 않았다.
- 春日部つむぎ 권리자에게 복제 가부를 문의하지 않았다(약관 해석 문의에는 답하지 않는다고 밝혀 둔 곳이다. voicevox-terms.md E절).

## 출처

- [Q1] Hugging Face 모델 카드 Qwen3-TTS-12Hz-1.7B-CustomVoice: https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice
- [Q2] GitHub QwenLM/Qwen3-TTS README: https://github.com/QwenLM/Qwen3-TTS
- [Q3] Hugging Face API(저장소 목록, 파일 크기, 라이선스 표기): https://huggingface.co/api/models?author=Qwen&search=TTS , https://huggingface.co/api/models?author=mlx-community&search=Qwen3-TTS , `https://huggingface.co/api/models/{저장소}?blobs=true`
- [Q4] MLX 변환본 설정과 생성 기본값: https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16/raw/main/config.json , https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice/raw/main/generation_config.json
- [Q5] mlx-audio(MIT, Python 3.10+): https://github.com/Blaizzy/mlx-audio , https://pypi.org/project/mlx-audio/ . qwen-tts: https://pypi.org/project/qwen-tts/
- [Q6] mlx-audio의 Qwen3-TTS README: https://github.com/Blaizzy/mlx-audio/blob/main/mlx_audio/tts/models/qwen3_tts/README.md
- [Q7] 사용자 글(M3 MacBook Air, MPS, 일본어). 출처가 개인 글 하나라 약하다: https://dev.to/tumf/qwen3-tts-surprised-by-the-quality-of-japanese-on-apple-silicon-m3-creating-rights-free-voices-k1d
- [Q9] 출력 24kHz: 이슈 #219의 코드(`sr=24000`)에서 읽었다. 약한 근거: https://github.com/QwenLM/Qwen3-TTS/issues/219
- [Q10] 이슈 #69 (M4 Pro, cpu에서 멈춤, mps+bfloat16으로 해결): https://github.com/QwenLM/Qwen3-TTS/issues/69
- [Q11] Qwen2.5-Omni-7B 모델 카드: https://huggingface.co/Qwen/Qwen2.5-Omni-7B
- [Q12] Qwen3-Omni-30B-A3B-Instruct 모델 카드: https://huggingface.co/Qwen/Qwen3-Omni-30B-A3B-Instruct
- [Q13] 이슈 #388 (라이선스 확인 요청, 답 없음): https://github.com/QwenLM/Qwen3-TTS/issues/388
- [Q14] 이슈 #16 (없는 웃음·말, 개발자 답변): https://github.com/QwenLM/Qwen3-TTS/issues/16
- [Q15] 이슈·PR #124, #345, #362: https://github.com/QwenLM/Qwen3-TTS/issues/124 , https://github.com/QwenLM/Qwen3-TTS/issues/345 , https://github.com/QwenLM/Qwen3-TTS/pull/362
- [Q16] 이슈 #219 (첫 음 왜곡): https://github.com/QwenLM/Qwen3-TTS/issues/219
- [Q17] 이슈 #55 (일본어·한국어 끝 잘림): https://github.com/QwenLM/Qwen3-TTS/issues/55
- [Q18] 이슈 #343 (짧은 발화 불안정): https://github.com/QwenLM/Qwen3-TTS/issues/343
- [Q19] 이슈 #386 (40ms 메아리): https://github.com/QwenLM/Qwen3-TTS/issues/386
- [Q20] 春日部つむぎ公式サイト RULE (브라우저로 렌더링해 VOICEVOX·MMVC 약관 원문 확인): https://tsumugi-official.studio.site/rule
- [Q21] 春日部つむぎ公式サイト よくある質問: https://tsumugi-official.studio.site/rule2
- 앞선 조사: [kana-voice-alternatives.md](kana-voice-alternatives.md), [voicevox-terms.md](voicevox-terms.md)
