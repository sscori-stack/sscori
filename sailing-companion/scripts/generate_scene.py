#!/usr/bin/env python3
"""
콕핏 뷰 장면 파이프라인 (Gemini 이미지 생성/편집).

1. 마스터 장면 1장(900x560)을 생성한다: 콕핏 뒤에서 앞을 보는 시점, 휠·선장·마스트/돛·갑판·뱃머리·바다·섬·노을 하늘.
2. 마스터를 참조로 첨부해 "같은 구도에서 X만 남겨라" 편집 요청으로 레이어를 파생한다(같은 프레임 크기 → 위치가 맞는다):
   backplate(하늘+바다, 배 없음), island(섬+등대), boat(갑판·선실·마스트·뱃머리, 돛/휠/선장 없음), sail(돛 천만), wheel, captain.
3. 투명 레이어는 크로마키 → 바운딩 박스로 잘라 저장하고, 프레임 기준 좌표·피벗을 assets/art/layout.json 에 기록한다.
   Godot 는 layout.json 을 읽어 각 노드를 배치한다(없으면 씬의 플레이스홀더 위치 사용).

사용:
  GEMINI_API_KEY=... python3 scripts/generate_scene.py --master           # 마스터만 (구도 확인용)
  python3 scripts/generate_scene.py --layers                             # 마스터에서 레이어 파생
  python3 scripts/generate_scene.py --all                                # 둘 다
  python3 scripts/generate_scene.py --layout                             # 기존 레이어 PNG 로 layout.json 만 다시 계산
  옵션: --force (있어도 다시), --only backplate,sail (레이어 선택), --model
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_assets as ga  # noqa: E402

ROOT = ga.ROOT
ART = ga.ART_DIR
SCENE_DIR = ART / "scene"
RAW_DIR = ART / "_raw" / "scene"
MASTER = SCENE_DIR / "scene_master.png"
LAYOUT = ART / "layout.json"
FRAME = (900, 560)

STYLE = (
    "Modern clean cel-shaded anime illustration in the style of contemporary cozy lo-fi games: crisp clean linework, "
    "flat two-tone shading with soft glow highlights, saturated pastel sunset palette (peach, coral, apricot, lavender, dusty blue), "
    "gentle bloom on the sun, no film grain, no watercolor bleed, no paper texture, no text, no watermark. "
)

MASTER_PROMPT = STYLE + (
    "A first-person COCKPIT VIEW from the aft cockpit of a small classic sailing yacht at sunset, camera at eye level of someone sitting "
    "at the back of the cockpit looking FORWARD toward the bow. Composition (16:9): "
    "the ship's wooden steering wheel is large in the lower-middle of the frame, its hub at about 55% width and 72% height, seen from behind; "
    "a charming chubby orange tabby cat captain wearing a navy captain's hat with a gold anchor emblem, a chunky rust-orange knit sweater and "
    "a white neckerchief sits on the RIGHT (starboard) cockpit bench beside the wheel, seen in three-quarter view from behind, "
    "relaxed, one paw resting on the wheel rim, looking ahead at the sea; "
    "ahead of the cockpit the teak deck and a low cabin top lead forward to the bow; the wooden mast rises from the deck slightly LEFT of center "
    "and a full white mainsail billows to the LEFT of the mast, towering up past the top edge of the frame; "
    "beyond the bow: calm sea with a shimmering sunset reflection, the horizon line at about 38% of the frame height, "
    "a distant island with a small lighthouse on the right side of the horizon, and a warm sunset sky with a thin crescent moon and a few stars upper right. "
    "No other animals, no people, no otter, no text. Everything belongs to one coherent scene with correct perspective."
)

BASE_RULE = (
    "IMAGE 1 is the BASE image. IMAGE 2 is the finished target scene for reference of style, placement and scale. "
    "Edit IMAGE 1 by ADDING only the element described below, drawn in the same style and at the same position and size as in IMAGE 2. "
    "Every pixel of IMAGE 1 that is not covered by the new element must stay EXACTLY unchanged (do not re-render, recolor, shift or crop anything). "
    "Output exactly the same image size. No text.\n"
)

# 누적 단계: (name, prompt, pivot_kind). 각 단계는 직전 단계 이미지를 BASE 로 받아 요소 하나를 추가한다.
STAGES: list[tuple[str, str, str]] = [
    ("island", BASE_RULE + "ADD: the distant island with the small lighthouse on the right side of the horizon, as a soft silhouette on the horizon line.", "topleft"),
    ("boat", BASE_RULE + "ADD: the sailing yacht seen from the aft cockpit in first person: the cockpit floor and both side benches in the foreground, "
             "the wheel PEDESTAL (a wooden/steel column in the lower middle, but NOT the round wheel itself), the teak deck and low cabin top leading forward, "
             "the bow with its pulpit rail, the wooden mast rising from the deck slightly left of center with the boom and rigging lines. "
             "Do NOT draw the sail canvas, do NOT draw the round steering wheel, do NOT draw any character.", "topleft"),
    ("sail", BASE_RULE + "ADD: the full white mainsail canvas attached to the mast and boom, billowing to the LEFT of the mast and towering past the top edge of the frame. "
             "Only the sail canvas is new; mast, boom and everything else stay as they are.", "mastbottomleft"),
    ("wheel", BASE_RULE + "ADD: the round wooden ship's steering wheel (rim, eight spokes with handles, brass hub) mounted on the pedestal in the lower middle, "
              "seen from behind, complete and unoccluded. Nothing else changes.", "center"),
    ("captain", BASE_RULE + "ADD: the chubby orange tabby cat captain (navy captain's hat with gold anchor emblem, chunky rust-orange knit sweater, white neckerchief) "
                "sitting on the RIGHT cockpit bench beside the wheel, seen in three-quarter view from behind, relaxed, one paw resting on the wheel rim, "
                "looking ahead at the sea. Nothing else changes.", "bottomcenter"),
]
STAGE_ORDER = [st[0] for st in STAGES]


def _diff_layer(prev: Image.Image, cur: Image.Image, threshold: float = 26.0, soft: float = 34.0) -> Image.Image:
    """cur - prev 의 차이 영역을 알파로 하는 RGBA 레이어. 작은 잡음은 형태학 열림으로 제거."""
    from PIL import ImageChops, ImageFilter
    a = prev.convert("RGB")
    b = cur.convert("RGB")
    diff = ImageChops.difference(a, b)
    # 채널 최대값
    r, g, bl = diff.split()
    m = ImageChops.lighter(ImageChops.lighter(r, g), bl)
    # 잡음 제거: 확실한 영역(> threshold+soft) 을 열림 연산으로 정리한 마스크와, 부드러운 알파를 곱한다
    hard = m.point(lambda v: 255 if v > threshold + soft * 0.5 else 0)
    hard = hard.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(3))
    alpha = m.point(lambda v: int(255 * min(1.0, max(0.0, (v - threshold) / soft))))
    alpha = ImageChops.multiply(alpha, hard)
    # 내부 구멍 메우기(작은 픽셀 차이 없는 부분): 닫힘
    alpha = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    out = b.convert("RGBA")
    out.putalpha(alpha)
    return out


def generate_layers(client: ga.GeminiImageClient, force: bool, only: set[str] | None) -> None:
    if not MASTER.exists():
        print("! 마스터 장면이 없습니다. 먼저 --master 를 실행하세요.")
        return
    base_path = RAW_DIR / "backplate.png"
    if not base_path.exists():
        print("! backplate 원본이 없습니다(마스터에서 배 없는 하늘·바다). 먼저 생성합니다.")
        raw, model = client.generate(
            "Use the attached image as the exact reference. Remove the yacht entirely (no deck, cabin, mast, sail, wheel, cat) and remove the island "
            "and lighthouse. Show only the sunset sky and open sea, continuing them naturally where the boat was, same horizon height, same sun and moon. "
            "Same size, same style, no text.", [MASTER], "16:9")
        raw.save(base_path)
    prev_path = base_path
    for name, prompt, _pivot in STAGES:
        stage_path = RAW_DIR / f"stage_{name}.png"
        if stage_path.exists() and not force and (not only or name not in only):
            prev_path = stage_path
            print(f"- {name}: 단계 이미지 있음, 건너뜀")
            continue
        try:
            print(f"* {name}: 추가 생성 중 (base={prev_path.name}) ...")
            raw, model = client.generate(prompt, [prev_path, MASTER], "16:9")
            img = ga.fit_to(raw.convert("RGB"), FRAME, "cover")
            img.save(stage_path)
            print(f"  -> {stage_path.relative_to(ROOT)} via {model}")
            prev_path = stage_path
        except Exception as e:  # noqa: BLE001
            print(f"  !! {name} 실패: {str(e)[:300]}")
            break


def build_layout() -> dict:
    """누적 단계 이미지의 차이로 레이어 PNG 와 layout.json 을 만든다."""
    SCENE_DIR.mkdir(parents=True, exist_ok=True)
    layout: dict = {"frame": list(FRAME), "layers": {}}
    base_path = RAW_DIR / "backplate.png"
    if not base_path.exists():
        print("! backplate 원본 없음")
        return layout
    prev = ga.fit_to(Image.open(base_path).convert("RGB"), FRAME, "cover")
    prev.convert("RGBA").save(SCENE_DIR / "backplate.png", "PNG", optimize=True)
    layout["layers"]["backplate"] = {"file": "scene/backplate.png", "bbox": [0, 0, FRAME[0], FRAME[1]], "pivot": [0, 0], "pivot_kind": "topleft"}
    from PIL import ImageFilter
    for name, _prompt, pivot_kind in STAGES:
        stage_path = RAW_DIR / f"stage_{name}.png"
        if not stage_path.exists():
            print(f"- {name}: 단계 이미지 없음")
            continue
        cur = ga.fit_to(Image.open(stage_path).convert("RGB"), FRAME, "cover")
        layer = _diff_layer(prev, cur)
        alpha = layer.getchannel("A").point(lambda v: 255 if v > 128 else 0)
        bbox = alpha.filter(ImageFilter.MinFilter(5)).getbbox() or alpha.getbbox()
        if not bbox:
            print(f"  ! {name}: 차이 영역 없음")
            prev = cur
            continue
        l, t, r, b = bbox
        l, t = max(0, l - 4), max(0, t - 4)
        r, b = min(FRAME[0], r + 4), min(FRAME[1], b + 4)
        crop = layer.crop((l, t, r, b))
        out = SCENE_DIR / f"{name}.png"
        crop.save(out, "PNG", optimize=True)
        if pivot_kind == "topleft":
            pivot = (l, t)
        elif pivot_kind == "bottomcenter":
            pivot = ((l + r) / 2.0, b)
        elif pivot_kind == "center":
            pivot = ((l + r) / 2.0, (t + b) / 2.0)
        else:  # mastbottomleft: 돛이 마스트 왼쪽으로 부풀므로 앞전(마스트)은 오른쪽 가장자리
            pivot = (r, b)
        cover = 100.0 * sum(alpha.crop((l, t, r, b)).histogram()[129:]) / max(1, (r - l) * (b - t))
        layout["layers"][name] = {"file": f"scene/{name}.png", "bbox": [l, t, r, b], "pivot": [pivot[0], pivot[1]], "pivot_kind": pivot_kind}
        print(f"* {name}: {crop.width}x{crop.height} bbox={bbox} pivot={pivot} coverage={cover:.0f}%")
        prev = cur
    # 합성 확인용
    comp = Image.open(SCENE_DIR / "backplate.png").convert("RGBA")
    for name, _p, _k in STAGES:
        f = SCENE_DIR / f"{name}.png"
        if f.exists():
            lay = Image.open(f).convert("RGBA")
            bb = layout["layers"][name]["bbox"]
            comp.alpha_composite(lay, (bb[0], bb[1]))
    comp.save(RAW_DIR / "composite_check.png")
    # 파생 정보
    if "island" in layout["layers"]:
        isl = layout["layers"]["island"]
        layout["horizon_y"] = isl["bbox"][3] - 4
        im = Image.open(SCENE_DIR / "island.png")
        a = im.getchannel("A").load()
        for y in range(im.height):
            xs = [x for x in range(im.width) if a[x, y] > 128]
            if xs:
                layout["lighthouse"] = [isl["bbox"][0] + (min(xs) + max(xs)) / 2.0, isl["bbox"][1] + y + 6]
                break
    else:
        layout["horizon_y"] = int(FRAME[1] * 0.38)
    if "sail" in layout["layers"]:
        sb = layout["layers"]["sail"]["bbox"]
        layout["mast_top"] = [sb[2], sb[1]]
    # 바다 = 백플레이트의 수평선 아래(파도 메시용), 하늘 = 백플레이트 전체
    hy = int(layout["horizon_y"])
    sea = Image.open(SCENE_DIR / "backplate.png").convert("RGBA").crop((0, max(0, hy - 2), FRAME[0], FRAME[1]))
    sea.save(SCENE_DIR / "sea.png", "PNG", optimize=True)
    layout["layers"]["sea"] = {"file": "scene/sea.png", "bbox": [0, max(0, hy - 2), FRAME[0], FRAME[1]], "pivot": [0, max(0, hy - 2)], "pivot_kind": "topleft"}
    LAYOUT.write_text(json.dumps(layout, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"layout.json 저장: {LAYOUT.relative_to(ROOT)}")
    return layout


# ---------------------------------------------------------------- 개별 레이어(마젠타 위) + 코드 스냅 방식
ISO_STYLE = STYLE + "Use the attached reference image(s) for the exact art style, palette, line weight and the object's design. "
ISOLATED: dict[str, tuple[str, str]] = {
    # name → (prompt, reference: "master" | "stage_boat")
    "boat_plate": ("IMAGE 1 is the base. Reproduce IMAGE 1 EXACTLY (same yacht, same cockpit-view composition, same deck, cabin, benches, wheel pedestal, "
                   "mast, boom, rigging lines, pulpit rail, same line and shading) but replace ALL of the sky and ALL of the sea with a completely flat, "
                   "uniform, pure magenta (#FF00FF) background, like a green-screen. Keep the boat opaque and complete, including thin rigging lines. "
                   "No sail canvas, no round steering wheel, no character. Same image size.", "stage_boat"),
    "sail_only": (ISO_STYLE + "Draw ONLY the white mainsail canvas of the yacht exactly as it appears in the reference: the same billowing shape, seen from the cockpit "
                  "below and behind, its straight front edge (luff) running along where the mast would be on the RIGHT side of the canvas, the canvas bulging to the LEFT, "
                  "the bottom edge (foot) along where the boom would be. Draw the canvas complete including the part that was cut by the top of the frame "
                  "(extend it upward to the head of the sail). NO mast, NO boom, NO rigging, NO boat, NO sky, NO sea. Fully isolated on a completely flat, "
                  "uniform, pure magenta (#FF00FF) background.", "master"),
    "wheel_only": (ISO_STYLE + "Draw ONLY the round wooden ship's steering wheel from the reference: rim, eight turned spokes with handles, brass hub, "
                   "seen from directly behind and slightly above as in the reference, complete and unoccluded, centered, large. NO pedestal, NO paw, NO boat. "
                   "Fully isolated on a completely flat, uniform, pure magenta (#FF00FF) background.", "master"),
    "captain_seated": (ISO_STYLE + "Draw ONLY the chubby orange tabby cat captain from the reference (navy captain's hat with gold anchor emblem, chunky rust-orange "
                       "knit sweater, white neckerchief), sitting on a bench seen in three-quarter view from behind, relaxed, looking ahead, one paw resting forward "
                       "as if on a wheel rim, the other paw on its lap. Draw the WHOLE cat including its bottom and tail (nothing cut off), NO bench, NO wheel, "
                       "NO boat. Fully isolated on a completely flat, uniform, pure magenta (#FF00FF) background.", "master"),
    "island_only": (ISO_STYLE + "Draw ONLY the distant island with the small lighthouse from the reference: a low soft purple-blue silhouette with the lighthouse "
                    "near its right end, wide and flat, seen from sea level, its bottom edge perfectly straight (it sits on the horizon). NO sea, NO sky. "
                    "Fully isolated on a completely flat, uniform, pure magenta (#FF00FF) background, drawn large across the width of the image.", "master"),
}
ISO_ORDER = ["boat_plate", "sail_only", "wheel_only", "captain_seated", "island_only"]


def generate_isolated(client: ga.GeminiImageClient, force: bool, only: set[str] | None) -> None:
    for name in ISO_ORDER:
        if only and name not in only:
            continue
        prompt, ref = ISOLATED[name]
        raw_path = RAW_DIR / f"{name}.png"
        if raw_path.exists() and not force:
            print(f"- {name}: 원본 있음, 건너뜀")
            continue
        refs = [RAW_DIR / "stage_boat.png"] if ref == "stage_boat" else [MASTER]
        aspect = "16:9" if name in ("boat_plate", "island_only") else ("3:4" if name == "sail_only" else "1:1")
        try:
            print(f"* {name}: 생성 중 ...")
            raw, model = client.generate(prompt, refs, aspect)
            raw.save(raw_path)
            print(f"  -> {raw_path.relative_to(ROOT)} via {model} (raw {raw.width}x{raw.height})")
        except Exception as e:  # noqa: BLE001
            print(f"  !! {name} 실패: {str(e)[:300]}")


# ---------------------------------------------------------------- 조립(스냅) → scene/*.png + layout.json

def _key_and_crop(raw: Image.Image, cover_frame: bool) -> tuple[Image.Image, tuple[int, int, int, int]]:
    """마젠타 원본 → RGBA. cover_frame 이면 프레임 크기로 맞춘 뒤(전체 판), 아니면 피사체 bbox 로 자른다."""
    img = ga.fit_to(raw.convert("RGB"), FRAME, "cover") if cover_frame else raw.convert("RGB")
    bg = ga.detect_background(img)
    if bg is None:
        rgba = img.convert("RGBA")
    else:
        key, spread = bg
        soft_in = max(30.0, spread * 1.8)
        rgba = ga.chroma_key(img, key=key, soft_in=soft_in, soft_out=soft_in + 35.0)
    rgba = ga.clear_border(rgba, max(4, int(min(rgba.size) * 0.012)))
    if cover_frame:
        return rgba, (0, 0, rgba.width, rgba.height)
    from PIL import ImageFilter
    alpha = rgba.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    bbox = alpha.filter(ImageFilter.MinFilter(5)).getbbox() or alpha.getbbox() or (0, 0, rgba.width, rgba.height)
    l, t, r, b = bbox
    l, t = max(0, l - 3), max(0, t - 3)
    r, b = min(rgba.width, r + 3), min(rgba.height, b + 3)
    return rgba.crop((l, t, r, b)), (l, t, r, b)


def find_mast_x(plate: Image.Image) -> float:
    """선체 판 상반부에서 폭 6~40px 의 세로 불투명 띠가 가장 많은 행에 걸쳐 같은 x 에 있는 곳 = 마스트."""
    a = plate.getchannel("A").load()
    w, h = plate.size
    centers: dict[int, int] = {}
    for y in range(0, int(h * 0.55), 2):
        x = 0
        while x < w:
            if a[x, y] > 128:
                x0 = x
                while x < w and a[x, y] > 128:
                    x += 1
                run = x - x0
                if 6 <= run <= 40:
                    c = (x0 + x) // 2
                    centers[c // 6] = centers.get(c // 6, 0) + 1
            else:
                x += 1
    if not centers:
        return w * 0.42
    best = max(centers.items(), key=lambda kv: kv[1])[0]
    return best * 6 + 3


def find_horizon_y(backplate: Image.Image) -> int:
    """행 평균색의 변화가 가장 큰 곳(중간 대역) = 수평선."""
    rgb = backplate.convert("RGB")
    w, h = rgb.size
    small = rgb.resize((max(1, w // 8), h))
    px = small.load()
    rows = []
    for y in range(h):
        r = g = b = 0
        for x in range(small.width):
            pr, pg, pb = px[x, y]
            r += pr; g += pg; b += pb
        n = small.width
        rows.append((r / n, g / n, b / n))
    best_y, best_d = int(h * 0.4), -1.0
    for y in range(int(h * 0.3), int(h * 0.7)):
        d = sum(abs(rows[y + 1][i] - rows[y - 1][i]) for i in range(3))
        if d > best_d:
            best_d, best_y = d, y
    return best_y


def assemble() -> dict:
    """개별 원본 → 최종 레이어 PNG + layout.json. 위치는 코드로 스냅한다."""
    SCENE_DIR.mkdir(parents=True, exist_ok=True)
    W, H = FRAME
    layout: dict = {"frame": [W, H], "layers": {}}

    def put(name: str, img: Image.Image, origin: tuple[float, float], pivot: tuple[float, float], kind: str) -> None:
        img.save(SCENE_DIR / f"{name}.png", "PNG", optimize=True)
        layout["layers"][name] = {"file": f"scene/{name}.png",
                                  "bbox": [int(origin[0]), int(origin[1]), int(origin[0]) + img.width, int(origin[1]) + img.height],
                                  "pivot": [pivot[0], pivot[1]], "pivot_kind": kind}
        print(f"* {name}: {img.width}x{img.height} at {origin} pivot={pivot}")

    # 1) 백플레이트(하늘+바다) 와 수평선
    back = ga.fit_to(Image.open(RAW_DIR / "backplate.png").convert("RGB"), FRAME, "cover").convert("RGBA")
    hy = find_horizon_y(back)
    layout["horizon_y"] = hy
    put("backplate", back, (0, 0), (0, 0), "topleft")
    sea = back.crop((0, max(0, hy - 2), W, H))
    put("sea", sea, (0, max(0, hy - 2)), (0, max(0, hy - 2)), "topleft")

    # 2) 선체 판(전체 프레임) + 마스트 x
    plate, _ = _key_and_crop(Image.open(RAW_DIR / "boat_plate.png"), True)
    mast_x = find_mast_x(plate)
    layout["mast_x"] = mast_x
    put("boat", plate, (0, 0), (0, 0), "topleft")

    # 3) 섬: 수평선 위, 오른쪽. 폭 = 프레임의 40%
    isl, _ = _key_and_crop(Image.open(RAW_DIR / "island_only.png"), False)
    tw = int(W * 0.40)
    isl = isl.resize((tw, max(1, round(isl.height * tw / isl.width))), Image.LANCZOS)
    ox, oy = W - tw - 40, hy - isl.height + 2
    put("island", isl, (ox, oy), (ox, oy), "topleft")
    a = isl.getchannel("A").load()
    for y in range(isl.height):
        xs = [x for x in range(isl.width) if a[x, y] > 128]
        if xs:
            layout["lighthouse"] = [ox + (min(xs) + max(xs)) / 2.0, oy + y + 4]
            break

    # 4) 돛: 앞전(오른쪽 가장자리)을 마스트에, 발(아래)을 foot_y 에. 폭은 마스트 왼쪽 공간의 대부분.
    sail, _ = _key_and_crop(Image.open(RAW_DIR / "sail_only.png"), False)
    foot_y = int(H * 0.55)
    sail_w = int(mast_x * 0.95)
    sail = sail.resize((sail_w, max(1, round(sail.height * sail_w / sail.width))), Image.LANCZOS)
    ox, oy = int(mast_x - sail_w), foot_y - sail.height
    put("sail", sail, (ox, oy), (mast_x, foot_y), "mastbottomleft")
    layout["mast_top"] = [mast_x, max(0, oy)]

    # 5) 휠: 페데스탈 위. 허브 위치·지름은 상수(프레임 비율)
    wheel, _ = _key_and_crop(Image.open(RAW_DIR / "wheel_only.png"), False)
    dia = int(W * 0.30)
    wheel = wheel.resize((dia, max(1, round(wheel.height * dia / wheel.width))), Image.LANCZOS)
    hub = (mast_x + W * 0.055, H * 0.74)
    ox, oy = hub[0] - wheel.width / 2.0, hub[1] - wheel.height / 2.0
    put("wheel", wheel, (ox, oy), hub, "center")

    # 6) 선장: 우측 벤치. 발(아래 중앙)을 프레임 아래쪽에 두어 하체 일부가 잘리게(콕핏에 앉은 느낌)
    cat, _ = _key_and_crop(Image.open(RAW_DIR / "captain_seated.png"), False)
    cat_h = int(H * 0.66)
    cat = cat.resize((max(1, round(cat.width * cat_h / cat.height)), cat_h), Image.LANCZOS)
    feet = (hub[0] + W * 0.27, H * 1.06)
    ox, oy = feet[0] - cat.width / 2.0, feet[1] - cat.height
    put("captain", cat, (ox, oy), feet, "bottomcenter")
    layout["helm_spot"] = [feet[0], feet[1]]
    layout["winch_spot"] = [mast_x + W * 0.02, H * 0.78]

    # 합성 확인
    comp = back.copy()
    for name in ["island", "boat", "sail", "wheel", "captain"]:
        l = layout["layers"][name]
        lay = Image.open(SCENE_DIR / f"{name}.png").convert("RGBA")
        full = Image.new("RGBA", FRAME, (0, 0, 0, 0))
        full.alpha_composite(lay, (max(0, l["bbox"][0]), max(0, l["bbox"][1])) if l["bbox"][0] >= 0 and l["bbox"][1] >= 0 else (0, 0))
        if l["bbox"][0] < 0 or l["bbox"][1] < 0:
            full = Image.new("RGBA", FRAME, (0, 0, 0, 0))
            full.paste(lay, (l["bbox"][0], l["bbox"][1]), lay)
        comp.alpha_composite(full)
    comp.save(RAW_DIR / "composite_check.png")
    LAYOUT.write_text(json.dumps(layout, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"horizon_y={hy} mast_x={mast_x:.0f}  layout.json 저장")
    return layout


# ---------------------------------------------------------------- 추가 에셋(같은 스타일): 선장 동작 스트립, UI 버튼, 해도 배경

def _extra_assets() -> list[ga.Asset]:
    cat_ref = "scene/captain.png"
    return [
        ga.Asset("captain_walk_anim", "the same chubby orange tabby cat captain from the reference, standing and walking calmly to the right in profile, unhurried stride; "
                 "frame 1: left foot forward; frame 2: feet passing, body slightly up; frame 3: right foot forward; frame 4: feet passing, body slightly down",
                 (253, 430), transparent=True, aspect="16:9", anchor="bottom", frames=4, out_prefix="scene/captain_walk", extra_refs=[cat_ref], no_style_ref=True),
        ga.Asset("captain_pull_anim", "the same chubby orange tabby cat captain from the reference, standing in profile and hauling on a SHORT rope held close to its body "
                 "with both paws (the rope never extends outside the character's own frame); frame 1: paws reaching a little forward to grab the rope; "
                 "frame 2: leaning back slightly, pulling; frame 3: paws brought to the chest, rope taut",
                 (253, 430), transparent=True, aspect="16:9", anchor="bottom", frames=3, out_prefix="scene/captain_pull", extra_refs=[cat_ref], no_style_ref=True),
        ga.Asset("captain_stretch_anim", "the same chubby orange tabby cat captain from the reference, standing and stretching with a yawn, in profile; "
                 "frame 1: arms halfway up, mouth opening; frame 2: arms fully up, big yawn, eyes closed; frame 3: arms coming down, satisfied smile",
                 (253, 430), transparent=True, aspect="16:9", anchor="bottom", frames=3, out_prefix="scene/captain_stretch", extra_refs=[cat_ref], no_style_ref=True),
        ga.Asset("ui_btn_settings", "A round flat game UI button: a soft cream disc with a thin coral outline and a simple navy gear icon in the middle, modern minimal. Only the button.",
                 (60, 60), transparent=True, aspect="1:1", anchor="center", no_style_ref=True),
        ga.Asset("ui_btn_share", "A round flat game UI button: a soft cream disc with a thin coral outline and a simple navy diagonal arrow (open link) icon in the middle, modern minimal. Only the button.",
                 (60, 60), transparent=True, aspect="1:1", anchor="center", no_style_ref=True),
        ga.Asset("ui_btn_chart", "A round flat game UI button: a soft cream disc with a thin coral outline and a simple navy folded-map icon in the middle, modern minimal. Only the button.",
                 (60, 60), transparent=True, aspect="1:1", anchor="center", no_style_ref=True),
        ga.Asset("chart_bg", "A flat top-down texture for a nautical chart panel: soft cream paper with a faint pale-blue latitude/longitude grid, a small pale compass rose in one corner, "
                 "clean modern flat style, subtle rounded corners look. It is PAPER, not a landscape: NO sky, NO sea, NO land, NO text. Opaque full-frame.",
                 (400, 260), transparent=False, aspect="3:2", anchor="cover", no_style_ref=True),
    ]


def _extra_prompt(asset: ga.Asset) -> str:
    parts = [STYLE]
    parts.append("Use the attached reference image(s) for the exact art style, palette and character design. ")
    if asset.transparent:
        parts.append(ga.CHROMA_HINT)
    if asset.frames > 0:
        parts.append(ga.STRIP_HINT.format(n=asset.frames, steps=asset.prompt))
        parts.append("Subject of every frame: " + asset.prompt.split(";")[0])
    else:
        parts.append("Subject: " + asset.prompt)
    return "\n".join(parts)


def generate_extras(client: ga.GeminiImageClient, force: bool, only: set[str] | None) -> None:
    (ART / "scene").mkdir(parents=True, exist_ok=True)
    for asset in _extra_assets():
        if only and asset.name not in only:
            continue
        if all(p.exists() for p in asset.outputs()) and not force:
            print(f"- {asset.name}: 이미 있음")
            continue
        refs = [MASTER] + [ART / r for r in asset.extra_refs if (ART / r).exists()]
        raw_path = RAW_DIR / f"extra_{asset.name}.png"
        try:
            print(f"* {asset.name}: 생성 중 ...")
            raw, model = client.generate(_extra_prompt(asset), refs, asset.aspect)
            raw.save(raw_path)
            if asset.frames > 0:
                frames = ga.postprocess_frames(asset, raw)
                for i, fr in enumerate(frames):
                    fr.save(asset.frame_path(i), "PNG", optimize=True)
                print(f"  -> {asset.frame_path(0).relative_to(ROOT)} .. _{len(frames) - 1} via {model}")
            else:
                out = ga.postprocess(asset, raw)
                out.save(asset.path, "PNG", optimize=True)
                print(f"  -> {asset.path.relative_to(ROOT)} via {model}")
        except Exception as e:  # noqa: BLE001
            print(f"  !! {asset.name} 실패: {str(e)[:300]}")


def _client(model: str | None) -> ga.GeminiImageClient:
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        print("! GEMINI_API_KEY 가 없습니다.", file=sys.stderr)
        sys.exit(2)
    return ga.GeminiImageClient(key, model)


def generate_master(client: ga.GeminiImageClient, force: bool) -> Image.Image:
    SCENE_DIR.mkdir(parents=True, exist_ok=True)
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    if MASTER.exists() and not force:
        print(f"- master: 이미 있음 ({MASTER.relative_to(ROOT)}), --force 로 재생성")
        return Image.open(MASTER).convert("RGB")
    refs = [ga.REFERENCE] if ga.REFERENCE.exists() else []
    print("* master: 생성 중 ...")
    raw, model = client.generate(MASTER_PROMPT, refs, "16:9")
    raw.save(RAW_DIR / "scene_master_raw.png")
    img = ga.fit_to(raw.convert("RGB"), FRAME, "cover")
    img.save(MASTER, "PNG", optimize=True)
    print(f"  -> {MASTER.relative_to(ROOT)} via {model} (raw {raw.width}x{raw.height})")
    return img


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--master", action="store_true")
    ap.add_argument("--layers", action="store_true")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--layout", action="store_true", help="원본 레이어로 layout.json 재계산만")
    ap.add_argument("--isolate", action="store_true", help="개별 레이어(선체 판·돛·휠·선장·섬)를 마젠타 위에 생성")
    ap.add_argument("--extras", action="store_true", help="선장 동작 스트립·UI 버튼·해도 배경을 같은 스타일로 생성")
    ap.add_argument("--extras-reprocess", action="store_true", help="추가 에셋을 원본에서 후처리만 다시 (API 미사용)")
    ap.add_argument("--assemble", action="store_true", help="개별 원본을 크로마키·스냅해 scene/*.png + layout.json 생성 (API 미사용)")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--only")
    ap.add_argument("--model")
    args = ap.parse_args()
    only = {s.strip() for s in args.only.split(",")} if args.only else None
    if args.layout:
        build_layout()
        return 0
    if args.assemble:
        assemble()
        return 0
    if args.extras_reprocess:
        for asset in _extra_assets():
            if only and asset.name not in only:
                continue
            raw_path = RAW_DIR / f"extra_{asset.name}.png"
            if not raw_path.exists():
                continue
            raw = Image.open(raw_path)
            raw.load()
            if asset.frames > 0:
                for i, fr in enumerate(ga.postprocess_frames(asset, raw)):
                    fr.save(asset.frame_path(i), "PNG", optimize=True)
                print(f"* {asset.name}: 재처리 → {asset.frames} frames")
            else:
                ga.postprocess(asset, raw).save(asset.path, "PNG", optimize=True)
                print(f"* {asset.name}: 재처리")
        return 0
    client = _client(args.model)
    if args.master or args.all:
        generate_master(client, args.force)
    if args.isolate:
        generate_isolated(client, args.force, only)
        return 0
    if args.extras:
        generate_extras(client, args.force, only)
        return 0
    if args.layers or args.all:
        generate_layers(client, args.force, only)
        build_layout()
    return 0


if __name__ == "__main__":
    sys.exit(main())
