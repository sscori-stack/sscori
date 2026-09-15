#!/usr/bin/env python3
"""
Sailing Companion 에셋 생성기 (Google Gemini 이미지 생성, "Nano Banana").

- README 의 에셋 표를 순회하며 항목별 프롬프트로 이미지를 생성해 assets/art/<파일명>.png 로 저장한다.
- 스타일 고정 접두사 + reference/image_0.png(있으면) 를 함께 보내 화풍을 맞춘다.
- 투명 배경이 필요한 항목은 마젠타 단색 배경으로 요청한 뒤 Pillow 로 크로마키 제거(모델이 진짜 알파를 주면 그대로 사용).
- 타일링 항목(sea, clouds)은 심리스 요청 + 좌우 가장자리 롤-블렌딩 후처리.
- 이미 존재하는 파일은 --force 없이는 건너뛴다. 항목 하나가 실패해도 다음 항목으로 계속 진행한다.
- API 키(GEMINI_API_KEY)가 없으면 아무것도 생성하지 않고 종료한다(게임은 플레이스홀더로 동작).

사용:
  GEMINI_API_KEY=... python3 scripts/generate_assets.py            # 없는 파일만 생성
  python3 scripts/generate_assets.py --force --only captain,otter    # 지정 항목 재생성
  python3 scripts/generate_assets.py --dry-run                       # 프롬프트만 출력
  python3 scripts/generate_assets.py --selftest                      # 후처리 함수 자가 테스트
  python3 scripts/generate_assets.py --report                        # 기존 파일 검사 표만 출력
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import os
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

try:
    from PIL import Image, ImageChops
except ImportError:  # pragma: no cover
    print("Pillow 가 필요합니다: pip install pillow", file=sys.stderr)
    raise

try:
    import requests
except ImportError:  # pragma: no cover
    print("requests 가 필요합니다: pip install requests", file=sys.stderr)
    raise

ROOT = Path(__file__).resolve().parent.parent
ART_DIR = ROOT / "assets" / "art"
REFERENCE = ROOT / "reference" / "image_0.png"

API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
# 순서대로 시도한다. 키의 요금제에 따라 사용 가능한 모델이 다르다(이미지 생성은 유료 등급 필요할 수 있음).
MODEL_CANDIDATES = [
    "gemini-2.5-flash-image",          # Nano Banana
    "gemini-3.1-flash-image",
    "gemini-3.1-flash-lite-image",
    "gemini-3-pro-image",              # Nano Banana Pro
]

STYLE_PREFIX = (
    "지브리풍 수채화, 따뜻한 노을 톤, 선명한 라인, 배경 완전 투명 또는 단색. "
    "Studio Ghibli-inspired watercolor illustration, warm sunset palette (peach, apricot, lavender, soft purple), "
    "clean crisp linework, soft paper texture, cozy and calm mood, no text, no watermark, no signature. "
)
CHROMA_HINT = (
    "IMPORTANT: draw ONLY the requested subject, fully isolated, centered, nothing cut off, "
    "on a completely flat, uniform, pure magenta background (#FF00FF). "
    "No shadow, no gradient, no vignette, no ground plane on the background. "
    "Ideally output a PNG with a transparent alpha channel; if not possible, keep the magenta perfectly flat."
)
SEAMLESS_HINT = (
    "The image must be a seamless horizontally tileable pattern: the left edge must continue perfectly into the right edge "
    "with no visible seam, and the composition must not have a focal object in the center."
)
REFERENCE_HINT = (
    "Use the attached reference image as the style guide: reproduce the same art style, brush feel, line weight and color palette. "
    "Draw ONLY the element described below, separated from the scene."
)
KEY_COLOR = (255, 0, 255)


@dataclass
class Asset:
    name: str                      # 파일명(확장자 제외)
    prompt: str                    # 항목 묘사
    size: tuple[int, int]          # 목표 크기(창 2배 해상도)
    transparent: bool = False      # 배경 투명 필요
    seamless: bool = False         # 좌우 타일링
    aspect: str = "1:1"            # 생성 시 요청할 비율
    anchor: str = "bottom"         # 크기 맞출 때 정렬: bottom / center / cover
    use_captain_ref: bool = False  # captain.png 를 캐릭터 참조로 첨부
    extra_refs: list[str] = field(default_factory=list)

    @property
    def path(self) -> Path:
        return ART_DIR / f"{self.name}.png"


ASSETS: list[Asset] = [
    Asset("sky", "A wide sunset sky seen from a sailboat at sea: warm orange-apricot glow near the horizon fading up into lavender and soft purple, "
          "a thin crescent moon and a few tiny stars in the upper right, a couple of faint soft clouds. No sea, no boat, no land. Opaque full-frame painting.",
          (900, 560), transparent=False, aspect="16:9", anchor="cover"),
    Asset("clouds_far", "A horizontal band of small distant fluffy sunset clouds, pale peach and cream with lavender shadows, sparse, soft edges, "
          "seen from far away. Only the clouds.", (900, 120), transparent=True, seamless=True, aspect="16:9", anchor="cover"),
    Asset("clouds_near", "A horizontal band of larger fluffy cumulus clouds lit by sunset, cream and apricot tops with soft purple undersides, "
          "closer and more detailed than distant clouds. Only the clouds.", (900, 140), transparent=True, seamless=True, aspect="16:9", anchor="cover"),
    Asset("horizon", "A very wide, low silhouette strip of a distant island coastline with a small lighthouse near its right end, "
          "soft purple-blue haze silhouette against nothing, the bottom edge is a flat straight sea horizon line. Only the silhouette strip, nothing above it.",
          (940, 120), transparent=True, aspect="21:9", anchor="bottom"),
    Asset("sea", "Calm open sea surface at sunset viewed from a boat, gentle rolling waves, blue-violet water with warm orange and pink sunset reflections "
          "as a shimmering path, small highlights. No boat, no sky, no land: only water filling the whole frame.",
          (1200, 280), transparent=False, seamless=True, aspect="16:9", anchor="cover"),
    Asset("sail", "A single white mainsail full of wind on a wooden mast, seen from behind and slightly to the side, the boom pointing to the right, "
          "cream-white canvas with soft shading, a few rope details. The mast base is at the bottom center. Only the sail and mast.",
          (260, 280), transparent=True, aspect="1:1", anchor="bottom"),
    Asset("deck", "The wooden deck of a small classic sailboat seen from behind at cockpit level: warm honey-brown planks, a coiled rope, a brass compass "
          "in a small wooden box, cleats. A wide low shape. Only the deck and its props, no sea, no sky, no people.",
          (680, 140), transparent=True, aspect="16:9", anchor="bottom"),
    Asset("winch", "A small brass and wood sailboat sheet winch with a cleat and a short rope tail, seen from the side. Tiny prop. Only the winch.",
          (44, 28), transparent=True, aspect="1:1", anchor="bottom"),
    Asset("otter", "A cute sea otter curled up sleeping peacefully on a folded plaid blanket, eyes closed, paws tucked, chubby and fluffy brown fur, "
          "seen from the side, very cozy. Only the otter and its small blanket.", (120, 68), transparent=True, aspect="4:3", anchor="bottom"),
    Asset("captain", "A charming tabby cat captain sitting on a wooden bench, seen from behind and slightly to the side, gazing calmly out at the sea, "
          "wearing a navy captain's hat with a gold anchor emblem, a chunky brown patterned knit sweater and a white neckerchief. "
          "Relaxed, peaceful posture. Full body, feet at the bottom. Only the cat.", (88, 156), transparent=True, aspect="3:4", anchor="bottom"),
    Asset("captain_walk", "The SAME tabby cat captain (same hat, sweater, neckerchief), now standing and walking calmly to the side with an unhurried stride, "
          "seen in profile, tail relaxed. Full body, feet at the bottom. Only the cat.", (88, 156), transparent=True, aspect="3:4", anchor="bottom", use_captain_ref=True),
    Asset("captain_pull", "The SAME tabby cat captain (same hat, sweater, neckerchief), standing and gently pulling a rope with both paws, "
          "leaning back a little, calm focused expression. Full body, feet at the bottom. Only the cat and the rope in its paws.",
          (88, 156), transparent=True, aspect="3:4", anchor="bottom", use_captain_ref=True),
    Asset("captain_steer", "The SAME tabby cat captain (same hat, sweater, neckerchief), sitting and holding a wooden ship's wheel spoke with one paw, "
          "seen from behind and slightly to the side, relaxed. Full body, feet at the bottom. Only the cat (do not draw the wheel itself).",
          (88, 156), transparent=True, aspect="3:4", anchor="bottom", use_captain_ref=True),
    Asset("captain_pet", "The SAME tabby cat captain (same hat, sweater, neckerchief), crouching down and gently patting something small in front of it "
          "with a soft smile, seen from the side. Full body, feet at the bottom. Only the cat.", (88, 156), transparent=True, aspect="3:4", anchor="bottom", use_captain_ref=True),
    Asset("captain_stretch", "The SAME tabby cat captain (same hat, sweater, neckerchief), standing and stretching its arms up with a big satisfied yawn, "
          "eyes closed, seen from the side. Full body, feet at the bottom. Only the cat.", (88, 156), transparent=True, aspect="3:4", anchor="bottom", use_captain_ref=True),
    Asset("wheel", "A classic wooden ship's steering wheel with eight turned spokes and handles and a brass hub, seen exactly from the front, "
          "perfectly centered so the hub is the exact center of the image. Only the wheel.", (120, 120), transparent=True, aspect="1:1", anchor="center"),
    Asset("windex", "A tiny masthead wind vane (windex): a slim red arrow pointing straight up with a small tail fin, brass pivot at the center. "
          "Vertical orientation, arrow tip at the top. Only the vane.", (24, 48), transparent=True, aspect="1:1", anchor="center"),
    Asset("cockpit", "The lower wooden cockpit coaming and railing of a small sailboat seen from behind, a wide horizontal frame of warm dark wood "
          "with brass fittings, slightly curved top edge. Only the wooden frame strip.", (900, 72), transparent=True, aspect="21:9", anchor="bottom"),
    Asset("chart_bg", "An old nautical chart background: aged parchment paper texture in warm cream and tan, faint compass rose in a corner, "
          "faint latitude/longitude grid lines, soft watercolor stains, no land shapes, no text. Opaque full-frame.",
          (400, 260), transparent=False, aspect="3:2", anchor="cover"),
    Asset("ui_btn_settings", "A round wooden button icon with a brass gear symbol in the middle, hand-painted look. Only the button.",
          (60, 60), transparent=True, aspect="1:1", anchor="center"),
    Asset("ui_btn_share", "A round wooden button icon with a brass diagonal arrow (share/open link) symbol in the middle, hand-painted look. Only the button.",
          (60, 60), transparent=True, aspect="1:1", anchor="center"),
    Asset("ui_btn_chart", "A round wooden button icon with a small folded nautical chart/map symbol in the middle, hand-painted look. Only the button.",
          (60, 60), transparent=True, aspect="1:1", anchor="center"),
]


# ============================================================ 후처리

def chroma_key(img: Image.Image, key=KEY_COLOR, soft_in: float = 70.0, soft_out: float = 150.0) -> Image.Image:
    """단색(key) 배경을 알파로. 색 거리 soft_in 이하 → 투명, soft_out 이상 → 불투명, 사이는 선형."""
    rgba = img.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    kr, kg, kb = key
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d = ((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2) ** 0.5
            if d <= soft_in:
                px[x, y] = (r, g, b, 0)
            elif d < soft_out:
                t = (d - soft_in) / (soft_out - soft_in)
                # 디스필: 반투명 가장자리의 마젠타 물빠짐 완화
                if r > g and b > g:
                    m = int(g + (max(r, b) - g) * 0.4)
                    r, b = min(r, m), min(b, m)
                px[x, y] = (r, g, b, int(a * t))
    return rgba


def has_real_alpha(img: Image.Image) -> bool:
    if img.mode != "RGBA":
        return False
    alpha = img.getchannel("A")
    lo, hi = alpha.getextrema()
    return lo < 250


def looks_like_key_background(img: Image.Image, key=KEY_COLOR, tol: float = 60.0) -> bool:
    """네 모서리 대부분이 key 색이면 크로마키 대상."""
    rgb = img.convert("RGB")
    w, h = rgb.size
    pts = [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3), (w // 2, 2), (w // 2, h - 3), (2, h // 2), (w - 3, h // 2)]
    hits = 0
    for p in pts:
        r, g, b = rgb.getpixel(p)
        if ((r - key[0]) ** 2 + (g - key[1]) ** 2 + (b - key[2]) ** 2) ** 0.5 <= tol:
            hits += 1
    return hits >= 5


def make_seamless_x(img: Image.Image, blend_frac: float = 0.25) -> Image.Image:
    """좌우 타일링: 절반만큼 굴린 이미지(가장자리가 연속) 위에 원본을 중앙 페더 마스크로 덮는다."""
    w, h = img.size
    rolled = ImageChops.offset(img, w // 2, 0)
    b = max(1, int(w * blend_frac))
    mask = Image.new("L", (w, h), 0)
    mpx = mask.load()
    for x in range(w):
        # 중앙 1.0, 양끝으로 b 픽셀에 걸쳐 0
        if x < b:
            v = x / b
        elif x >= w - b:
            v = (w - 1 - x) / b
        else:
            v = 1.0
        col = int(255 * v)
        for y in range(h):
            mpx[x, y] = col
    out = rolled.copy()
    out.paste(img, (0, 0), mask)
    return out


def autocrop(img: Image.Image, threshold: int = 12) -> Image.Image:
    if img.mode != "RGBA":
        return img
    alpha = img.getchannel("A").point(lambda v: 255 if v > threshold else 0)
    bbox = alpha.getbbox()
    return img.crop(bbox) if bbox else img


def fit_to(img: Image.Image, size: tuple[int, int], anchor: str) -> Image.Image:
    """anchor: cover(비율 유지 확대 후 중앙 크롭) / bottom(비율 유지 축소, 하단 중앙 정렬) / center."""
    tw, th = size
    if anchor == "cover":
        scale = max(tw / img.width, th / img.height)
        nw, nh = max(1, round(img.width * scale)), max(1, round(img.height * scale))
        r = img.resize((nw, nh), Image.LANCZOS)
        left, top = (nw - tw) // 2, (nh - th) // 2
        return r.crop((left, top, left + tw, top + th))
    scale = min(tw / img.width, th / img.height)
    nw, nh = max(1, round(img.width * scale)), max(1, round(img.height * scale))
    r = img.convert("RGBA").resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    x = (tw - nw) // 2
    y = (th - nh) if anchor == "bottom" else (th - nh) // 2
    canvas.paste(r, (x, y), r)
    return canvas


def postprocess(asset: Asset, raw: Image.Image) -> Image.Image:
    img = raw
    if asset.transparent:
        if has_real_alpha(img):
            img = img.convert("RGBA")
        elif looks_like_key_background(img):
            img = chroma_key(img)
        else:
            print(f"  ! {asset.name}: 투명 배경도 마젠타 배경도 아님 → 그대로 사용(수동 확인 필요)")
            img = img.convert("RGBA")
        if asset.seamless:
            img = fit_to(img, asset.size, "cover")
            img = make_seamless_x(img)
        else:
            img = autocrop(img)
            img = fit_to(img, asset.size, asset.anchor)
    else:
        img = fit_to(img.convert("RGB"), asset.size, "cover")
        if asset.seamless:
            img = make_seamless_x(img)
        img = img.convert("RGBA")
    return img


# ============================================================ Gemini 호출

def _b64_png(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def build_prompt(asset: Asset, has_reference: bool) -> str:
    parts = [STYLE_PREFIX]
    if has_reference:
        parts.append(REFERENCE_HINT)
    if asset.transparent:
        parts.append(CHROMA_HINT)
    if asset.seamless:
        parts.append(SEAMLESS_HINT)
    parts.append("Subject: " + asset.prompt)
    return "\n".join(parts)


class GeminiImageClient:
    def __init__(self, api_key: str, model: str | None = None, timeout: float = 120.0):
        self.api_key = api_key
        self.models = [model] if model else list(MODEL_CANDIDATES)
        self.timeout = timeout
        self.session = requests.Session()
        self.working_model: str | None = None

    def generate(self, prompt: str, ref_images: list[Path], aspect: str) -> tuple[Image.Image, str]:
        parts: list[dict] = [{"text": prompt}]
        for p in ref_images:
            parts.append({"inline_data": {"mime_type": "image/png", "data": _b64_png(p)}})
        models = [self.working_model] if self.working_model else self.models
        last_err: Exception | None = None
        for model in models:
            for modalities in (["IMAGE"], ["IMAGE", "TEXT"]):
                body = {
                    "contents": [{"role": "user", "parts": parts}],
                    "generationConfig": {"responseModalities": modalities, "imageConfig": {"aspectRatio": aspect}},
                }
                try:
                    img = self._call(model, body)
                    self.working_model = model
                    return img, model
                except RetryableError as e:
                    last_err = e
                    continue
                except QuotaError as e:
                    last_err = e
                    break  # 이 모델은 이 키로 못 씀 → 다음 모델
                except requests.HTTPError as e:
                    last_err = e
                    code = e.response.status_code if e.response is not None else 0
                    if code == 400:
                        # 이 모델/모달리티 조합이 안 맞음 → 다음 조합
                        continue
                    if code == 404:
                        break  # 모델 없음 → 다음 모델
                    raise
        if isinstance(last_err, QuotaError):
            raise QuotaError("이 API 키로는 이미지 모델 할당량이 0 입니다(무료 등급 미지원 또는 결제 미설정). "
                             "Google AI Studio 에서 결제를 활성화하거나 다른 키를 쓰세요. " + str(last_err)[:200])
        raise RuntimeError(f"모든 모델/설정 실패: {last_err}")

    def _call(self, model: str, body: dict) -> Image.Image:
        url = f"{API_BASE}/{model}:generateContent"
        headers = {"x-goog-api-key": self.api_key, "Content-Type": "application/json"}
        delay = 4.0
        for attempt in range(4):
            resp = self.session.post(url, headers=headers, data=json.dumps(body), timeout=self.timeout)
            if resp.status_code == 429 and ("limit: 0" in resp.text or "billing" in resp.text.lower()):
                raise QuotaError(f"429 quota/billing: {resp.text[:200]}")
            if resp.status_code in (429, 500, 502, 503, 504):
                if attempt == 3:
                    raise RetryableError(f"{resp.status_code}: {resp.text[:200]}")
                time.sleep(delay)
                delay *= 2
                continue
            if resp.status_code != 200:
                raise requests.HTTPError(f"{resp.status_code}: {resp.text[:300]}", response=resp)
            data = resp.json()
            return self._extract_image(data)
        raise RetryableError("retry exhausted")

    @staticmethod
    def _extract_image(data: dict) -> Image.Image:
        for cand in data.get("candidates", []):
            content = cand.get("content", {})
            for part in content.get("parts", []):
                inline = part.get("inlineData") or part.get("inline_data")
                if inline and inline.get("data"):
                    raw = base64.b64decode(inline["data"])
                    return Image.open(io.BytesIO(raw))
        finish = [c.get("finishReason") for c in data.get("candidates", [])]
        feedback = data.get("promptFeedback")
        raise RuntimeError(f"응답에 이미지가 없음 (finishReason={finish}, promptFeedback={feedback})")


class RetryableError(Exception):
    pass


class QuotaError(Exception):
    """할당량 0 또는 요금제 제한: 재시도해도 소용없다."""


# ============================================================ 실행

def report(assets: list[Asset]) -> None:
    rows = []
    for a in assets:
        if a.path.exists():
            try:
                with Image.open(a.path) as im:
                    im.load()
                    mode = im.mode
                    size = f"{im.width}x{im.height}"
                    if im.mode == "RGBA":
                        alpha = im.getchannel("A")
                        hist = alpha.histogram()
                        total = im.width * im.height
                        transparent_pct = 100.0 * sum(hist[:16]) / total
                        alpha_txt = f"{transparent_pct:5.1f}% transparent"
                    else:
                        alpha_txt = "no alpha"
                    ok = (im.width, im.height) == a.size and mode == "RGBA"
                    rows.append((a.name, "OK" if ok else "CHECK", size, mode, alpha_txt))
            except Exception as e:  # noqa: BLE001
                rows.append((a.name, "BROKEN", "-", "-", str(e)[:40]))
        else:
            rows.append((a.name, "missing", f"({a.size[0]}x{a.size[1]})", "-", "placeholder"))
    w = max(len(r[0]) for r in rows)
    print(f"\n{'asset':<{w}}  status   size        mode  alpha")
    print("-" * (w + 44))
    for name, st, size, mode, alpha in rows:
        print(f"{name:<{w}}  {st:<8} {size:<11} {mode:<5} {alpha}")


def selftest() -> int:
    """API 없이 후처리 함수를 검증한다."""
    failures = 0

    def check(label: str, ok: bool) -> None:
        nonlocal failures
        print(("PASS " if ok else "FAIL ") + label)
        if not ok:
            failures += 1

    # 크로마키: 마젠타 배경 위 갈색 원
    img = Image.new("RGB", (120, 100), KEY_COLOR)
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    d.ellipse((30, 20, 90, 80), fill=(140, 90, 50))
    check("looks_like_key_background", looks_like_key_background(img))
    keyed = chroma_key(img)
    check("chroma: corner transparent", keyed.getpixel((1, 1))[3] == 0)
    check("chroma: center opaque", keyed.getpixel((60, 50))[3] == 255)
    cropped = autocrop(keyed)
    check("autocrop: ~61x61", abs(cropped.width - 61) <= 2 and abs(cropped.height - 61) <= 2)
    fitted = fit_to(cropped, (88, 156), "bottom")
    check("fit bottom: size", fitted.size == (88, 156))
    check("fit bottom: bottom row has content", any(fitted.getpixel((x, 155))[3] > 0 for x in range(88)))
    check("fit bottom: top row empty", all(fitted.getpixel((x, 0))[3] == 0 for x in range(88)))
    # 진짜 알파가 있으면 크로마키를 건너뛰는지
    rgba = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    check("has_real_alpha", has_real_alpha(rgba) and not has_real_alpha(img))
    # 심리스: 좌우 경계 차이가 원본보다 작아야
    grad = Image.new("RGB", (200, 40))
    gp = grad.load()
    for x in range(200):
        for y in range(40):
            gp[x, y] = (x, 100, 255 - x)
    seam = make_seamless_x(grad)
    def edge_diff(im: Image.Image) -> float:
        p = im.convert("RGB").load()
        return sum(abs(p[0, y][0] - p[im.width - 1, y][0]) for y in range(im.height)) / im.height
    check(f"seamless: edge diff {edge_diff(grad):.0f} → {edge_diff(seam):.0f}", edge_diff(seam) < edge_diff(grad) * 0.2)
    check("seamless: size kept", seam.size == grad.size)
    # cover
    cov = fit_to(Image.new("RGB", (1024, 576), (10, 20, 30)), (900, 560), "cover")
    check("fit cover: size", cov.size == (900, 560))
    # 프롬프트 구성
    a = ASSETS[0]
    p = build_prompt(a, True)
    check("prompt has style prefix + reference hint", STYLE_PREFIX[:10] in p and "reference image" in p)
    pc = build_prompt(next(x for x in ASSETS if x.transparent and x.seamless), False)
    check("prompt has chroma + seamless hints", "#FF00FF" in pc and "tileable" in pc)
    print(f"\nselftest: {failures} failure(s)")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Gemini 로 게임 에셋 생성")
    ap.add_argument("--force", action="store_true", help="이미 있는 파일도 다시 생성")
    ap.add_argument("--only", help="쉼표로 구분한 항목 이름만 처리")
    ap.add_argument("--dry-run", action="store_true", help="API 호출 없이 프롬프트만 출력")
    ap.add_argument("--selftest", action="store_true", help="후처리 함수 자가 테스트")
    ap.add_argument("--report", action="store_true", help="생성 없이 검사 표만 출력")
    ap.add_argument("--model", help="모델 이름 강제 (기본: gemini-2.5-flash-image 부터 순서대로 시도)")
    ap.add_argument("--keep-raw", action="store_true", help="후처리 전 원본을 assets/art/_raw/ 에 보관")
    ap.add_argument("--sleep", type=float, default=2.0, help="호출 사이 대기(초)")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    assets = ASSETS
    if args.only:
        wanted = {s.strip() for s in args.only.split(",") if s.strip()}
        unknown = wanted - {a.name for a in ASSETS}
        if unknown:
            print(f"알 수 없는 항목: {sorted(unknown)}", file=sys.stderr)
            return 2
        assets = [a for a in ASSETS if a.name in wanted]

    if args.report:
        report(assets)
        return 0

    ART_DIR.mkdir(parents=True, exist_ok=True)
    has_reference = REFERENCE.exists()
    if not has_reference:
        print(f"! 레퍼런스 이미지가 없습니다({REFERENCE.relative_to(ROOT)}). 스타일 문구만으로 진행하고, "
              "먼저 생성된 sky.png 를 색감 앵커로 첨부합니다.")

    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key and not args.dry_run:
        print("! GEMINI_API_KEY 가 없어 생성을 건너뜁니다. 게임은 플레이스홀더로 동작합니다.")
        report(assets)
        return 0

    client = None if args.dry_run else GeminiImageClient(api_key, args.model)
    results: dict[str, str] = {}
    for asset in assets:
        if asset.path.exists() and not args.force:
            results[asset.name] = "skip (exists)"
            print(f"- {asset.name}: 이미 있음, 건너뜀 (--force 로 재생성)")
            continue
        refs: list[Path] = []
        if has_reference:
            refs.append(REFERENCE)
        elif asset.name != "sky" and (ART_DIR / "sky.png").exists():
            refs.append(ART_DIR / "sky.png")
        if asset.use_captain_ref and (ART_DIR / "captain.png").exists():
            refs.append(ART_DIR / "captain.png")
        for extra in asset.extra_refs:
            p = ART_DIR / extra
            if p.exists():
                refs.append(p)
        prompt = build_prompt(asset, bool(refs))
        if args.dry_run:
            print(f"\n=== {asset.name} ({asset.size[0]}x{asset.size[1]}, aspect {asset.aspect}, refs={[r.name for r in refs]})\n{prompt}")
            results[asset.name] = "dry-run"
            continue
        try:
            print(f"* {asset.name}: 생성 중 ({asset.aspect}, refs={[r.name for r in refs]}) ...")
            raw, model = client.generate(prompt, refs, asset.aspect)
            if args.keep_raw:
                raw_dir = ART_DIR / "_raw"
                raw_dir.mkdir(exist_ok=True)
                raw.save(raw_dir / f"{asset.name}.png")
            out = postprocess(asset, raw)
            out.save(asset.path, "PNG", optimize=True)
            results[asset.name] = f"ok ({model}, raw {raw.width}x{raw.height})"
            print(f"  -> {asset.path.relative_to(ROOT)} {out.width}x{out.height} via {model}")
        except QuotaError as e:
            # 할당량 문제는 항목을 바꿔도 똑같이 실패하므로 나머지는 건너뛴다(API 를 헛되이 두드리지 않음)
            results[asset.name] = f"FAILED: {str(e)[:160]}"
            print(f"  !! {asset.name} 실패: {str(e)[:400]}")
            print("  !! 할당량/요금제 문제이므로 남은 항목은 건너뜁니다.")
            for rest in assets:
                if rest.name not in results:
                    results[rest.name] = "skipped (quota)"
            break
        except Exception as e:  # noqa: BLE001 - 한 항목 실패가 전체를 멈추면 안 된다
            results[asset.name] = f"FAILED: {str(e)[:160]}"
            print(f"  !! {asset.name} 실패: {str(e)[:300]}")
        time.sleep(args.sleep)

    print("\n=== 결과")
    for name, r in results.items():
        print(f"{name:<18} {r}")
    if not args.dry_run:
        report(assets)
    return 0


if __name__ == "__main__":
    sys.exit(main())
