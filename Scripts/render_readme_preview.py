from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Docs" / "screenshots" / "sarjbul-ios-preview.png"
TOKENS_PATH = ROOT / "SarjBul" / "Resources" / "design-tokens.json"
TOKENS = json.loads(TOKENS_PATH.read_text(encoding="utf-8"))


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def blend(foreground: tuple[int, int, int], background: tuple[int, int, int], opacity: float) -> tuple[int, int, int]:
    return tuple(int(foreground[index] * opacity + background[index] * (1 - opacity)) for index in range(3))


RAW_BG = hex_to_rgb(TOKENS["colors"]["background"]["hex"])


def token_rgb(name: str, base: tuple[int, int, int] = RAW_BG) -> tuple[int, int, int]:
    token = TOKENS["colors"][name]
    return blend(hex_to_rgb(token["hex"]), base, float(token.get("opacity", 1.0)))


BG = token_rgb("background")
SURFACE = token_rgb("surface")
SURFACE_SOFT = token_rgb("surfaceSoft")
INK = token_rgb("text")
MUTED = token_rgb("textMuted")
ACCENT = token_rgb("primary")
PRIMARY_DEEP = token_rgb("primaryDeep")
ELECTRIC = token_rgb("electricBlue")
NAVY = ELECTRIC
LINE = token_rgb("line")
RADII = {key: int(value) for key, value in TOKENS["radius"].items()}
SHADOWS = TOKENS["shadows"]
FONTS = TOKENS["fonts"]


def shadow_rgba(name: str) -> tuple[int, int, int, int]:
    shadow = SHADOWS[name]
    color = hex_to_rgb(shadow["color"])
    alpha = int(255 * float(shadow["opacity"]))
    return (*color, alpha)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    family = FONTS["display"] if bold else FONTS["body"]
    suffixes = [" Bold", "-Bold", ""] if bold else ["", " Regular", "-Regular"]
    preferred = []
    for suffix in suffixes:
        preferred.extend(
            [
                f"/Library/Fonts/{family}{suffix}.ttf",
                f"/Library/Fonts/{family}{suffix}.otf",
                f"/System/Library/Fonts/Supplemental/{family}{suffix}.ttf",
                f"/System/Library/Fonts/Supplemental/{family}{suffix}.otf",
            ]
        )
    candidates = [
        *preferred,
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Helvetica.ttf",
        "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    return ImageFont.load_default(size=size)


F = {
    "title": font(48, True),
    "h1": font(33, True),
    "h2": font(24, True),
    "body": font(16, False),
    "body_b": font(16, True),
    "small": font(12, False),
    "small_b": font(12, True),
    "tiny": font(9, True),
}


def rounded(draw: ImageDraw.ImageDraw, box, radius=RADII["lg"], fill=SURFACE, outline=LINE, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def gradient(size, left=ACCENT, right=NAVY):
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for x in range(w):
        t = x / max(1, w - 1)
        color = tuple(int(left[i] * (1 - t) + right[i] * t) for i in range(3))
        for y in range(h):
            px[x, y] = (*color, 255)
    return img


def text(draw, xy, value, fill=INK, font_key="body", anchor=None, align="left"):
    draw.text(xy, value, fill=fill, font=F[font_key], anchor=anchor, align=align)


def phone(canvas, x, y, title):
    draw = ImageDraw.Draw(canvas)
    text(draw, (x + 18, y - 34), title, fill=NAVY, font_key="h2")
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x + 6, y + 8, x + 326, y + 708), radius=RADII["screen"], fill=shadow_rgba("soft"))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    rounded(draw, (x, y, x + 320, y + 700), radius=RADII["screen"], fill=SURFACE, outline=LINE, width=2)
    rounded(draw, (x + 10, y + 10, x + 310, y + 690), radius=RADII["card"], fill=BG, outline=None, width=0)
    text(draw, (x + 28, y + 32), "9:41", font_key="small_b")
    text(draw, (x + 238, y + 32), "5G  Wi-Fi  ▯", font_key="tiny")
    return (x + 22, y + 58, x + 298, y + 660)


def pill(canvas, box, label, active=False):
    draw = ImageDraw.Draw(canvas)
    fill = ACCENT if active else SURFACE
    rounded(draw, box, radius=RADII["md"], fill=fill, outline=LINE)
    cx = (box[0] + box[2]) // 2
    cy = (box[1] + box[3]) // 2
    text(draw, (cx, cy), label, fill=INK if active else MUTED, font_key="small_b", anchor="mm")


def primary(canvas, box, label):
    g = gradient((box[2] - box[0], box[3] - box[1]))
    mask = Image.new("L", g.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, g.size[0], g.size[1]), radius=RADII["lg"], fill=255)
    canvas.paste(g, (box[0], box[1]), mask)
    text(ImageDraw.Draw(canvas), ((box[0] + box[2]) // 2, (box[1] + box[3]) // 2), label, font_key="body_b", anchor="mm")


def home(canvas, x, y):
    area = phone(canvas, x, y, "Ana Sayfa")
    draw = ImageDraw.Draw(canvas)
    ax, ay, _, _ = area
    pill(canvas, (ax, ay, ax + 86, ay + 54), "Yakın", True)
    pill(canvas, (ax + 94, ay, ax + 180, ay + 54), "Hızlı")
    pill(canvas, (ax + 188, ay, ax + 274, ay + 54), "Uygun")

    card = (ax, ay + 76, ax + 276, ay + 222)
    rounded(draw, card, radius=RADII["xl"])
    draw.ellipse((ax + 18, ay + 98, ax + 66, ay + 146), fill=NAVY)
    draw.ellipse((ax + 34, ay + 114, ax + 50, ay + 130), outline=SURFACE, width=2)
    draw.line((ax + 26, ay + 122, ax + 58, ay + 122), fill=SURFACE, width=2)
    draw.line((ax + 42, ay + 106, ax + 42, ay + 138), fill=SURFACE, width=2)
    text(draw, (ax + 83, ay + 94), "Nereden başlıyorsun?", font_key="body_b")
    text(draw, (ax + 83, ay + 120), "38.3939, 27.1891", fill=MUTED, font_key="small_b")
    primary(canvas, (ax + 18, ay + 158, ax + 258, ay + 204), "Konumumu kullan")

    text(draw, (ax + 4, ay + 250), "SÜRÜŞ PROFİLİ", fill=PRIMARY_DEEP, font_key="small_b")
    profile = (ax, ay + 276, ax + 276, ay + 560)
    rounded(draw, profile, radius=RADII["xl"])
    text(draw, (ax + 18, ay + 298), "Şarj %", font_key="body_b")
    text(draw, (ax + 238, ay + 298), "%30", font_key="body_b")
    draw.line((ax + 20, ay + 338, ax + 250, ay + 338), fill=LINE, width=6)
    draw.line((ax + 20, ay + 338, ax + 92, ay + 338), fill=ACCENT, width=6)
    draw.ellipse((ax + 85, ay + 326, ax + 110, ay + 351), fill=ELECTRIC)
    draw.arc((ax + 26, ay + 374, ax + 126, ay + 474), -90, 18, fill=ACCENT, width=12)
    text(draw, (ax + 76, ay + 416), "%30", font_key="h2", anchor="mm")
    text(draw, (ax + 156, ay + 386), "Seçili batarya seviyesi", fill=MUTED, font_key="small_b")
    text(draw, (ax + 156, ay + 414), "Yola hazır", font_key="h2")
    pill(canvas, (ax + 20, ay + 496, ax + 122, ay + 542), "75 kWh")
    pill(canvas, (ax + 136, ay + 496, ax + 258, ay + 542), "16.9 kWh")
    primary(canvas, (ax, ay + 580, ax + 276, ay + 632), "Şarj Bul")


def route(canvas, x, y):
    area = phone(canvas, x, y, "Rota Kartı")
    draw = ImageDraw.Draw(canvas)
    ax, ay, _, _ = area
    card = (ax, ay, ax + 276, ay + 598)
    rounded(draw, card, radius=RADII["xl"])
    map_box = (ax + 14, ay + 14, ax + 262, ay + 184)
    rounded(draw, map_box, radius=RADII["lg"], fill=SURFACE_SOFT, outline=None)
    for i in range(6):
        yy = map_box[1] + 24 + i * 24
        draw.line((map_box[0] + 8, yy, map_box[2] - 8, yy + 6), fill=LINE, width=1)
    route_points = [(ax + 48, ay + 132), (ax + 116, ay + 100), (ax + 168, ay + 114), (ax + 214, ay + 66), (ax + 238, ay + 56)]
    draw.line(route_points, fill=NAVY, width=5, joint="curve")
    draw.ellipse((ax + 38, ay + 122, ax + 58, ay + 142), fill=ACCENT, outline=SURFACE, width=4)
    draw.ellipse((ax + 230, ay + 48, ax + 248, ay + 66), fill=NAVY, outline=SURFACE, width=3)
    draw.ellipse((ax + 210, ay + 22, ax + 264, ay + 76), fill=SURFACE)
    text(draw, (ax + 237, ay + 42), "57", font_key="h2", anchor="mm")
    text(draw, (ax + 237, ay + 62), "SKOR", fill=MUTED, font_key="tiny", anchor="mm")
    text(draw, (ax + 20, ay + 220), "2.2 km", font_key="title")
    text(draw, (ax + 22, ay + 274), "3 dk · varış %26", fill=MUTED, font_key="body_b")
    text(draw, (ax + 22, ay + 314), "Oyak Buca Konutları 2. Etap", font_key="body_b")
    text(draw, (ax + 22, ay + 340), "otoWATT", fill=MUTED, font_key="small_b")
    pill(canvas, (ax + 20, ay + 372, ax + 96, ay + 432), "GÜÇ\n22 kW")
    pill(canvas, (ax + 106, ay + 372, ax + 182, ay + 432), "SOKET\nCCS")
    pill(canvas, (ax + 192, ay + 372, ax + 262, ay + 432), "FİYAT\nBilinmiyor")
    pill(canvas, (ax + 20, ay + 452, ax + 130, ay + 482), "Varış güvenli")
    pill(canvas, (ax + 142, ay + 452, ax + 252, ay + 482), "Canlı veri yok")
    primary(canvas, (ax + 20, ay + 504, ax + 256, ay + 552), "Rotayı Aç")


def lounge(canvas, x, y):
    area = phone(canvas, x, y, "Salon")
    draw = ImageDraw.Draw(canvas)
    ax, ay, _, _ = area
    text(draw, (ax, ay), "ŞARJ ARASI", fill=PRIMARY_DEEP, font_key="small_b")
    text(draw, (ax, ay + 36), "Salon", fill=MUTED, font_key="title")
    text(draw, (ax, ay + 96), "Aracın dolarken reflekslerini açık\ntutan kısa ve sürprizli bir oyun.", fill=MUTED, font_key="body_b")
    panel = (ax, ay + 164, ax + 276, ay + 496)
    rounded(draw, panel, radius=RADII["xl"])
    text(draw, (ax + 20, ay + 188), "VOLT DASH", fill=NAVY, font_key="small_b")
    text(draw, (ax + 20, ay + 220), "Hazır", font_key="h1")
    text(draw, (ax + 226, ay + 190), "SKOR 0", font_key="small_b", anchor="mm")
    game = (ax + 20, ay + 264, ax + 256, ay + 446)
    rounded(draw, game, radius=RADII["lg"], fill=BG)
    draw.line((ax + 42, ay + 410, ax + 236, ay + 410), fill=LINE, width=3)
    draw.ellipse((ax + 66, ay + 360, ax + 110, ay + 404), fill=ACCENT, outline=SURFACE, width=4)
    draw.polygon(
        [
            (ax + 89, ay + 368),
            (ax + 80, ay + 386),
            (ax + 88, ay + 386),
            (ax + 84, ay + 398),
            (ax + 98, ay + 378),
            (ax + 90, ay + 378),
        ],
        fill=NAVY,
    )
    rounded(draw, (ax + 206, ay + 336, ax + 242, ay + 410), radius=RADII["sm"], fill=ELECTRIC, outline=None)
    primary(canvas, (ax + 48, ay + 524, ax + 228, ay + 578), "Başlat")


def account(canvas, x, y):
    area = phone(canvas, x, y, "Hesap")
    draw = ImageDraw.Draw(canvas)
    ax, ay, _, _ = area
    text(draw, (ax, ay), "Hesap", font_key="title")
    panel = (ax, ay + 78, ax + 276, ay + 420)
    rounded(draw, panel, radius=RADII["xl"])
    pill(canvas, (ax + 18, ay + 100, ax + 258, ay + 142), "Giriş        Kayıt        Sıfırla")
    rounded(draw, (ax + 18, ay + 170, ax + 258, ay + 222), radius=RADII["md"], fill=SURFACE, outline=LINE)
    text(draw, (ax + 36, ay + 188), "E-posta", fill=MUTED, font_key="body")
    rounded(draw, (ax + 18, ay + 240, ax + 258, ay + 292), radius=RADII["md"], fill=SURFACE, outline=LINE)
    text(draw, (ax + 36, ay + 258), "Şifre", fill=MUTED, font_key="body")
    primary(canvas, (ax + 18, ay + 318, ax + 258, ay + 370), "Giriş yap")
    text(draw, (ax + 20, ay + 456), "Favoriler ve durum bildirimleri\nhesapla senkronize edilir.", fill=MUTED, font_key="body_b")


def main():
    from PIL import ImageFilter

    globals()["ImageFilter"] = ImageFilter
    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", (1480, 880), BG)
    draw = ImageDraw.Draw(canvas)
    text(draw, (52, 34), "SarjBul iOS Preview", font_key="title")
    text(draw, (54, 88), "SwiftUI uygulamasının güncel ana akışı, rota kartı, Salon oyunu ve hesap ekranı.", fill=MUTED, font_key="body")
    home(canvas, 62, 150)
    route(canvas, 420, 150)
    lounge(canvas, 778, 150)
    account(canvas, 1136, 150)
    canvas.convert("RGB").save(OUT, quality=94)
    print(OUT)


if __name__ == "__main__":
    main()
