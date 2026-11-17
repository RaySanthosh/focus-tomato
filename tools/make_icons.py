"""Draws the Focus Tomato icon set: launcher PNGs, adaptive-icon foreground, Play Store icon + feature graphic.
Run: python tools/make_icons.py   (from C:\\Play_Store_App)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "focus_tomato", "android", "app", "src", "main", "res")
STORE = os.path.join(ROOT, "store")

BG = (255, 244, 236)
TOMATO = (229, 83, 61)
TOMATO_DARK = (196, 60, 43)
LEAF = (46, 158, 106)
WHITE = (255, 255, 255)


def draw_tomato(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float) -> None:
    """Tomato body + leaf crown + a clock hand (the 'focus timer' hint)."""
    d.ellipse([cx - r, cy - r * 0.92, cx + r, cy + r * 0.92], fill=TOMATO_DARK)
    d.ellipse([cx - r * 0.96, cy - r * 0.90, cx + r * 0.90, cy + r * 0.82], fill=TOMATO)
    w = max(2, int(r * 0.11))
    d.line([cx, cy + r * 0.05, cx, cy - r * 0.45], fill=WHITE, width=w)
    d.line([cx, cy + r * 0.05, cx + r * 0.32, cy + r * 0.22], fill=WHITE, width=w)
    d.ellipse([cx - w, cy + r * 0.05 - w, cx + w, cy + r * 0.05 + w], fill=WHITE)
    top = cy - r * 0.86
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = r * 0.42 if i % 2 == 0 else r * 0.16
        pts.append((cx + rad * math.cos(ang), top + rad * math.sin(ang) * 0.55))
    d.polygon(pts, fill=LEAF)
    d.rounded_rectangle([cx - r * 0.05, top - r * 0.32, cx + r * 0.05, top], radius=r * 0.04, fill=LEAF)


def render(size: int, scale: float, bg, shape: str) -> Image.Image:
    ss = 4
    S = size * ss
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if shape == "circle":
        d.ellipse([0, 0, S - 1, S - 1], fill=bg)
    elif shape == "square":
        d.rectangle([0, 0, S, S], fill=bg)
    draw_tomato(d, S / 2, S / 2 + S * 0.04 * scale, S * 0.5 * scale)
    return img.resize((size, size), Image.LANCZOS)


def save(img: Image.Image, *parts: str) -> None:
    path = os.path.join(*parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for name, k in densities.items():
    save(render(int(48 * k), 0.62, BG, "circle"), RES, f"mipmap-{name}", "ic_launcher.png")
    save(render(int(108 * k), 0.40, None, "none"), RES, f"mipmap-{name}", "ic_launcher_foreground.png")

save(render(512, 0.62, BG, "square").convert("RGB"), STORE, "icon-512.png")

fg = Image.new("RGB", (1024, 500), BG)
icon = render(300, 0.9, None, "none")
fg.paste(icon, (70, 100), icon)
d = ImageDraw.Draw(fg)
try:
    title = ImageFont.truetype("segoeuib.ttf", 72)
    sub = ImageFont.truetype("segoeui.ttf", 32)
except OSError:
    title = sub = ImageFont.load_default()
d.text((420, 165), "Focus Tomato", font=title, fill=(60, 30, 25))
d.text((424, 265), "Simple focus timer.", font=sub, fill=(110, 80, 70))
d.text((424, 310), "No account. No ads. No tracking.", font=sub, fill=(110, 80, 70))
save(fg, STORE, "feature-graphic-1024x500.png")
