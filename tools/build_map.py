#!/usr/bin/env python3
"""지도 정의 데이터 map.json을 만든다 (docs/design/home-map.md 7.1).

  python3 tools/build_map.py           # KanaTrip/Resources/map.json을 다시 쓴다
  python3 tools/build_map.py --check   # 지금 파일과 다르면 1로 끝난다(쓰지 않음)

입력
- KanaTrip/Resources/hiragana_scenes.json: 장면 순서, 단계 id, 단어의 그림 이름(`art`).
- tools/map_layout.json: 재구성안 A(R2.3)의 수치(metrics, motion, 구간 높이, 칸 y), 스티커 자리, `stickerOverride`(장면 id → 그림 목록).
- 단어 그림 원본 목록: build/word-art/word-{art}.png(place_word_art.py 결과) 또는 그와 같은 앱 에셋
  KanaTrip/Assets.xcassets/WordArt-{art}.imageset. 둘 중 하나라도 있으면 "그림 있음"으로 본다.

출력 (iOS·안드로이드 공용)
- 구간(`sections`)은 아래(출발)에서 위(지역 끝) 순서. y는 구간 바닥에서 위로 잰 pt.
- 칸 상태, 문구는 넣지 않는다. 앱이 진도와 장면 데이터에서 계산한다.

표준 라이브러리만 쓴다(Pillow 필요 없음). 같은 입력이면 결과가 같다.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCENES = ROOT / "KanaTrip" / "Resources" / "hiragana_scenes.json"
LAYOUT = ROOT / "tools" / "map_layout.json"
OUT = ROOT / "KanaTrip" / "Resources" / "map.json"
NEUTRAL_ART = ROOT / "build" / "word-art"
ASSETS = ROOT / "KanaTrip" / "Assets.xcassets"


def has_art(name: str) -> bool:
    if (NEUTRAL_ART / f"word-{name}.png").exists():
        return True
    return (ASSETS / f"WordArt-{name}.imageset" / f"WordArt-{name}.png").exists()


def pick_sticker(step: dict) -> str | None:
    """단계의 단어 가운데 데이터 순서로 처음 나오는, 그림이 있는 단어의 `art` (2.3)."""
    for word in step["words"]:
        art = word.get("art")
        if art and has_art(art):
            return art
    return None


def scene_stickers(scene: dict, override: dict) -> list[str]:
    """장면 띠에 붙일 그림 목록(A, B 순). `stickerOverride`에 장면이 있으면 그 목록(빈 목록이면 없음)."""
    if scene["id"] in override:
        return list(override[scene["id"]])
    return [art for art in (pick_sticker(step) for step in scene["steps"][:2]) if art]


def num(v):
    """정수로 떨어지는 값은 정수로 적는다(파일을 읽기 쉽게)."""
    return int(v) if float(v).is_integer() else round(v, 4)


def clean(obj):
    if isinstance(obj, list):
        return [clean(v) for v in obj]
    if isinstance(obj, dict):
        return {k: clean(v) for k, v in obj.items()}
    if isinstance(obj, float):
        return num(obj)
    return obj


def build(scenes_data: dict, layout: dict) -> dict:
    m = layout["metrics"]
    col = m["columns"]
    sec = layout["sections"]
    sc = sec["scene"]
    stk = layout["stickers"]
    override = {k: v for k, v in layout.get("stickerOverride", {}).items() if not k.startswith("_")}
    scenes = sorted(scenes_data["scenes"], key=lambda s: s["order"])
    script = scenes_data.get("script", "hiragana")
    start_id = f"{script}-start"
    end_id = f"{script}-end"
    half = m["nodeHeight"] / 2
    gap = m["dotGap"]
    # 출발·끝 표지 글자 줄의 반 높이(.footnote 한 줄 약 22pt). 점선이 글자 6pt 앞에서 멈추게 한다.
    label_half = 11

    def dots(frm, to, x0, y0, x1, y1):
        """곧은 점선 한 조각 [시작점, 끝점]. y는 `to` 칸이 든 구간 바닥에서 위로 잰 pt(앞 구간이면 음수)."""
        return {"from": frm, "to": to, "d": [[x0, y0], [x1, y1]]}

    sections = []
    start_y = sec["start"]["nodeY"]
    start_h = sec["start"]["height"]
    sections.append({
        "id": start_id, "kind": "start", "height": start_h, "tile": None,
        "nodes": [{"id": start_id, "kind": "start", "x": 0.5, "y": start_y}],
        "paths": [],
        "stickers": [],
    })

    # 앞 칸의 위 끝: (id, x, 이 구간 바닥 기준 y).
    prev = (start_id, 0.5, start_y + label_half - start_h)
    band_bottom = sc["bandBottom"]
    band_center = (band_bottom + sc["height"]) / 2
    for scene in scenes:
        sid = scene["id"]
        steps = scene["steps"]
        a_id, b_id = steps[0]["id"], steps[1]["id"]
        quiz_id = f"{sid}-quiz"
        h = sc["height"]
        ay, by, qy = sc["stepA"], sc["stepB"], sc["quiz"]
        xa, xb, xq = col["a"], col["b"], col["quiz"]

        arts = scene_stickers(scene, override)[:2]
        slots = ["b"] if len(arts) == 1 else ["a", "b"][: len(arts)]
        stickers = []
        for art, slot in zip(arts, slots):
            # 띠 오른쪽 끝: B 오른쪽 변 = W − bandInset, A = B 왼쪽 stickerGap. dx는 pt (R2.3).
            dx_b = -(m["bandInset"] + m["sticker"] / 2)
            dx = dx_b if slot == "b" else dx_b - m["sticker"] - m["stickerGap"]
            stickers.append({"slot": slot, "art": art, "x": 1, "dx": dx, "y": band_center,
                             "rotate": stk[slot]["rotate"]})

        sections.append({
            "id": sid, "kind": "scene", "scene": sid, "height": h, "tile": None,
            "nodes": [
                {"id": a_id, "kind": "step", "session": a_id, "x": xa, "y": ay},
                {"id": b_id, "kind": "step", "session": b_id, "x": xb, "y": by},
                {"id": quiz_id, "kind": "quiz", "session": quiz_id, "x": xq, "y": qy},
                # 장면 띠: 세 칸 위 끝(목적지). front = 장면을 넘을 때 기리가 거치는 띠 가운데 (R2.4).
                {"id": sid, "kind": "band", "scene": sid, "x": 0.5, "y": band_center, "front": [0.5, band_center]},
            ],
            "paths": [
                # 칸 위 변 가운데 → 다음 칸 아래 변 가운데, 가장자리 dotGap 앞에서 멈춘다. 띠 안으로는 지나지 않는다.
                dots(prev[0], a_id, prev[1] if prev[0] == start_id else xa, prev[2] + gap, xa, ay - half - gap),
                dots(a_id, b_id, xa, ay + half + gap, xb, by - half - gap),
                dots(b_id, quiz_id, xb, by + half + gap, xq, qy - half - gap),
                dots(quiz_id, sid, xq, qy + half + gap, xq, band_bottom - gap),
            ],
            "stickers": stickers,
        })
        # 다음 구간에서 이 띠의 위 끝은 y 0.
        prev = (sid, None, 0)

    end_y = sec["gate"]["nodeY"]
    sections.append({
        "id": end_id, "kind": "gate", "height": sec["gate"]["height"], "tile": None,
        "nodes": [{"id": end_id, "kind": "gate", "x": 0.5, "y": end_y}],
        "paths": [dots(prev[0], end_id, 0.5, gap, 0.5, end_y - label_half - gap)],
        "stickers": [],
    })

    return clean({
        "schema": 2,
        "units": {"x": "fraction of map width (0-1)", "y": "pt (=dp) from section bottom, upward"},
        "metrics": m,
        "motion": layout["motion"],
        "regions": [{"id": script, "script": script, "sections": sections}],
    })


def dump(data: dict) -> str:
    """구간·칸·길·스티커는 한 줄에 하나씩 적어 사람이 diff를 읽기 쉽게 한다."""
    def line(obj):
        return json.dumps(obj, ensure_ascii=False, separators=(", ", ": "))

    out = ["{"]
    out.append(f'  "schema": {data["schema"]},')
    out.append(f'  "units": {line(data["units"])},')
    out.append(f'  "metrics": {line(data["metrics"])},')
    out.append(f'  "motion": {line(data["motion"])},')
    out.append('  "regions": [')
    for ri, region in enumerate(data["regions"]):
        out.append("    {")
        out.append(f'      "id": {line(region["id"])}, "script": {line(region["script"])},')
        out.append('      "sections": [')
        for si, s in enumerate(region["sections"]):
            head = {k: v for k, v in s.items() if k not in ("nodes", "paths", "stickers")}
            out.append("        {")
            out.append("          " + line(head)[1:-1] + ",")
            for key in ("nodes", "paths", "stickers"):
                items = s[key]
                if not items:
                    out.append(f'          "{key}": []' + ("," if key != "stickers" else ""))
                    continue
                out.append(f'          "{key}": [')
                for ii, item in enumerate(items):
                    out.append("            " + line(item) + ("," if ii + 1 < len(items) else ""))
                out.append("          ]" + ("," if key != "stickers" else ""))
            out.append("        }" + ("," if si + 1 < len(region["sections"]) else ""))
        out.append("      ]")
        out.append("    }" + ("," if ri + 1 < len(data["regions"]) else ""))
    out.append("  ]")
    out.append("}")
    text = "\n".join(out) + "\n"
    assert json.loads(text) == data
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="파일이 최신인지 확인만 한다")
    args = parser.parse_args()

    scenes = json.loads(SCENES.read_text(encoding="utf-8"))
    layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
    text = dump(build(scenes, layout))

    if args.check:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print("map.json이 최신이 아님: python3 tools/build_map.py", file=sys.stderr)
            return 1
        print("map.json 최신")
        return 0

    OUT.write_text(text, encoding="utf-8")
    data = json.loads(text)
    stickers = [st["art"] for s in data["regions"][0]["sections"] for st in s["stickers"]]
    print(f"{OUT.relative_to(ROOT)}: 구간 {len(data['regions'][0]['sections'])}, 스티커 {len(stickers)}")
    print("스티커:", " ".join(stickers))
    return 0


if __name__ == "__main__":
    sys.exit(main())
