#!/usr/bin/env python3
"""로컬 ComfyUI(Z-Image Turbo)로 디자인 시안 이미지를 만든다.

필요한 것: 실행 중인 Comfy Desktop(기본 127.0.0.1:8188)과
~/ComfyUI-Shared/models 아래의 세 파일
  diffusion_models/z_image_turbo_bf16.safetensors
  text_encoders/qwen_3_4b.safetensors
  vae/ae.safetensors

예:
  python3 tools/gen_image.py "flat vector app icon ..." --name icon --count 4
결과는 docs/design/item-art/source/candidates/<name>_<seed>.png 이고, 같은 이름의 .json에
프롬프트와 설정을 남겨 같은 시드로 다시 만들 수 있게 한다.
"""

import argparse
import json
import random
import sys
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "docs" / "design" / "item-art" / "source" / "candidates"


def workflow(prompt: str, seed: int, width: int, height: int, steps: int, shift: float) -> dict:
    # Apple GPU(MPS)는 fp8을 지원하지 않으므로 weight_dtype은 default(bf16)로 둔다.
    return {
        "1": {"class_type": "UNETLoader",
              "inputs": {"unet_name": "z_image_turbo_bf16.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader",
              "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "lumina2"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "4": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["1", 0], "shift": shift}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": prompt}},
        "6": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["5", 0]}},
        "7": {"class_type": "EmptySD3LatentImage",
              "inputs": {"width": width, "height": height, "batch_size": 1}},
        "8": {"class_type": "KSampler",
              "inputs": {"model": ["4", 0], "positive": ["5", 0], "negative": ["6", 0],
                         "latent_image": ["7", 0], "seed": seed, "steps": steps, "cfg": 1.0,
                         "sampler_name": "res_multistep", "scheduler": "simple", "denoise": 1.0}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"images": ["9", 0], "filename_prefix": "kanatrip"}},
    }


def call(host: str, path: str, data: dict | None = None):
    req = urllib.request.Request(
        f"http://{host}{path}",
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def generate(host: str, wf: dict, timeout: float) -> bytes:
    res = json.loads(call(host, "/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())}))
    if res.get("node_errors"):
        raise RuntimeError(json.dumps(res["node_errors"], ensure_ascii=False))
    pid = res["prompt_id"]
    deadline = time.time() + timeout
    while time.time() < deadline:
        hist = json.loads(call(host, f"/history/{pid}")).get(pid)
        if hist:
            status = hist.get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(json.dumps(status.get("messages"), ensure_ascii=False)[:2000])
            for out in hist.get("outputs", {}).values():
                for img in out.get("images", []):
                    q = urllib.parse.urlencode(
                        {"filename": img["filename"], "subfolder": img["subfolder"], "type": img["type"]})
                    return call(host, f"/view?{q}")
        time.sleep(1)
    raise TimeoutError(f"{timeout}초 안에 끝나지 않음 (prompt_id={pid})")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("prompt")
    p.add_argument("--name", default="draft", help="파일 이름 앞부분")
    p.add_argument("--count", type=int, default=1, help="시드를 바꿔 몇 장 만들지")
    p.add_argument("--seed", type=int, help="첫 시드 (없으면 무작위, 이후 +1씩)")
    p.add_argument("--width", type=int, default=1024)
    p.add_argument("--height", type=int, default=1024)
    p.add_argument("--steps", type=int, default=8)
    p.add_argument("--shift", type=float, default=3.0)
    p.add_argument("--out", type=Path, default=DEFAULT_OUT)
    p.add_argument("--host", default="127.0.0.1:8188")
    p.add_argument("--timeout", type=float, default=600)
    a = p.parse_args()

    a.out.mkdir(parents=True, exist_ok=True)
    seed = a.seed if a.seed is not None else random.randint(0, 2**31 - 1)
    for i in range(a.count):
        s = seed + i
        t0 = time.time()
        png = generate(a.host, workflow(a.prompt, s, a.width, a.height, a.steps, a.shift), a.timeout)
        path = a.out / f"{a.name}_{s}.png"
        path.write_bytes(png)
        meta = {"prompt": a.prompt, "seed": s, "width": a.width, "height": a.height,
                "steps": a.steps, "shift": a.shift, "model": "z_image_turbo_bf16"}
        path.with_suffix(".json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n")
        print(f"{path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}  ({time.time() - t0:.1f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
