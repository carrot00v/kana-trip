"""오니기리 캐릭터 SVG를 만든다.

밥알이 뭉친 울퉁불퉁한 외곽선은 손으로 그리기 어려워서 계산으로 만든다.
실행: python3 tools/make_onigiri_svg.py
산출물: docs/design/character/onigiri-default.svg, onigiri-happy.svg
"""
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "docs/design/character"

LINE = "#4A2219"      # 외곽선, 눈, 입
RICE = "#FFFDF7"      # 밥
GRAIN = "#EFE3CC"     # 밥알 결
NORI = "#34402F"      # 김
RED = "#E2533F"       # 두건, 모자 띠
CHEEK = "#F5A7A0"     # 볼
TONGUE = "#EE8A8A"
YELLOW = "#F6B92B"    # 강조 표시
SW = 6                # 외곽선 굵기


def rounded_triangle(verts, r, n):
    """작은 삼각형을 반지름 r만큼 부풀린 외곽선 위에서 같은 간격의 점 n개."""
    segs = []  # (종류, 데이터, 길이)
    k = len(verts)
    cx = sum(v[0] for v in verts) / k
    cy = sum(v[1] for v in verts) / k
    normals = []
    for i in range(k):
        a, b = verts[i], verts[(i + 1) % k]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nx, ny = dy / L, -dx / L
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        if (mx - cx) * nx + (my - cy) * ny < 0:
            nx, ny = -nx, -ny
        normals.append((nx, ny))
    for i in range(k):
        a, b = verts[i], verts[(i + 1) % k]
        nx, ny = normals[i]
        p0 = (a[0] + nx * r, a[1] + ny * r)
        p1 = (b[0] + nx * r, b[1] + ny * r)
        segs.append(("line", (p0, p1), math.hypot(p1[0] - p0[0], p1[1] - p0[1])))
        # 꼭짓점 b의 둥근 모서리
        n2 = normals[(i + 1) % k]
        a0 = math.atan2(ny, nx)
        a1 = math.atan2(n2[1], n2[0])
        da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
        segs.append(("arc", (b, a0, da), abs(da) * r))
    total = sum(s[2] for s in segs)
    pts = []
    for j in range(n):
        t = total * j / n
        for kind, d, L in segs:
            if t <= L:
                if kind == "line":
                    (x0, y0), (x1, y1) = d
                    f = t / L if L else 0
                    pts.append((x0 + (x1 - x0) * f, y0 + (y1 - y0) * f))
                else:
                    c, a0, da = d
                    a = a0 + da * (t / L if L else 0)
                    pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
                break
            t -= L
    return pts, (cx, cy)


def scallop_path(pts, center, bump):
    """점 사이를 바깥으로 볼록한 곡선으로 이어 밥알 뭉치 느낌을 낸다."""
    cx, cy = center
    d = [f"M{pts[0][0]:.1f} {pts[0][1]:.1f}"]
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nx, ny = dy / L, -dx / L
        if (mx - cx) * nx + (my - cy) * ny < 0:
            nx, ny = -nx, -ny
        h = bump * (1.0 + 0.35 * math.sin(i * 2.3))  # 크기를 조금씩 다르게
        d.append(f"Q{mx + nx * h:.1f} {my + ny * h:.1f} {b[0]:.1f} {b[1]:.1f}")
    return " ".join(d) + "Z"


def body_path():
    # 모서리 반지름을 크게 잡아 꼭대기가 둥글고 옆이 불룩한 주먹밥 모양으로
    pts, c = rounded_triangle([(150, 182), (202, 250), (98, 250)], 72, 32)
    return scallop_path(pts, c, 4)


def stub(d, width=22):
    """흰 막대(팔·다리)에 외곽선을 두른다."""
    return (f'<path d="{d}" stroke="{LINE}" stroke-width="{width}" stroke-linecap="round" fill="none"/>'
            f'<path d="{d}" stroke="{RICE}" stroke-width="{width - 2 * SW}" stroke-linecap="round" fill="none"/>')


def hat():
    puffs = [(112, 72, 30), (150, 54, 36), (188, 72, 30)]
    rect = (98, 70, 104, 36)
    outline = "".join(f'<circle cx="{x}" cy="{y}" r="{r}"/>' for x, y, r in puffs)
    outline += f'<rect x="{rect[0]}" y="{rect[1]}" width="{rect[2]}" height="{rect[3]}"/>'
    return f'''
  <!-- 요리사 모자: 살짝 기울인다 -->
  <g transform="rotate(-5 150 110)">
    <g fill="{LINE}" stroke="{LINE}" stroke-width="{SW * 2}" stroke-linejoin="round">{outline}</g>
    <g fill="{RICE}">{outline}</g>
    <path d="M100 66 Q106 56 118 54" fill="none" stroke="{GRAIN}" stroke-width="4" stroke-linecap="round"/>
    <!-- 모자 앞의 오니기리 표시 -->
    <path d="M150 62 Q153 62 167 86 Q168 90 164 90 L136 90 Q132 90 133 86 Q147 62 150 62Z" fill="{RICE}" stroke="{LINE}" stroke-width="4.5" stroke-linejoin="round"/>
    <rect x="145" y="77" width="10" height="13" fill="{NORI}"/>
    <!-- 모자 띠 -->
    <rect x="94" y="100" width="112" height="18" rx="5" fill="{RED}" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
  </g>'''


def scarf():
    return f'''
  <!-- 두건: 오른쪽이 올라가게 비스듬히 -->
  <path d="M28 224 Q150 252 272 204 L274 226 Q150 278 30 248Z" fill="{RED}" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
  <path d="M44 238 L2 246 L30 264Z" fill="{RED}" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
  <path d="M52 246 L40 292 L70 262Z" fill="{RED}" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
  <circle cx="48" cy="242" r="13" fill="{RED}" stroke="{LINE}" stroke-width="{SW}"/>'''


EYE_L = f'<ellipse cx="114" cy="170" rx="7" ry="10" fill="{LINE}"/>'
EYE_R = f'<ellipse cx="186" cy="170" rx="7" ry="10" fill="{LINE}"/>'

FACES = {
    "default": f'''
  {EYE_L}
  {EYE_R}
  <path d="M140 186 Q150 196 160 186" fill="none" stroke="{LINE}" stroke-width="5.5" stroke-linecap="round"/>''',
    "happy": f'''
  {EYE_L}
  <path d="M196 161 L180 170 L196 179" fill="none" stroke="{LINE}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M135 180 L165 180 Q165 207 150 207 Q135 207 135 180Z" fill="{LINE}" stroke="{LINE}" stroke-width="4" stroke-linejoin="round"/>
  <path d="M140 198 Q150 189 160 198 Q157 205 150 205 Q143 205 140 198Z" fill="{TONGUE}"/>''',
}

ARMS = {
    "default": stub("M36 266 L22 284", 24) + stub("M264 266 L278 284", 24),
    "happy": stub("M258 214 Q298 204 290 164", 24),
}

MARKS = f'''
  <!-- 강조 표시 -->
  <g stroke="{YELLOW}" stroke-width="8" stroke-linecap="round">
    <path d="M284 130 L286 112"/>
    <path d="M298 140 L311 127"/>
    <path d="M303 157 L318 154"/>
  </g>'''


def svg(kind):
    body = body_path()
    grains = "".join(
        f'<path d="{d}" fill="none" stroke="{GRAIN}" stroke-width="4" stroke-linecap="round"/>'
        for d in ["M182 132 q6 2 9 8", "M78 156 q-2 6 0 11", "M222 192 q4 4 4 10",
                  "M44 270 q6 4 12 3", "M226 260 q-2 6 -8 9", "M60 296 q6 3 12 2"])
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-30 0 360 360" width="360" height="360">
  <defs>
    <clipPath id="bodyClip"><path d="{body}"/></clipPath>
  </defs>

  <!-- 그림자 -->
  <ellipse cx="150" cy="346" rx="90" ry="9" fill="#E8D4BE" opacity="0.8"/>

  <!-- 다리 -->
  {stub("M128 314 L128 332", 36)}
  {stub("M172 314 L172 332", 36)}

  <!-- 팔 -->
  {ARMS[kind]}

  <!-- 몸통 -->
  <path d="{body}" fill="{RICE}"/>
  <g clip-path="url(#bodyClip)">
    {grains}
    <rect x="96" y="232" width="108" height="114" fill="{NORI}" stroke="{LINE}" stroke-width="4"/>
  </g>
  <path d="{body}" fill="none" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
{scarf()}
{hat()}

  <!-- 볼 -->
  <ellipse cx="94" cy="190" rx="15" ry="10" fill="{CHEEK}"/>
  <ellipse cx="206" cy="190" rx="15" ry="10" fill="{CHEEK}"/>
  <!-- 얼굴 -->{FACES[kind]}
{MARKS if kind == "happy" else ""}
</svg>
'''


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in FACES:
        (OUT / f"onigiri-{kind}.svg").write_text(svg(kind), encoding="utf-8")
        print("wrote", OUT / f"onigiri-{kind}.svg")
