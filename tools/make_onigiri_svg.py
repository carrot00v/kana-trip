"""오니기리 캐릭터 SVG를 만든다.

밥알이 뭉친 울퉁불퉁한 외곽선은 손으로 그리기 어려워서 계산으로 만든다.
실행: python3 tools/make_onigiri_svg.py   (.venv/bin/python이면 그린 픽셀 비교까지 한다. Pillow 필요)
산출물: docs/design/character/onigiri-{default,happy,talk,point,think,sorry}.svg (확인용 완성 그림)
        docs/design/character/parts/ (Lottie 부위를 하나씩 본 확인용 SVG, docs/design/giri-companion.md 4.4, 5.9.1)
        docs/design/character/layers/ (예전 레이어 SVG. 확인용으로만 남긴다), items/ (꾸미기 아이템, reward-flow.md 8.1)
        docs/design/character/items/chef_hat.png (1080px, Lottie 이미지 슬롯·안드로이드용, giri-companion.md 5.7)
        KanaTrip/Assets.xcassets의 아이템 에셋 (Item-chef_hat, ItemThumb-*)
앱의 기리는 이 스크립트의 부위 함수로 tools/build_giri_lottie.py가 만드는 KanaTrip/Resources/giri.lottie.json이다(2026-11-21).

밥 바꾸기 (docs/design/item-art/brief.md 2.4): 본체(그림자, 다리, 팔, 몸, 무늬, 김, 외곽선, 볼, 빨간 두건)의 색과 무늬를
밥 정의 표 RICES로 바꾼다. 밥 색·무늬 값은 이 표에만 둔다(rewards.json에는 넣지 않는다). 실행할 때 대비와 얼굴 금지 구역을
검사해 출력하고, 기준을 못 넘으면 멈춘다.

부위 (giri-companion.md 4.4): 본체를 shadow(), leg(), arm(), body_fill(), pattern(), body_front()로 나눈다. Lottie에는
마스크·매트가 없어 무늬와 김은 몸 경로로 미리 잘라 낸 경로로 그린다(bodyClip을 쓰지 않는다). 부위를 이은 그림이
bodyClip으로 그리던 예전 그림과 같은 픽셀인지 check_pixels_match()가 본다.
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
            f'<path class="rice" d="{d}" stroke="{fill}" stroke-width="{width - 2 * SW}" stroke-linecap="round" fill="none"/>')


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


def scarf():
    return f'''
  <!-- 두건: 오른쪽이 올라가게 비스듬히 -->
  <path d="M28 224 Q150 252 272 204 L274 226 Q150 278 30 248Z" fill="{RED}" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
  <path d="M44 238 L2 246 L30 264Z" fill="{RED}" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
  <path d="M52 246 L40 292 L70 262Z" fill="{RED}" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
  <circle cx="48" cy="242" r="13" fill="{RED}" stroke="{LINE}" stroke-width="{SW}"/>'''


EYE_L = f'<ellipse cx="114" cy="170" rx="7" ry="10" fill="{LINE}"/>'
EYE_R = f'<ellipse cx="186" cy="170" rx="7" ry="10" fill="{LINE}"/>'

_CHEVRON_R = (f'<path d="M196 161 L180 170 L196 179" fill="none" stroke="{LINE}" stroke-width="6" '
              f'stroke-linecap="round" stroke-linejoin="round"/>')

# 표정 → (눈, 입). 앱(Lottie)은 표정마다 레이어 `face_{표정}` 하나를 켜고, 깜빡임은 눈 묶음의 크기로 한다
# (giri-companion.md 4.4.1, 5.9.1). 눈 묶음 이름은 깜빡이는 얼굴이 `eyes`, 감은 눈(웃음의 윙크, 아쉬움)이 `eyes_fixed`.
FACE_PARTS = {
    "default": (
        EYE_L + EYE_R,
        f'<path d="M140 186 Q150 196 160 186" fill="none" stroke="{LINE}" stroke-width="5.5" stroke-linecap="round"/>'),
    "happy": (
        EYE_L + _CHEVRON_R,
        f'<path d="M135 180 L165 180 Q165 207 150 207 Q135 207 135 180Z" fill="{LINE}" stroke="{LINE}" stroke-width="4" '
        f'stroke-linejoin="round"/>'
        f'<path d="M140 198 Q150 189 160 198 Q157 205 150 205 Q143 205 140 198Z" fill="{TONGUE}"/>'),
    # 기리 동행 표정 (docs/design/giri-companion.md 4.2)
    "talk": (
        EYE_L + EYE_R,
        f'<path d="M140 184 Q150 181 160 184 Q160 200 150 200 Q140 200 140 184Z" fill="{LINE}" stroke="{LINE}" stroke-width="3" '
        f'stroke-linejoin="round"/>'
        f'<path d="M143 194 Q150 189 157 194 Q155 199 150 199 Q145 199 143 194Z" fill="{TONGUE}"/>'),
    "think": (
        f'<ellipse cx="118" cy="167" rx="6" ry="9" fill="{LINE}"/><ellipse cx="190" cy="167" rx="6" ry="9" fill="{LINE}"/>',
        f'<path d="M145 191 Q152 187 160 189" fill="none" stroke="{LINE}" stroke-width="5.5" stroke-linecap="round"/>'),
    "sorry": (
        f'<path d="M104 161 L120 170 L104 179" fill="none" stroke="{LINE}" stroke-width="6" stroke-linecap="round" '
        f'stroke-linejoin="round"/>' + _CHEVRON_R,
        f'<path d="M139 193 Q144.5 187 150 193 Q155.5 199 161 193" fill="none" stroke="{LINE}" stroke-width="5" '
        f'stroke-linecap="round"/>'),
}
BLINKING_FACES = ("default", "talk", "think")
# 깜빡임(눈 묶음 세로 크기)의 축. 생각 얼굴은 눈이 오른쪽 위를 본다 (4.4.1).
EYES_PIVOT = {"think": (154, 167)}
EYES_PIVOT_DEFAULT = (150, 170)


def eyes_id(kind):
    return "eyes" if kind in BLINKING_FACES else "eyes_fixed"


FACES = {kind: f'\n  <g id="{eyes_id(kind)}">{eyes}</g>\n  <g id="mouth">{mouth}</g>'
         for kind, (eyes, mouth) in FACE_PARTS.items()}

# 확인용 완성 그림: 이름 → (얼굴, 팔 자세, 반짝임) (giri-companion.md 4.1). 앱은 Lottie 부위를 켜고 끈다.
EXPRESSIONS = {
    "default": ("default", "default", False),
    "happy": ("happy", "happy", True),
    "talk": ("talk", "default", False),
    "point": ("talk", "happy", False),
    "think": ("think", "default", False),
    "sorry": ("sorry", "default", False),
}

# 팔 막대 경로. 색은 밥을 따른다. 왼팔은 모든 자세에 있다 (giri-companion.md 4.4.3, 5.9.1).
ARMS = {"l": "M36 266 L22 284", "r_down": "M264 266 L278 284", "r_up": "M258 214 Q298 204 290 164"}
# 팔 자세 → 팔 목록. 이름은 예전 레이어 파일(giri-base-{자세}.svg)과 맞춘다. default = 오른팔 내림, happy = 오른팔 듦.
POSES = {"default": ["l", "r_down"], "happy": ["l", "r_up"]}
# 2026-11-21 전의 팔 자세. 웃음·손 들기에 왼팔이 없었다. 픽셀 비교의 기준(legacy_svg)에만 쓴다.
LEGACY_POSES = {"default": ["l", "r_down"], "happy": ["r_up"]}
# 웃음·손 들기에 새로 생긴 왼팔이 보이는 자리 (x0, y0, x1, y1). 듦 자세의 옛 그림 비교는 이 상자 밖에서만 한다 (5.9.1).
LEFT_ARM_BOX = (8, 252, 50, 298)
LEGS = {"l": "M128 314 L128 332", "r": "M172 314 L172 332"}


def arm(key, fill=RICE):
    return stub(ARMS[key], 24, fill)


def arms(kind, fill=RICE, poses=None):
    return "".join(arm(key, fill) for key in (poses or POSES)[kind])


MARKS = f'''
  <!-- 강조 표시 -->
  <g stroke="{YELLOW}" stroke-width="8" stroke-linecap="round">
    <path d="M284 130 L286 112"/>
    <path d="M298 140 L311 127"/>
    <path d="M303 157 L318 154"/>
  </g>'''


def body_clip_def(body):
    """몸통 모양 clipPath. defs 안에 넣는다. 밥 썸네일과 픽셀 비교의 기준 그림에만 쓴다."""
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


NORI_RECT = (96, 232, 108, 114)  # x, y, 폭, 높이. 외곽선 굵기 4
NORI_STROKE = 4


def body_layers(body, rice="plain_rice"):
    """밥, 무늬(또는 밥알 결), 김, 몸통 외곽선을 bodyClip으로 자른 예전 방식. body_clip_def가 함께 있어야 한다.
    밥 썸네일과 앱 아이콘, 부위 그림의 픽셀 비교 기준이 쓴다."""
    x, y, w, h = NORI_RECT
    return f'''<path d="{body}" fill="{RICES[rice]["fill"]}"/>
  <g clip-path="url(#bodyClip)">
    {rice_pattern(rice)}
    <rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{NORI}" stroke="{LINE}" stroke-width="{NORI_STROKE}"/>
  </g>
  <path d="{body}" fill="none" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>'''


def cheeks(color=CHEEK):
    return f'''
  <!-- 볼 -->
  <ellipse class="cheek" cx="94" cy="190" rx="15" ry="10" fill="{color}"/>
  <ellipse class="cheek" cx="206" cy="190" rx="15" ry="10" fill="{color}"/>'''


def face(kind):
    """표정 (눈 묶음, 입 묶음). 볼은 밥마다 색이 달라 본체로 옮겼다 (giri-companion.md 4.3의 6)."""
    return f'''
  <!-- 얼굴 -->{FACES[kind]}'''


# ---- 미리 자르기 (giri-companion.md 5.9.1) ----
# Lottie에는 clipPath가 없어(마스크·매트를 쓰지 않는다, 5.1) 몸 경로와의 교집합을 다각형으로 계산해 경로로 낸다.
# 몸 외곽선(굵기 6)이 몸 경로 양쪽 3을 덮으므로, 자른 가장자리를 다각형으로 근사한 차이는 외곽선 아래에 숨는다.
CLIP_STEPS = 16       # 몸 외곽선 이차 곡선 하나를 펴는 점 수
ELLIPSE_POINTS = 128  # 잘린 무늬 타원의 다각형 점 수 (반지름 36에서 오차 0.011)
KAPPA = 0.5522847498  # 원을 3차 곡선 넷으로 그리는 핸들 비율


def fmt(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def polygon_d(pts):
    return "M" + " L".join(f"{fmt(x)} {fmt(y)}" for x, y in pts) + "Z"


def ellipse_points(e, n=ELLIPSE_POINTS):
    cx, cy, rx, ry, rot = e
    a = math.radians(rot)
    out = []
    for k in range(n):
        t = 2 * math.pi * k / n
        u, v = rx * math.cos(t), ry * math.sin(t)
        out.append((cx + u * math.cos(a) - v * math.sin(a), cy + u * math.sin(a) + v * math.cos(a)))
    return out


def ellipse_d(e):
    """회전한 타원을 3차 곡선 넷의 경로로 (Lottie의 타원은 회전이 없다)."""
    cx, cy, rx, ry, rot = e
    a = math.radians(rot)

    def p(u, v):
        return cx + u * math.cos(a) - v * math.sin(a), cy + u * math.sin(a) + v * math.cos(a)
    k = KAPPA
    # 4분의 1 호마다 (시작 핸들, 끝 핸들, 끝 점) (타원 자신의 좌표)
    arcs = [((rx, k * ry), (k * rx, ry), (0, ry)), ((-k * rx, ry), (-rx, k * ry), (-rx, 0)),
            ((-rx, -k * ry), (-k * rx, -ry), (0, -ry)), ((k * rx, -ry), (rx, -k * ry), (rx, 0))]
    d = "M{} {}".format(*map(fmt, p(rx, 0)))
    for c1, c2, end in arcs:
        d += " C{} {} {} {} {} {}".format(*map(fmt, (*p(*c1), *p(*c2), *p(*end))))
    return d + "Z"


def clip_convex(subject, window):
    """Sutherland–Hodgman: subject 다각형(몸, 오목해도 된다)을 볼록한 window 다각형으로 자른다 = 둘의 교집합."""
    area = sum(window[i][0] * window[(i + 1) % len(window)][1] - window[(i + 1) % len(window)][0] * window[i][1]
               for i in range(len(window)))
    sign = 1 if area > 0 else -1
    out = subject
    for i in range(len(window)):
        a, b = window[i], window[(i + 1) % len(window)]

        def side(p):
            return sign * ((b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]))

        def cross(p, q):
            sp, sq = side(p), side(q)
            t = sp / (sp - sq)
            return p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t
        src, out = out, []
        for j in range(len(src)):
            p, q = src[j], src[(j + 1) % len(src)]
            if side(q) >= 0:
                if side(p) < 0:
                    out.append(cross(p, q))
                out.append(q)
            elif side(p) >= 0:
                out.append(cross(p, q))
        if not out:
            break
    return out


def clip_polygon():
    pts = body_polygon(CLIP_STEPS)
    return pts[:-1] if pts[0] == pts[-1] else pts


def distance_outside(pts):
    """점들이 몸 경로 밖으로 나간 가장 큰 거리 (모두 안이면 0)."""
    poly = clip_polygon()
    worst = 0.0
    for x, y in pts:
        if inside(poly, x, y):
            continue
        best = min(segment_distance((x, y), poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))
        worst = max(worst, best)
    return worst


def segment_distance(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dy * dy
    t = 0 if L2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)


def grain_points(d, width=4, n=24):
    """결 선(상대 q 한 번) 중심선 위 점들을 굵기 반만큼 사방으로 넓힌 것."""
    import re
    x0, y0, qx, qy, x1, y1 = (float(v) for v in re.findall(r"-?\d+\.?\d*", d))
    cx, cy, ex, ey = x0 + qx, y0 + qy, x0 + x1, y0 + y1
    r = width / 2
    out = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * ex
        y = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * cy + t * t * ey
        out += [(x + r * math.cos(a), y + r * math.sin(a)) for a in (k * math.pi / 4 for k in range(8))]
    return out


def pattern(rice):
    """몸 경로로 미리 자른 무늬 (4.4.1의 7). 흰 밥은 결 선 6개, ごま는 깨 9알, やきおにぎり는 그을림 5조각.
    몸 경로 밖으로 외곽선 반 굵기(3)보다 덜 나가는 조각은 외곽선 아래에 숨으므로 자르지 않는다(결 선, 깨).
    더 나가는 조각(그을림)은 몸 다각형과의 교집합 다각형으로 낸다."""
    r = RICES[rice]
    color = r["pattern_color"]
    if r["pattern"] is None:
        out = []
        for d in GRAIN_LINES:
            assert distance_outside(grain_points(d)) < SW / 2, f"결 선 {d}이 외곽선 밖으로 나감"
            out.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="4" stroke-linecap="round"/>')
        return "".join(out)
    out = []
    for e in r["pattern"]:
        if distance_outside(ellipse_points(e)) < SW / 2:
            out.append(f'<path d="{ellipse_d(e)}" fill="{color}"/>')
        else:
            out.append(f'<path d="{polygon_d(clip_convex(clip_polygon(), ellipse_points(e)))}" fill="{color}"/>')
    return "".join(out)


def rect_points(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def nori():
    """몸 경로로 미리 자른 김: 외곽선(굵기 4, 모서리 각짐) 자리를 진갈색으로, 그 안을 김 색으로."""
    x, y, w, h = NORI_RECT
    s = NORI_STROKE / 2
    poly = clip_polygon()
    outer = clip_convex(poly, rect_points(x - s, y - s, x + w + s, y + h + s))
    inner = clip_convex(poly, rect_points(x + s, y + s, x + w - s, y + h - s))
    return f'<path d="{polygon_d(outer)}" fill="{LINE}"/><path d="{polygon_d(inner)}" fill="{NORI}"/>'


# ---- 부위 (giri-companion.md 4.4.1). 아래에서 위 순서 ----

def shadow():
    return f'''
  <!-- 그림자 -->
  <ellipse cx="150" cy="346" rx="90" ry="9" fill="{SHADOW}" opacity="0.8"/>'''


def leg(side, fill=RICE):
    return stub(LEGS[side], 36, fill)


def body_fill(rice="plain_rice"):
    return f'<path class="rice" d="{body_path()}" fill="{RICES[rice]["fill"]}"/>'


def body_front(rice="plain_rice"):
    """미리 자른 김, 몸 외곽선, 볼 두 개, 빨간 두건 (4.4.1의 8)."""
    return f'''
  {nori()}
  <path d="{body_path()}" fill="none" stroke="{LINE}" stroke-width="{SW}" stroke-linejoin="round"/>
{cheeks(RICES[rice]["cheek"])}
{scarf()}'''


def base(kind, rice="plain_rice", poses=None):
    """본체: 부위를 4.4.1 순서로 이은 것 (그림자, 다리, 팔, 몸 면, 무늬, 김·외곽선·볼·두건).
    팔은 자세마다, 몸·팔·다리 색과 무늬·볼 색은 밥마다 다르다."""
    fill = RICES[rice]["fill"]
    return f'''{shadow()}

  <!-- 다리 -->
  {leg("l", fill)}
  {leg("r", fill)}

  <!-- 팔 -->
  {arms(kind, fill, poses)}

  <!-- 몸통 -->
  {body_fill(rice)}
  {pattern(rice)}
{body_front(rice)}'''


def clip_reference_base(kind, rice="plain_rice", poses=None):
    """미리 자르기 전의 본체 (bodyClip). 픽셀 비교의 기준이다. body_clip_def가 함께 있어야 한다."""
    fill = RICES[rice]["fill"]
    return f'''{shadow()}
  {leg("l", fill)}
  {leg("r", fill)}
  {arms(kind, fill, poses)}
  {body_layers(body_path(), rice)}
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
    """완성 그림. 앱이 Lottie로 그리는 부위(본체, 머리, 얼굴, 반짝임)를 기본 차림(요리사 모자)으로 이은 것이다.
    팔과 반짝임을 주지 않으면 얼굴 이름을 따른다(default, happy)."""
    arm_kind = arm_kind or face_kind
    sparkles = (face_kind == "happy") if sparkles is None else sparkles
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-30 0 360 360" width="360" height="360">
{base(arm_kind, rice)}
{hat()}
{face(face_kind)}
{MARKS if sparkles else ""}
</svg>
'''


def clip_reference_svg(face_kind, arm_kind, sparkles, rice):
    """svg()와 같은 그림을 bodyClip으로 그린 것 (미리 자르기 검사의 기준)."""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-30 0 360 360" width="360" height="360">
  <defs>
    {body_clip_def(body_path())}
  </defs>
{clip_reference_base(arm_kind, rice)}
{hat()}
{face(face_kind)}
{MARKS if sparkles else ""}
</svg>
'''


def legacy_svg(kind):
    """2026-11-16 전의 완성 그림(볼이 얼굴 레이어, 두건이 따로 있던 순서, 웃음에 왼팔 없음). 그린 픽셀 비교의 기준이다."""
    body = body_path()
    old_face = cheeks() + face(kind)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-30 0 360 360" width="360" height="360">
  <defs>
    {body_clip_def(body)}
  </defs>
  <ellipse cx="150" cy="346" rx="90" ry="9" fill="{SHADOW}" opacity="0.8"/>
  {stub("M128 314 L128 332", 36)}
  {stub("M172 314 L172 332", 36)}
  {arms(kind, poses=LEGACY_POSES)}
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
# Lottie 이미지 슬롯에 꽂는 아이템 그림의 한 변 (360 좌표 × 3, giri-companion.md 5.7).
ITEM_PNG_SIDE = 1080


def base_file_name(kind, rice):
    return f"layers/giri-base-{kind}" + ("" if rice == "plain_rice" else f"-{rice}") + ".svg"


def layer_files():
    """확인용 레이어 SVG (문서 안 상대 경로, SVG 내용). 앱 에셋으로 넣지 않는다 (5.9.1)."""
    files = []
    for rice in RICES:
        for kind in POSES:
            files.append((base_file_name(kind, rice), wrap(base(kind, rice))))
    for kind in FACES:
        files.append((f"layers/giri-face-{kind}.svg", wrap(face(kind))))
    files.append(("layers/giri-sparkles.svg", wrap(MARKS)))
    return files


def part_files():
    """Lottie 부위를 하나씩 본 확인용 SVG (parts/, 5.9.1). 모두 viewBox -30 0 360 360."""
    files = [("parts/giri-shadow.svg", shadow()),
             ("parts/giri-leg-l.svg", leg("l")), ("parts/giri-leg-r.svg", leg("r")),
             ("parts/giri-arm-l.svg", arm("l")), ("parts/giri-arm-r-down.svg", arm("r_down")),
             ("parts/giri-arm-r-up.svg", arm("r_up")), ("parts/giri-body-fill.svg", body_fill())]
    files += [(f"parts/giri-pattern-{rice}.svg", pattern(rice)) for rice in RICES]
    files += [(f"parts/giri-body-front-{rice}.svg", body_front(rice)) for rice in RICES]
    files += [(f"parts/giri-face-{kind}.svg", face(kind)) for kind in FACES]
    files.append(("parts/giri-sparkles.svg", MARKS))
    return [(rel, wrap(inner)) for rel, inner in files]


def item_files():
    """(문서 안 상대 경로, 에셋 이름, SVG 내용). 기본 차림 아이템과 밥 썸네일."""
    files = []
    clip = body_clip_def(body_path())
    for rice in RICES:
        files.append((f"items/{rice}-thumb.svg", f"ItemThumb-{rice}",
                      wrap(rice_thumb(rice), THUMB_VIEWBOX["rice"], defs=clip)))
    for item_id, (slot, draw) in DEFAULT_ITEMS.items():
        files.append((f"items/{item_id}.svg", f"Item-{item_id}", wrap(draw())))
        files.append((f"items/{item_id}-thumb.svg", f"ItemThumb-{item_id}", wrap(draw(), THUMB_VIEWBOX[slot])))
    return files


# 쓰지 않게 된 산출물. 실행할 때 지운다. 2026-11-16 개편, 2026-11-21 Lottie로 바꾼 뒤의 레이어 에셋(5.9.1).
OBSOLETE_FILES = ["layers/giri-sparkles-left.svg", "items/red_scarf.svg", "items/red_scarf-thumb.svg"]
OBSOLETE_ASSETS = ["GiriSparklesLeft", "Item-red_scarf", "ItemThumb-red_scarf",
                   "GiriBaseDefault", "GiriBaseHappy", "GiriBaseDefault-goma", "GiriBaseHappy-goma",
                   "GiriBaseDefault-yakionigiri", "GiriBaseHappy-yakionigiri",
                   "GiriFaceDefault", "GiriFaceHappy", "GiriFaceTalk", "GiriFaceThink", "GiriFaceSorry", "GiriSparkles"]


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


def svg_renderer(tmp):
    """tools/svg_to_png.swift를 컴파일한 실행 파일 경로."""
    import subprocess
    exe = tmp / "svg_to_png"
    subprocess.run(["swiftc", "-O", str(Path(__file__).resolve().parent / "svg_to_png.swift"), "-o", str(exe)],
                   check=True)
    return exe


def render_png(exe, tmp, name, content, size=720, alpha=False):
    import subprocess
    src, out = tmp / f"{name}.svg", tmp / f"{name}.png"
    src.write_text(content, encoding="utf-8")
    subprocess.run([str(exe), str(src), str(out), str(size)] + (["alpha"] if alpha else []), check=True)
    return out


def check_pixels_match():
    """부위를 이은 그림이 예전 그림과 같은 픽셀인지 본다 (giri-companion.md 5.9.1, brief.md 2.4.2의 5).
    1) 옛 완성 그림(legacy_svg, bodyClip, 웃음에 왼팔 없음)과: 내림 자세는 전부, 듦 자세는 왼팔 자리(LEFT_ARM_BOX) 밖에서.
    2) 미리 자르기: 밥 3종 × 팔 자세 2 × 그 자세의 표정을 bodyClip으로 그린 기준 그림과 전부.
    안티에일리어싱 허용치 8을 넘는 픽셀이 0이어야 한다. Pillow가 없으면 건너뛴다."""
    try:
        from PIL import Image, ImageChops
    except ImportError:
        print("Pillow가 없어 픽셀 비교를 건너뜀 (.venv/bin/python으로 실행)")
        return
    import tempfile
    size = 720
    scale = size / 360

    def changed(a, b, skip=None):
        diff = ImageChops.difference(Image.open(a).convert("RGB"), Image.open(b).convert("RGB"))
        if skip:
            x0, y0, x1, y1 = ((v + 30 if i % 2 == 0 else v) * scale for i, v in enumerate(skip))
            diff.paste((0, 0, 0), (int(x0), int(y0), int(math.ceil(x1)), int(math.ceil(y1))))
        return sum(1 for p in diff.get_flattened_data() if max(p) > 8)

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        exe = svg_renderer(tmp)
        failures = []
        for kind in POSES:
            new = render_png(exe, tmp, f"{kind}-new", svg(kind), size)
            old = render_png(exe, tmp, f"{kind}-old", legacy_svg(kind), size)
            skip = None if POSES[kind] == LEGACY_POSES[kind] else LEFT_ARM_BOX
            n = changed(new, old, skip)
            where = "전부" if skip is None else f"왼팔 자리 {skip} 밖"
            print(f"픽셀 비교 옛 그림 {kind} ({where}): 다른 픽셀 {n} / {size * size}")
            if n:
                failures.append(f"옛 그림 {kind}")
        for rice in RICES:
            for name, (face_kind, arm_kind, sparkles) in EXPRESSIONS.items():
                if name not in ("default", "happy"):
                    continue
                new = render_png(exe, tmp, f"{rice}-{name}-new", svg(face_kind, arm_kind, sparkles, rice), size)
                ref = render_png(exe, tmp, f"{rice}-{name}-ref",
                                 clip_reference_svg(face_kind, arm_kind, sparkles, rice), size)
                n = changed(new, ref)
                print(f"픽셀 비교 미리 자르기 {rice} {name}: 다른 픽셀 {n} / {size * size}")
                if n:
                    failures.append(f"미리 자르기 {rice} {name}")
        assert not failures, "부위 그림이 기준 그림과 다름: " + ", ".join(failures)


def write_item_pngs():
    """기본 차림 아이템의 1080px PNG (Lottie 이미지 슬롯·안드로이드용, giri-companion.md 5.7). 투명 바탕."""
    import shutil
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        exe = svg_renderer(tmp)
        for item_id, (_, draw) in DEFAULT_ITEMS.items():
            png = render_png(exe, tmp, item_id, wrap(draw()), ITEM_PNG_SIDE, alpha=True)
            dest = OUT / "items" / f"{item_id}.png"
            shutil.copyfile(png, dest)
            print("wrote", dest)


if __name__ == "__main__":
    import shutil
    OUT.mkdir(parents=True, exist_ok=True)
    check_rices()
    check_pixels_match()
    for name, (face_kind, arm_kind, sparkles) in EXPRESSIONS.items():
        (OUT / f"onigiri-{name}.svg").write_text(svg(face_kind, arm_kind, sparkles), encoding="utf-8")
        print("wrote", OUT / f"onigiri-{name}.svg")
    for rel, content in layer_files() + part_files():
        path = OUT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        print("wrote", path)
    for rel, asset, content in item_files():
        path = OUT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        write_imageset(asset, path.name, content)
        print("wrote", path, "->", asset)
    write_item_pngs()
    for rel in OBSOLETE_FILES:
        if (OUT / rel).exists():
            (OUT / rel).unlink()
            print("removed", OUT / rel)
    for asset in OBSOLETE_ASSETS:
        folder = ASSETS / f"{asset}.imageset"
        if folder.exists():
            shutil.rmtree(folder)
            print("removed", folder)
