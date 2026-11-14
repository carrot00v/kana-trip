#!/usr/bin/env python3
"""로컬 ComfyUI 그림 생성의 진행률과 남은 시간을 보여 준다. 표준 라이브러리만 쓴다.

  python3 .claude/skills/image-progress/progress.py \
      [--dir 결과폴더] [--expect 이름:장수 ...] [--host 127.0.0.1:8188]

--expect를 주면 이름별로 몇 장이 나왔는지(<이름>_<시드>.png 개수)와 배치 전체의 남은 시간을 계산한다.
주지 않으면 ComfyUI 큐만 본다 (gen_image.py는 한 장씩 넣으므로 큐에는 1~2개만 보인다).
"""

import argparse
import json
import subprocess
import time
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path


def get(host: str, path: str):
    with urllib.request.urlopen(f"http://{host}{path}", timeout=5) as r:
        return json.loads(r.read())


def durations(history: dict) -> list[tuple[float, float]]:
    """성공한 작업의 (끝난 시각, 걸린 초). 시각은 epoch 초."""
    out = []
    for h in history.values():
        msgs = {m[0]: m[1] for m in h.get("status", {}).get("messages", [])}
        s, e = msgs.get("execution_start"), msgs.get("execution_success")
        if s and e:
            out.append((e["timestamp"] / 1000, (e["timestamp"] - s["timestamp"]) / 1000))
    return sorted(out)


def describe(item) -> str:
    wf = item[2]
    seed = next((n["inputs"].get("seed") for n in wf.values() if n.get("class_type") == "KSampler"), "?")
    text = next((n["inputs"].get("text", "") for n in wf.values() if n.get("class_type") == "CLIPTextEncode"), "")
    subj = text.split("Subject: ", 1)[-1][:60] if "Subject: " in text else text[:60]
    return f"seed {seed} · {subj}…"


def swap_line() -> str | None:
    try:
        s = subprocess.run(["sysctl", "-n", "vm.swapusage"], capture_output=True, text=True).stdout
        parts = dict(p.split(" = ") for p in s.strip().split("  ") if " = " in p)
        used, total = float(parts["used"].rstrip("M")), float(parts["total"].rstrip("M"))
        if total and used / total > 0.8:
            return f"스왑 {used / 1024:.1f}/{total / 1024:.1f}GB 사용 중. 메모리가 모자라 평소(3.5~5분)보다 느릴 수 있음"
    except Exception:
        pass
    return None


def fmt(sec: float) -> str:
    return f"{sec / 60:.0f}분" if sec >= 90 else f"{sec:.0f}초"


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dir", type=Path)
    p.add_argument("--expect", nargs="*", default=[], help="이름:장수 (예: thumb-sushi:4)")
    p.add_argument("--host", default="127.0.0.1:8188")
    a = p.parse_args()

    try:
        q = get(a.host, "/queue")
        hist = get(a.host, "/history?max_items=50")
    except Exception as e:
        print(f"ComfyUI({a.host})에 연결할 수 없음: {e}")
        print("Comfy Desktop이 꺼져 있으면 그림 작업은 docs/schedule.md 보류 작업으로 올린다 (CLAUDE.md).")
        return 1

    running, pending = q["queue_running"], q["queue_pending"]
    done_times = durations(hist)
    recent = [d for _, d in done_times[-6:]]
    avg = sum(recent) / len(recent) if recent else None

    # 지금 도는 작업의 경과: 큐가 이어서 돌았다면 직전 작업이 끝난 시각부터
    elapsed = time.time() - done_times[-1][0] if running and done_times else None

    print(f"ComfyUI: 실행 중 {len(running)} · 대기 {len(pending)}")
    for item in running:
        extra = f" (경과 약 {fmt(elapsed)})" if elapsed is not None else ""
        print(f"  ▶ {describe(item)}{extra}")
    for item in pending:
        print(f"  … {describe(item)}")
    if avg:
        print(f"최근 {len(recent)}장 평균 {fmt(avg)}/장")

    remaining_imgs = len(running) + len(pending)
    if a.expect:
        if not a.dir:
            p.error("--expect에는 --dir이 필요하다")
        total = made = 0
        print(f"\n배치 ({a.dir}):")
        for e in a.expect:
            name, n = e.rsplit(":", 1)
            n = int(n)
            k = len(list(a.dir.glob(f"{name}_*.png")))
            total, made = total + n, made + min(k, n)
            bar = "█" * min(k, n) + "░" * max(n - k, 0)
            print(f"  {name:<22} {bar} {k}/{n}")
        print(f"  합계 {made}/{total}장 ({made * 100 // total if total else 0}%)")
        remaining_imgs = total - made

    if avg and remaining_imgs:
        left = remaining_imgs * avg - (min(elapsed, avg) if elapsed else 0)
        eta = datetime.now() + timedelta(seconds=max(left, 0))
        print(f"남은 {remaining_imgs}장 · 약 {fmt(max(left, 0))} · 예상 완료 {eta:%H:%M}")
    elif not remaining_imgs:
        print("남은 작업 없음")

    if elapsed and avg and elapsed > 2 * avg:
        print(f"주의: 지금 작업이 평균의 두 배({fmt(elapsed)})를 넘김. gen_image.py --timeout(기본 1800초)에 걸리면 "
              "결과가 폴더에 저장되지 않으니, 그때는 ComfyUI /history에서 꺼내 저장한다.")
    if (w := swap_line()):
        print(w)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
