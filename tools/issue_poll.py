#!/usr/bin/env python3
"""결정이 필요한 항목을 GitHub 이슈로 올리고, 저장소 주인의 코멘트를 기다린다.

  python3 tools/issue_poll.py create --title "..." --body-file 본문.md [--label decision]
  python3 tools/issue_poll.py comment 12 --body-file 답.md
  python3 tools/issue_poll.py close 12
  python3 tools/issue_poll.py list                      # 열린 결정 이슈
  python3 tools/issue_poll.py wait [--interval 60] [--hours 6]

wait는 새 코멘트가 올 때까지 기다렸다가 JSON 한 줄씩 출력하고 끝난다(종료 코드 0).
시간이 다 되면 "없음"을 출력하고 종료 코드 3으로 끝난다. 다시 돌리면 이어서 본다.

- 저장소가 공개라서 누구나 코멘트를 달 수 있다. 저장소 주인(author_association == OWNER)의
  코멘트만 출력한다. 다른 사람의 코멘트는 개수만 알린다.
- 토큰은 git이 이 저장소에 쓰는 것을 `git credential fill`로 받아 api.github.com에만 보낸다.
  화면이나 파일에 쓰지 않는다. 환경 변수 GITHUB_TOKEN이 있으면 그것을 쓴다.
- 어디까지 봤는지는 build/issue-poll-state.json에 둔다(git이 무시하는 폴더).
- 이슈에는 개인 정보(계정 메일 등)를 적지 않는다.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = "carrot00v/kana-trip"
API = f"https://api.github.com/repos/{REPO}"
STATE = ROOT / "build" / "issue-poll-state.json"


def token() -> str | None:
    if os.environ.get("GITHUB_TOKEN"):
        return os.environ["GITHUB_TOKEN"]
    try:
        out = subprocess.run(["git", "credential", "fill"], input="protocol=https\nhost=github.com\n\n",
                             capture_output=True, text=True, timeout=10,
                             env={**os.environ, "GIT_TERMINAL_PROMPT": "0"}).stdout
    except Exception:
        return None
    for line in out.splitlines():
        if line.startswith("password="):
            return line[len("password="):]
    return None


def call(method: str, url: str, data: dict | None = None, auth: bool = True):
    req = urllib.request.Request(url, method=method,
                                 data=json.dumps(data).encode() if data is not None else None)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("User-Agent", "issue-poll-script")
    tok = token() if auth else None
    if tok:
        req.add_header("Authorization", f"Bearer {tok}")
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read() or b"null")


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_state() -> dict:
    if STATE.exists():
        return json.loads(STATE.read_text())
    return {"since": now(), "seen": []}


def save_state(s: dict) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(s))


def cmd_wait(a) -> int:
    s = load_state()
    save_state(s)
    deadline = time.time() + a.hours * 3600
    others = 0
    while time.time() < deadline:
        try:
            comments = call("GET", f"{API}/issues/comments?since={s['since']}&sort=created&direction=asc&per_page=100")
        except (urllib.error.URLError, TimeoutError) as e:
            print(f"확인 실패, 다시 시도: {e}", file=sys.stderr, flush=True)
            time.sleep(a.interval)
            continue
        fresh = [c for c in comments if c["id"] not in s["seen"]]
        mine = [c for c in fresh if c.get("author_association") == "OWNER" and not c["body"].startswith("[PM]")]
        others += sum(1 for c in fresh if c.get("author_association") != "OWNER")
        if fresh:
            s["seen"] = (s["seen"] + [c["id"] for c in fresh])[-500:]
            save_state(s)
        if mine:
            for c in mine:
                number = int(c["issue_url"].rsplit("/", 1)[1])
                print(json.dumps({"issue": number, "comment_id": c["id"], "created_at": c["created_at"],
                                  "body": c["body"]}, ensure_ascii=False), flush=True)
            if others:
                print(f"저장소 주인이 아닌 사람의 코멘트 {others}개는 건너뜀", flush=True)
            return 0
        time.sleep(a.interval)
    print("없음", flush=True)
    return 3


def cmd_create(a) -> int:
    body = Path(a.body_file).read_text()
    r = call("POST", f"{API}/issues", {"title": a.title, "body": body, "labels": a.label or []})
    print(r["number"], r["html_url"])
    return 0


def cmd_comment(a) -> int:
    # 내가 단 코멘트는 [PM]으로 시작해 wait가 사용자 답으로 읽지 않게 한다 (같은 계정으로 올라간다)
    body = "[PM] " + Path(a.body_file).read_text()
    r = call("POST", f"{API}/issues/{a.number}/comments", {"body": body})
    print(r["html_url"])
    return 0


def cmd_close(a) -> int:
    call("PATCH", f"{API}/issues/{a.number}", {"state": "closed"})
    print(f"닫음 #{a.number}")
    return 0


def cmd_list(a) -> int:
    for i in call("GET", f"{API}/issues?state=open&per_page=100"):
        if "pull_request" not in i:
            print(f"#{i['number']} {i['title']} (코멘트 {i['comments']})")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    w = sub.add_parser("wait")
    w.add_argument("--interval", type=int, default=60)
    w.add_argument("--hours", type=float, default=6)
    w.set_defaults(f=cmd_wait)
    c = sub.add_parser("create")
    c.add_argument("--title", required=True)
    c.add_argument("--body-file", required=True)
    c.add_argument("--label", action="append")
    c.set_defaults(f=cmd_create)
    m = sub.add_parser("comment")
    m.add_argument("number", type=int)
    m.add_argument("--body-file", required=True)
    m.set_defaults(f=cmd_comment)
    x = sub.add_parser("close")
    x.add_argument("number", type=int)
    x.set_defaults(f=cmd_close)
    sub.add_parser("list").set_defaults(f=cmd_list)
    a = p.parse_args()
    try:
        return a.f(a)
    except urllib.error.HTTPError as e:
        print(f"GitHub 응답 {e.code}: {e.read().decode()[:300]}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
