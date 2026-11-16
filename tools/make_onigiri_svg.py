"""오니기리 캐릭터 SVG를 만든다.

밥알이 뭉친 울퉁불퉁한 외곽선은 손으로 그리기 어려워서 계산으로 만든다.
실행: python3 tools/make_onigiri_svg.py   (.venv/bin/python이면 그린 픽셀 비교까지 한다. Pillow 필요)
산출물: docs/design/character/onigiri-{default,happy,talk,point,think,sorry}.svg, 레이어 SVG와 앱 에셋
        docs/design/character/layers/, items/ (꾸미기용 레이어, docs/design/reward-flow.md 8.1)
        KanaTrip/Assets.xcassets의 레이어 에셋 (GiriBase*[-{밥 id}], GiriFace*, GiriSparkles, Item-chef_hat, ItemThumb-*)

밥 바꾸기 (docs/design/item-art/brief.md 2.4): 본체 레이어(그림자, 다리, 팔, 몸, 무늬, 김, 외곽선, 볼, 빨간 두건)를
밥 정의 표 RICES마다 만든다. 흰 밥(plain_rice)은 접미사 없는 지금 이름(GiriBaseDefault, GiriBaseHappy)이다.
밥 색·무늬 값은 이 표에만 둔다(rewards.json에는 넣지 않는다). 실행할 때 대비와 얼굴 금지 구역을 검사해 출력하고,
기준을 못 넘으면 멈춘다.
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/design/character"
ASSETS = ROOT / "KanaTrip/Assets.xcassets"

LINE = "#4A2219"      # 외곽선, 눈, 입
RICE = "#FFFDF7"      # 밥
GRAIN = "#EFE3CC"     # 밥알 결
NORI = "#34402F"      # 김
RED = "#E2533F"       # 두건, 모자 띠
CHEEK = "#F5A7A0"     # 볼
TONGUE = "#EE8A8A"
YELLOW = "#F6B92B"    # 강조 표시
TOAST = "#EBBE7E"     # やきおにぎり 밥 바탕 (brief.md 2.4.5)
WOOD = "#C68A52"      # やきおにぎり 그을림
CHEEK_DEEP = "#E8857A"  # やきおにぎり 볼
SHADOW = "#E8D4BE"    # 그림자 (밥과 상관없이 그대로)
SW = 6                # 외곽선 굵기

# 밥알 결 선 (흰 밥만). 무늬 있는 밥은 결 선 대신 무늬를 그린다 (brief.md 2.4.4).
GRAIN_LINES = ["M182 132 q6 2 9 8", "M78 156 q-2 6 0 11", "M222 192 q4 4 4 10",
               "M44 270 q6 4 12 3", "M226 260 q-2 6 -8 9", "M60 296 q6 3 12 2"]

# 밥 정의 표 (brief.md 2.4.5). 무늬는 (cx, cy, rx, ry, rotate) 타원 목록. 외곽선 없이 bodyClip 안에서 그린다.
RICES = {
    "plain_rice": {"fill": RICE, "pattern": None, "pattern_color": GRAIN, "cheek": CHEEK},
    "goma": {
        "fill": RICE, "pattern_color": LINE, "cheek": CHEEK,
        # 검은깨 9알 (18 × 9)
        "pattern": [(126, 123, 9, 4.5, -10), (150, 121, 9, 4.5, 0), (174, 123, 9, 4.5, 10),
                    (62, 203, 9, 4.5, -35), (238, 203, 9, 4.5, 35),
                    (232, 262, 9, 4.5, 15), (246, 284, 9, 4.5, -25), (222, 300, 9, 4.5, -20),
                    (74, 300, 9, 4.5, 20)],
    },
    "yakionigiri": {
        "fill": TOAST, "pattern_color": WOOD, "cheek": CHEEK_DEEP,
        # 가장자리 그을림 5조각
        "pattern": [(150, 116, 36, 14, 0), (55, 195, 18, 15, -53), (245, 195, 18, 15, 53),
                    (54, 292, 28, 18, 46), (246, 292, 28, 18, -46)],
    },
}


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


def stub(d, width=22, fill=RICE):
    """밥 색 막대(팔·다리)에 외곽선을 두른다. 팔·다리에는 무늬를 넣지 않는다 (brief.md 2.4.4)."""
    return (f'<path d="{d}" stroke="{LINE}" stroke-width="{width}" stroke-linecap="round" fill="none"/>'
            f'<path d="{d}" stroke="{fill}" stroke-width="{width - 2 * SW}" stroke-linecap="round" fill="none"/>')


def head_inner_path():
    """몸 외곽선 안쪽 가장자리(본체 경로를 SW/2 = 3 안쪽으로 줄인 모양). 머리 아이템의 띠를 머리 안쪽에서 자를 때 쓴다
    (docs/design/item-art/head-fit.md 3.1)."""
    pts, c = rounded_triangle([(150, 182), (202, 250), (98, 250)], 72 - SW / 2, 32)
    return scallop_path(pts, c, 4)


# 기본 요리사 모자의 놓는 값 (head-fit.md 3.1): 모자 안 좌표 (150, 138)(띠 아랫변 가운데)을 기리 좌표 (142, 138)에 두고
# 그 점을 축으로 −6° 돌린다. dx −8, θ = asin(−8/72) ≈ −6.4°.
HAT_TRANSFORM = "translate(-8 0) rotate(-6 150 138)"


def hat(clip=True):
    """기본 요리사 모자 (head-fit.md 3.1, 맞춤 방식 swallow). 띠는 웃는 모양 곡선으로 머리보다 넓게 그리고
    머리 안쪽(headInner)에서 자른다. 관은 아래가 좁은 사다리꼴, 뭉게구름은 머리 어깨와 12 이상 떨어진다.
    clip=False는 자르기 전 띠 길이를 재는 검사용이다(place_item_art.py)."""
    # 구름은 문서 3.1의 값((112, 64) r28, (150, 48) r32, (188, 64) r28)에서 낮추고 줄였다. 문서 값이면 전체 높이 133,
    # 왼쪽 끝 x 62로 크기 상한(높이 120)과 범위(x 64)를 넘는다.
    puffs = [(114, 72, 26), (150, 58, 29), (186, 72, 26)]
    outline = "".join(f'<circle cx="{x}" cy="{y}" r="{r}"/>' for x, y, r in puffs)
    # 관 윗변을 문서의 y 84에서 76으로 올려 가운데 구름(아래 끝 80)과의 틈을 메운다. 보이는 옆선 기울기는 같다.
    outline += '<polygon points="100.4,76 199.6,76 176,128 124,128"/>'
    return f'''
  <!-- 요리사 모자: 띠가 머리를 가로지르고 머리 안쪽에서 잘린다 (head-fit.md 3.1) -->
  <defs><clipPath id="headInner"><path d="{head_inner_path()}"/></clipPath></defs>
  <g transform="{HAT_TRANSFORM}">
    <g fill="{LINE}" stroke="{LINE}" stroke-width="{SW * 2}" stroke-linejoin="round">{outline}</g>
    <g fill="{RICE}">{outline}</g>
    <path d="M104 68 Q109 58 120 56" fill="none" stroke="{GRAIN}" stroke-width="4" stroke-linecap="round"/>
    <!-- 모자 앞의 오니기리 표시 -->
    <path d="M150 84 Q153 84 167 108 Q168 112 164 112 L136 112 Q132 112 133 108 Q147 84 150 84Z" fill="{RICE}" stroke="{LINE}" stroke-width="4.5" stroke-linejoin="round"/>
    <rect x="145" y="99" width="10" height="13" fill="{NORI}"/>
  </g>
  <!-- 모자 띠: clipPath는 기리 좌표(변환 바깥)에 건다. 문서의 86~214보다 양쪽 6 길게 그려 오른쪽 끝도 외곽선 밖 4 이상 나간다 -->
  <g{' clip-path="url(#headInner)"' if clip else ''}>
    <g transform="{HAT_TRANSFORM}">
      <path d="M80 131 Q150 145 220 131 L220 113 Q150 127 80 113Z" fill="{RED}" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
    </g>
  </g>'''


def hat_icon():
    """2026-11-17 전의 요리사 모자. 앱 아이콘(make_app_icon.py)만 쓴다. 아이콘을 새 모자로 맞출지는 PM 결정 대기
    (head-fit.md 3.1)."""
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
    # 기리 동행 표정 (docs/design/giri-companion.md 4.2)
    "talk": f'''
  {EYE_L}
  {EYE_R}
  <path d="M140 184 Q150 181 160 184 Q160 200 150 200 Q140 200 140 184Z" fill="{LINE}" stroke="{LINE}" stroke-width="3" stroke-linejoin="round"/>
  <path d="M143 194 Q150 189 157 194 Q155 199 150 199 Q145 199 143 194Z" fill="{TONGUE}"/>''',
    "think": f'''
  <ellipse cx="118" cy="167" rx="6" ry="9" fill="{LINE}"/>
  <ellipse cx="190" cy="167" rx="6" ry="9" fill="{LINE}"/>
  <path d="M145 191 Q152 187 160 189" fill="none" stroke="{LINE}" stroke-width="5.5" stroke-linecap="round"/>''',
    "sorry": f'''
  <path d="M104 161 L120 170 L104 179" fill="none" stroke="{LINE}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M196 161 L180 170 L196 179" fill="none" stroke="{LINE}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M139 193 Q144.5 187 150 193 Q155.5 199 161 193" fill="none" stroke="{LINE}" stroke-width="5" stroke-linecap="round"/>''',
}

# 확인용 완성 그림: 이름 → (얼굴, 팔, 반짝임) (giri-companion.md 4.1). 앱은 레이어를 겹쳐 그린다.
EXPRESSIONS = {
    "default": ("default", "default", False),
    "happy": ("happy", "happy", True),
    "talk": ("talk", "default", False),
    "point": ("talk", "happy", False),
    "think": ("think", "default", False),
    "sorry": ("sorry", "default", False),
}

# 팔 자세 → 팔 막대 경로. 색은 밥을 따른다.
ARMS = {
    "default": ["M36 266 L22 284", "M264 266 L278 284"],
    "happy": ["M258 214 Q298 204 290 164"],
}


def arms(kind, fill=RICE):
    return "".join(stub(d, 24, fill) for d in ARMS[kind])

MARKS = f'''
  <!-- 강조 표시 -->
  <g stroke="{YELLOW}" stroke-width="8" stroke-linecap="round">
    <path d="M284 130 L286 112"/>
    <path d="M298 140 L311 127"/>
    <path d="M303 157 L318 154"/>
  </g>'''


def body_clip_def(body):
    """몸통 모양 clipPath. defs 안에 넣는다."""
    return f'<clipPath id="bodyClip"><path d="{body}"/></clipPath>'


def ellipse(e, color):
    cx, cy, rx, ry, rot = e
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})" fill="{color}"/>'


def rice_pattern(rice):
    """몸 위의 선·무늬: 흰 밥은 밥알 결 선, 나머지는 무늬 타원. bodyClip 안, 김보다 먼저 그린다."""
    r = RICES[rice]
    if r["pattern"] is None:
        return "".join(
            f'<path d="{d}" fill="none" stroke="{r["pattern_color"]}" stroke-width="4" stroke-linecap="round"/>'
            for d in GRAIN_LINES)
    return "".join(ellipse(e, r["pattern_color"]) for e in r["pattern"])


def body_layers(body, rice="plain_rice"):
    """밥, 무늬(또는 밥알 결), 김, 몸통 외곽선. body_clip_def가 함께 있어야 한다."""
    return f'''<path d="{body}" fill="{RICES[rice]["fill"]}"/>
  <g clip-path="url(#bodyClip)">
    {rice_pattern(rice)}
    <rect x="96" y="232" width="108" height="114" fill="{NORI}" stroke="{LINE}" stroke-width="4"/>
  </g>
  <path d="{body}" fill="none" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>'''


def cheeks(color=CHEEK):
    return f'''
  <!-- 볼 -->
  <ellipse cx="94" cy="190" rx="15" ry="10" fill="{color}"/>
  <ellipse cx="206" cy="190" rx="15" ry="10" fill="{color}"/>'''


def face(kind):
    """표정 (눈, 입). 볼은 밥마다 색이 달라 본체 레이어로 옮겼다 (giri-companion.md 4.3의 6)."""
    return f'''
  <!-- 얼굴 -->{FACES[kind]}'''


def base(kind, rice="plain_rice"):
    """본체 레이어: 그림자, 다리, 팔, 몸, 무늬, 김, 외곽선, 볼, 빨간 두건 (reward-flow.md 8.1).
    팔은 자세마다, 몸·팔·다리 색과 무늬·볼 색은 밥마다 다르다."""
    body = body_path()
    fill = RICES[rice]["fill"]
    return f'''
  <!-- 그림자 -->
  <ellipse cx="150" cy="346" rx="90" ry="9" fill="{SHADOW}" opacity="0.8"/>

  <!-- 다리 -->
  {stub("M128 314 L128 332", 36, fill)}
  {stub("M172 314 L172 332", 36, fill)}

  <!-- 팔 -->
  {arms(kind, fill)}

  <!-- 몸통 -->
  {body_layers(body, rice)}
{cheeks(RICES[rice]["cheek"])}
{scarf()}'''


def rice_thumb(rice):
    """밥 썸네일: 몸 바탕 + 무늬(또는 결 선) + 김 + 몸 외곽선만 (brief.md 2.6). 얼굴·볼·팔·다리·두건·그림자는 없다."""
    return body_layers(body_path(), rice)


def wrap(inner, view_box="-30 0 360 360", defs=""):
    w, h = view_box.split()[2:]
    defs_block = f"""
  <defs>
    {defs}
  </defs>
""" if defs else ""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_box}" width="{w}" height="{h}">{defs_block}
{inner}
</svg>
'''


def svg(face_kind, arm_kind=None, sparkles=None, rice="plain_rice"):
    """완성 그림. 앱이 겹치는 레이어(본체, 머리, 얼굴, 반짝임)를 기본 차림(요리사 모자)으로 이은 것이다.
    팔과 반짝임을 주지 않으면 얼굴 이름을 따른다(default, happy)."""
    arm_kind = arm_kind or face_kind
    sparkles = (face_kind == "happy") if sparkles is None else sparkles
    body = body_path()
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-30 0 360 360" width="360" height="360">
  <defs>
    {body_clip_def(body)}
  </defs>
{base(arm_kind, rice)}
{hat()}
{face(face_kind)}
{MARKS if sparkles else ""}
</svg>
'''


def legacy_svg(kind):
    """2026-11-16 전의 완성 그림(볼이 얼굴 레이어, 두건이 따로 있던 순서). 그린 픽셀 비교의 기준이다."""
    body = body_path()
    old_face = cheeks() + face(kind)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-30 0 360 360" width="360" height="360">
  <defs>
    {body_clip_def(body)}
  </defs>
  <ellipse cx="150" cy="346" rx="90" ry="9" fill="{SHADOW}" opacity="0.8"/>
  {stub("M128 314 L128 332", 36)}
  {stub("M172 314 L172 332", 36)}
  {arms(kind)}
  {body_layers(body)}
{scarf()}
{hat()}
{old_face}
{MARKS if kind == "happy" else ""}
</svg>
'''


# 꾸미기 레이어 (reward-flow.md 8.1). 모두 viewBox -30 0 360 360의 같은 정사각형이라 겹치기만 하면 맞는다.
# 썸네일은 종류별 viewBox로 잘라 낸 별도 파일이다 (brief.md 2.6).
THUMB_VIEWBOX = {
    "top": "57 -16 190 190",
    "rice": "6 72 288 288",
}

# 기본 차림의 머리 아이템. 지금 그림의 함수를 그대로 레이어로 쓴다. 다른 머리·속재료·배경 그림은 place_item_art.py가 만든다.
DEFAULT_ITEMS = {
    "chef_hat": ("top", hat),
}


def base_asset_name(kind, rice):
    """GiriBase{자세}, 흰 밥이 아니면 뒤에 -{밥 id}."""
    return f"GiriBase{kind.title()}" + ("" if rice == "plain_rice" else f"-{rice}")


def base_file_name(kind, rice):
    return f"layers/giri-base-{kind}" + ("" if rice == "plain_rice" else f"-{rice}") + ".svg"


def layer_files():
    """(문서 안 상대 경로, 에셋 이름, SVG 내용)."""
    files = []
    clip = body_clip_def(body_path())
    # 본체는 팔 자세 × 밥마다, 얼굴은 표정마다 하나 (giri-companion.md 4.3, brief.md 2.4.2)
    for rice in RICES:
        for kind in ARMS:
            files.append((base_file_name(kind, rice), base_asset_name(kind, rice), wrap(base(kind, rice), defs=clip)))
        files.append((f"items/{rice}-thumb.svg", f"ItemThumb-{rice}",
                      wrap(rice_thumb(rice), THUMB_VIEWBOX["rice"], defs=clip)))
    for kind in FACES:
        files.append((f"layers/giri-face-{kind}.svg", f"GiriFace{kind.title()}", wrap(face(kind))))
    files.append(("layers/giri-sparkles.svg", "GiriSparkles", wrap(MARKS)))
    for item_id, (slot, draw) in DEFAULT_ITEMS.items():
        files.append((f"items/{item_id}.svg", f"Item-{item_id}", wrap(draw())))
        files.append((f"items/{item_id}-thumb.svg", f"ItemThumb-{item_id}", wrap(draw(), THUMB_VIEWBOX[slot])))
    return files


# 2026-11-16 개편으로 쓰지 않게 된 산출물. 실행할 때 지운다.
OBSOLETE_FILES = ["layers/giri-sparkles-left.svg", "items/red_scarf.svg", "items/red_scarf-thumb.svg"]
OBSOLETE_ASSETS = ["GiriSparklesLeft", "Item-red_scarf", "ItemThumb-red_scarf"]


def write_imageset(name, filename, content):
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.svg"):
        if old.name != filename:
            old.unlink()
    (folder / filename).write_text(content, encoding="utf-8")
    (folder / "Contents.json").write_text("""{
  "images" : [
    {
      "filename" : "%s",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true,
    "template-rendering-intent" : "original"
  }
}
""" % filename, encoding="utf-8")


# ---- 검사 (brief.md 2.4.2의 5) ----

def luminance(hex_color):
    """WCAG 상대 휘도."""
    h = hex_color.lstrip("#")
    def ch(v):
        c = int(v, 16) / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(h[i:i + 2]) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def hue_saturation(hex_color):
    import colorsys
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    return hh * 360, ss


def body_polygon(steps=8):
    """몸 외곽선(이차 곡선 이음)을 점 목록으로 편다."""
    import re
    nums = [float(v) for v in re.findall(r"-?\d+\.?\d*", body_path())]
    x0, y0 = nums[0], nums[1]
    pts = [(x0, y0)]
    rest = nums[2:]
    for i in range(0, len(rest), 4):
        cx, cy, x1, y1 = rest[i:i + 4]
        for k in range(1, steps + 1):
            t = k / steps
            pts.append(((1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * x1,
                        (1 - t) ** 2 * y0 + 2 * (1 - t) * t * cy + t * t * y1))
        x0, y0 = x1, y1
    return pts


def inside(poly, x, y):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def in_ellipse(e, x, y):
    cx, cy, rx, ry, rot = e
    a = math.radians(rot)
    dx, dy = x - cx, y - cy
    u = dx * math.cos(a) + dy * math.sin(a)
    v = -dx * math.sin(a) + dy * math.cos(a)
    return (u / rx) ** 2 + (v / ry) ** 2 <= 1


def ellipse_bbox(e):
    cx, cy, rx, ry, rot = e
    a = math.radians(rot)
    hw = math.hypot(rx * math.cos(a), ry * math.sin(a))
    hh = math.hypot(rx * math.sin(a), ry * math.cos(a))
    return cx - hw, cy - hh, cx + hw, cy + hh


def check_rices():
    """대비 네 가지와 볼·무늬 대비, 금지 색상, 얼굴 금지 구역 안의 조각 수, 무늬 면적 비율, 조각의 가장 작은 폭.
    기준을 못 넘으면 AssertionError (brief.md 2.4.3, 2.4.4)."""
    poly = body_polygon()
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    body_px = [(x + 0.5, y + 0.5) for x in range(int(min(xs)), int(max(xs)) + 1)
               for y in range(int(min(ys)), int(max(ys)) + 1) if inside(poly, x + 0.5, y + 0.5)]
    body_area = len(body_px)
    failures = []
    for rid, r in RICES.items():
        fill = r["fill"]
        lum = luminance(fill)
        c_line, c_nori, c_red = contrast(fill, LINE), contrast(fill, NORI), contrast(fill, RED)
        c_cheek = contrast(fill, r["cheek"])
        hue, sat = hue_saturation(fill)
        line = (f"{rid:12} 바탕 {fill} 휘도 {lum:.2f} | 외곽선 {c_line:.1f} 김 {c_nori:.1f} 두건 {c_red:.1f} "
                f"볼 {c_cheek:.2f}")
        checks = [(lum >= 0.50, "바탕 휘도 0.50 미만"), (c_line >= 7, "외곽선 대비 7 미만"),
                  (c_nori >= 4.5, "김 대비 4.5 미만"), (c_red >= 2, "두건 대비 2 미만"),
                  (c_cheek >= 1.4, "볼 대비 1.4 미만"),
                  (not ((125 <= hue <= 160 and sat >= 0.25) or hue >= 330), "바탕 색상 금지 범위")]
        if r["pattern"]:
            color = r["pattern_color"]
            c_pat = contrast(fill, color)
            dark = luminance(color) < 0.15
            zone = (72, 130 if dark else 150, 228, 214)
            in_zone = sum(1 for e in r["pattern"]
                          if not (ellipse_bbox(e)[2] < zone[0] or ellipse_bbox(e)[0] > zone[2]
                                  or ellipse_bbox(e)[3] < zone[1] or ellipse_bbox(e)[1] > zone[3]))
            covered = sum(1 for x, y in body_px if any(in_ellipse(e, x, y) for e in r["pattern"]))
            ratio = covered / body_area
            elongated = [max(e[2], e[3]) >= 1.5 * min(e[2], e[3]) for e in r["pattern"]]
            min_short = min(2 * min(e[2], e[3]) for e in r["pattern"])
            min_long = min(2 * max(e[2], e[3]) for e in r["pattern"])
            size_ok = all((2 * max(e[2], e[3]) >= 16 and 2 * min(e[2], e[3]) >= 8) if el
                          else 2 * min(e[2], e[3]) >= 16 for e, el in zip(r["pattern"], elongated))
            line += (f" | 무늬 {color} 대비 {c_pat:.2f}, {len(r['pattern'])}조각, 금지 구역 안 {in_zone}, "
                     f"면적 {ratio:.1%}, 가장 작은 폭 {min_short:g}(긴 쪽 {min_long:g})")
            checks += [(c_pat >= 1.6, "무늬 대비 1.6 미만"), (in_zone == 0, "얼굴 금지 구역에 무늬"),
                       (len(r["pattern"]) <= 12, "무늬 12조각 넘음"), (ratio <= 0.15, "무늬 면적 15% 넘음"),
                       (size_ok, "무늬 조각 폭 부족")]
            if dark:
                checks.append((all(e[2] >= e[3] and abs(e[4]) <= 45 for e in r["pattern"]),
                               "어두운 무늬가 세로로 김"))
        else:
            line += " | 결 선"
        print(line)
        failures += [f"{rid}: {msg}" for ok, msg in checks if not ok]
    print(f"몸 면적 {body_area}")
    assert not failures, "밥 검사 실패: " + ", ".join(failures)


def check_pixels_match():
    """흰 밥 기본 차림을 새 레이어 순서(볼·두건이 본체 안)로 겹친 결과가 옛 완성 그림과 같은 픽셀인지 본다.
    볼 순서가 바뀌므로 문자열이 아니라 그린 픽셀로 비교한다 (brief.md 2.4.2의 5). Pillow가 없으면 건너뛴다."""
    try:
        from PIL import Image, ImageChops
    except ImportError:
        print("Pillow가 없어 픽셀 비교를 건너뜀 (.venv/bin/python으로 실행)")
        return
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        exe = tmp / "svg_to_png"
        subprocess.run(["swiftc", "-O", str(Path(__file__).resolve().parent / "svg_to_png.swift"), "-o", str(exe)],
                       check=True)
        for kind in ARMS:
            pngs = []
            for name, content in (("new", svg(kind)), ("old", legacy_svg(kind))):
                src, out = tmp / f"{kind}-{name}.svg", tmp / f"{kind}-{name}.png"
                src.write_text(content, encoding="utf-8")
                subprocess.run([str(exe), str(src), str(out), "720"], check=True)
                pngs.append(Image.open(out).convert("RGB"))
            diff = ImageChops.difference(*pngs)
            changed = sum(1 for p in diff.get_flattened_data() if max(p) > 8)
            print(f"픽셀 비교 {kind}: 다른 픽셀 {changed} / {720 * 720}")
            assert changed == 0, f"{kind}: 새 레이어 순서의 그림이 옛 완성 그림과 다름"


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    check_rices()
    check_pixels_match()
    for name, (face_kind, arm_kind, sparkles) in EXPRESSIONS.items():
        (OUT / f"onigiri-{name}.svg").write_text(svg(face_kind, arm_kind, sparkles), encoding="utf-8")
        print("wrote", OUT / f"onigiri-{name}.svg")
    for rel, asset, content in layer_files():
        path = OUT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        write_imageset(asset, path.name, content)
        print("wrote", path, "->", asset)
    for rel in OBSOLETE_FILES:
        if (OUT / rel).exists():
            (OUT / rel).unlink()
            print("removed", OUT / rel)
    for asset in OBSOLETE_ASSETS:
        folder = ASSETS / f"{asset}.imageset"
        if folder.exists():
            import shutil
            shutil.rmtree(folder)
            print("removed", folder)
