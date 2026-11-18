#!/usr/bin/env python3
"""지도 정의 데이터 map.json을 만든다 (docs/design/home-map.md 7.1).

  python3 tools/build_map.py           # KanaTrip/Resources/map.json을 다시 쓴다
  python3 tools/build_map.py --check   # 지금 파일과 다르면 1로 끝난다(쓰지 않음)

입력
- KanaTrip/Resources/hiragana_scenes.json: 장면 순서, 단계 id, 단어의 그림 이름(`art`).
- tools/map_layout.json: 1.3의 수치(metrics, motion, 구간 높이, 칸 y), 스티커 자리, `stickerOverride`.
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


def pick_sticker(step: dict, override: dict) -> str | None:
    """단계의 단어 가운데 데이터 순서로 처음 나오는, 그림이 있는 단어의 `art` (2.3)."""
    if step["id"] in override:
        return override[step["id"]]
    for word in step["words"]:
        art = word.get("art")
        if art and has_art(art):
            return art
    return None


def curve(x0, y0, x1, y1):
    """세로로 떠나 세로로 닿는 3차 베지어. 제어점은 두 칸 y의 가운데 (1.3)."""
    mid = (y0 + y1) / 2
    return [[x0, y0], [x0, mid], [x1, mid], [x1, y1]]


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
    left, right = layout["metrics"]["lanes"]
    sec = layout["sections"]
    sc = sec["scene"]
    stk = layout["stickers"]
    override = layout.get("stickerOverride", {})
    scenes = sorted(scenes_data["scenes"], key=lambda s: s["order"])
    script = scenes_data.get("script", "hiragana")
    start_id = f"{script}-start"
    end_id = f"{script}-end"

    sections = []
    start_y = sec["start"]["nodeY"]
    start_h = sec["start"]["height"]
    first_to = scenes[0]["id"] if scenes else end_id
    sections.append({
        "id": start_id, "kind": "start", "height": start_h, "tile": None,
        "nodes": [{"id": start_id, "kind": "start", "x": 0.5, "y": start_y}],
        "paths": [{"from": start_id, "to": first_to,
                   "d": [[0.5, start_y], [0.5, start_y + 40], [0.5, start_y + 64], [0.5, start_h]]}],
        "stickers": [],
    })

    previous = start_id
    for i, scene in enumerate(scenes):
        sid = scene["id"]
        # 홀수 장면(1번째, 3번째 …)은 a 칸이 왼쪽 길, 짝수 장면은 오른쪽 길 (1.3).
        lane_a = left if i % 2 == 0 else right
        lane_b = right if i % 2 == 0 else left
        a_is_left = lane_a < 0.5
        bubble_a = "right" if a_is_left else "left"
        bubble_b = "left" if a_is_left else "right"
        steps = scene["steps"]
        a_id, b_id = steps[0]["id"], steps[1]["id"]
        quiz_id = f"{sid}-quiz"
        h = sc["height"]
        by, fy, ay, bly, qy = sc["building"], sc["front"], sc["stepA"], sc["stepB"], sc["quiz"]
        nxt = scenes[i + 1]["id"] if i + 1 < len(scenes) else end_id

        stickers = []
        metrics = layout["metrics"]
        for key, step in (("a", steps[0]), ("b", steps[1])):
            art = pick_sticker(step, override)
            if not art:
                continue
            spec = stk[key]
            # 건물 카드 양옆에 붙인다: A 왼쪽·8pt 아래, B 오른쪽·8pt 위 (2.3, 2026-11-18).
            # dx는 pt라 지도 폭과 상관없이 건물에 붙어 있다.
            side = spec["side"]
            stickers.append({
                "step": step["id"], "art": art,
                "x": 0.5, "dx": side * metrics["stickerDx"],
                "y": by + side * metrics["stickerDy"], "rotate": spec["rotate"],
            })

        sections.append({
            "id": sid, "kind": "scene", "scene": sid, "height": h, "tile": None,
            "nodes": [
                {"id": sid, "kind": "building", "scene": sid, "x": 0.5, "y": by, "front": [0.5, fy]},
                {"id": a_id, "kind": "step", "session": a_id, "x": lane_a, "y": ay, "bubble": bubble_a},
                {"id": b_id, "kind": "step", "session": b_id, "x": lane_b, "y": bly, "bubble": bubble_b},
                {"id": quiz_id, "kind": "quiz", "session": quiz_id, "x": lane_a, "y": qy, "bubble": bubble_a},
            ],
            "paths": [
                # 구간 경계에서 길은 x 0.5로 세로로 지난다 (1.3).
                {"from": previous, "to": sid, "d": [[0.5, 0], [0.5, 27], [0.5, 53], [0.5, by]]},
                {"from": sid, "to": a_id, "d": [[0.5, by], [0.5, (by + ay) / 2], [lane_a, (by + ay) / 2], [lane_a, ay]]},
                {"from": a_id, "to": b_id, "d": curve(lane_a, ay, lane_b, bly)},
                {"from": b_id, "to": quiz_id, "d": curve(lane_b, bly, lane_a, qy)},
                {"from": quiz_id, "to": nxt, "d": [[lane_a, qy], [lane_a, qy + 34], [0.5, qy + 14], [0.5, h]]},
            ],
            "stickers": stickers,
        })
        previous = quiz_id

    end_y = sec["gate"]["nodeY"]
    sections.append({
        "id": end_id, "kind": "gate", "height": sec["gate"]["height"], "tile": None,
        "nodes": [{"id": end_id, "kind": "gate", "x": 0.5, "y": end_y, "bubble": "right"}],
        "paths": [{"from": previous, "to": end_id, "d": [[0.5, 0], [0.5, end_y / 3], [0.5, end_y * 2 / 3], [0.5, end_y]]}],
        "stickers": [],
    })

    return clean({
        "schema": 1,
        "units": {"x": "fraction of map width (0-1)", "y": "pt (=dp) from section bottom, upward"},
        "metrics": layout["metrics"],
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
