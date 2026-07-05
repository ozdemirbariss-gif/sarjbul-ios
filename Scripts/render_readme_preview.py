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
    g = gradient((box[2] - box[0], box[3] - box[1]), left=ACCENT, right=PRIMARY_DEEP)
    mask = Image.new("L", g.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, g.size[0], g.size[1]), radius=RADII["lg"], fill=255)
    canvas.paste(g, (box[0], box[1]), mask)
    text(ImageDraw.Draw(canvas), ((box[0] + box[2]) // 2, (box[1] + box[3]) // 2), label, font_key="body_b", anchor="mm")


def bottom_nav(canvas, ax, ay, active="home"):
    draw = ImageDraw.Draw(canvas)
    nav = (ax - 4, ay + 576, ax + 280, ay + 646)
    rounded(draw, nav, radius=34, fill=ELECTRIC, outline=LINE, width=1)
    tabs = [("home", "Ana", ax + 8), ("lounge", "Salon", ax + 76), ("routes", "Rotalar", ax + 144), ("account", "Hesap", ax + 212)]
    for key, label, tx in tabs:
        fill = SURFACE if key == active else SURFACE_SOFT
        rounded(draw, (tx, ay + 586, tx + 58, ay + 636), radius=25, fill=fill, outline=LINE)
        text(draw, (tx + 29, ay + 611), label, fill=INK if key == active else MUTED, font_key="tiny", anchor="mm")


def account(canvas, x, y):
    area = phone(canvas, x, y, "Giriş")
    draw = ImageDraw.Draw(canvas)
    ax, ay, _, _ = area
    pill(canvas, (ax + 172, ay - 44, ax + 224, ay - 6), "TR", True)
    pill(canvas, (ax + 224, ay - 44, ax + 276, ay - 6), "EN")
    hero = (ax, ay + 28, ax + 276, ay + 294)
    rounded(draw, hero, radius=RADII["card"], fill=SURFACE)
    rounded(draw, (ax + 22, ay + 56, ax + 156, ay + 102), radius=23, fill=SURFACE, outline=LINE)
    draw.ellipse((ax + 42, ay + 70, ax + 66, ay + 94), fill=gradient((24, 24)).getpixel((8, 8)))
    draw.ellipse((ax + 78, ay + 77, ax + 92, ay + 91), fill=ACCENT)
    text(draw, (ax + 104, ay + 68), "ŞarjBul", font_key="h2")
    text(draw, (ax + 20, ay + 146), "Akımı", fill=MUTED, font_key="title")
    rounded(draw, (ax + 20, ay + 198, ax + 210, ay + 252), radius=RADII["md"], fill=ACCENT, outline=None)
    text(draw, (ax + 34, ay + 202), "yakala.", font_key="title")
    draw.rounded_rectangle((ax + 198, ay + 242, ax + 302, ay + 252), radius=5, fill=ACCENT)

    guest = (ax, ay + 318, ax + 276, ay + 446)
    rounded(draw, guest, radius=RADII["xl"])
    text(draw, (ax + 18, ay + 340), "En yakın şarjı hemen bul", font_key="h2")
    text(draw, (ax + 18, ay + 374), "Üyelik gerekmez. Konumunu seçip\nrotanı oluşturabilirsin.", fill=MUTED, font_key="small_b")
    primary(canvas, (ax + 18, ay + 402, ax + 258, ay + 434), "Hemen başla")

    auth = (ax, ay + 474, ax + 276, ay + 650)
    rounded(draw, auth, radius=RADII["xl"])
    draw.line((ax + 20, ay + 496, ax + 256, ay + 496), fill=LINE, width=2)
    text(draw, (ax + 18, ay + 520), "Hesabınla devam et", font_key="h2")
    text(draw, (ax + 18, ay + 552), "Favoriler ve bildirimler hesabına kaydedilir.", fill=MUTED, font_key="small_b")
    pill(canvas, (ax + 18, ay + 588, ax + 128, ay + 628), "Giriş", True)
    pill(canvas, (ax + 128, ay + 588, ax + 258, ay + 628), "Kayıt")


def home(canvas, x, y):
    area = phone(canvas, x, y, "Ana Sayfa")
    draw = ImageDraw.Draw(canvas)
    ax, ay, _, _ = area
    pill(canvas, (ax + 4, ay + 8, ax + 86, ay + 72), "Yakın")
    pill(canvas, (ax + 98, ay + 8, ax + 180, ay + 72), "Hızlı")
    pill(canvas, (ax + 192, ay + 8, ax + 274, ay + 72), "Uygun")

    text(draw, (ax, ay + 118), "SÜRÜŞ PROFİLİ", fill=PRIMARY_DEEP, font_key="small_b")
    profile = (ax, ay + 154, ax + 276, ay + 456)
    rounded(draw, profile, radius=RADII["xl"])
    text(draw, (ax + 18, ay + 176), "Şarj %", fill=MUTED, font_key="body_b")
    text(draw, (ax + 138, ay + 194), "30", fill=MUTED, font_key="body_b", anchor="mm")
    draw.line((ax + 20, ay + 218, ax + 250, ay + 218), fill=LINE, width=5)
    draw.line((ax + 20, ay + 218, ax + 100, ay + 218), fill=ACCENT, width=5)
    draw.ellipse((ax + 92, ay + 206, ax + 118, ay + 232), fill=ELECTRIC)
    draw.arc((ax + 28, ay + 274, ax + 118, ay + 364), -90, 18, fill=ACCENT, width=12)
    text(draw, (ax + 73, ay + 314), "%30", font_key="h2", anchor="mm")
    text(draw, (ax + 138, ay + 290), "Seçili batarya seviyesi", fill=MUTED, font_key="small_b")
    text(draw, (ax + 138, ay + 320), "Yola hazır", font_key="h2")
    draw.line((ax + 18, ay + 382, ax + 258, ay + 382), fill=LINE, width=1)
    pill(canvas, (ax + 18, ay + 402, ax + 128, ay + 442), "75")
    pill(canvas, (ax + 148, ay + 402, ax + 258, ay + 442), "16,9")
    pill(canvas, (ax, ay + 484, ax + 276, ay + 532), "Filtreler ve sürüş ayarları")
    bottom_nav(canvas, ax, ay, "home")


def recommendation(canvas, ax, y):
    draw = ImageDraw.Draw(canvas)
    card = (ax, y, ax + 276, y + 112)
    rounded(draw, card, radius=RADII["xl"], fill=SURFACE, outline=ACCENT, width=8)
    draw.rounded_rectangle((ax, y + 64, ax + 276, y + 112), radius=22, fill=ELECTRIC)
    draw.rounded_rectangle((ax + 20, y + 22, ax + 64, y + 66), radius=16, fill=ELECTRIC)
    text(draw, (ax + 38, y + 32), "↯", fill=ACCENT, font_key="h2", anchor="mm")
    text(draw, (ax + 82, y + 22), "Akıllı menzil önerisi", fill=MUTED, font_key="small_b")
    text(draw, (ax + 82, y + 42), "100 km güvenli menzille", font_key="small_b")
    text(draw, (ax + 82, y + 58), "yola hazırsın", font_key="small_b")
    text(draw, (ax + 82, y + 78), "En Uygun İstasyonu Bul", fill=SURFACE, font_key="small_b")


def suggestion(canvas, x, y):
    area = phone(canvas, x, y, "Öneri")
    ax, ay, _, _ = area
    recommendation(canvas, ax, ay + 218)
    bottom_nav(canvas, ax, ay, "home")


def route(canvas, x, y):
    area = phone(canvas, x, y, "Rota Kartı")
    draw = ImageDraw.Draw(canvas)
    ax, ay, _, _ = area
    card = (ax, ay + 32, ax + 276, ay + 586)
    rounded(draw, card, radius=36, fill=ACCENT, outline=ACCENT, width=8)
    map_box = (ax + 10, ay + 42, ax + 266, ay + 232)
    rounded(draw, map_box, radius=RADII["lg"], fill=SURFACE_SOFT, outline=None)
    for i in range(6):
        yy = map_box[1] + 24 + i * 24
        draw.line((map_box[0] + 8, yy, map_box[2] - 8, yy + 6), fill=LINE, width=1)
    draw.line((ax + 150, ay + 222, ax + 162, ay + 70), fill=ELECTRIC, width=6)
    pill(canvas, (ax + 22, ay + 62, ax + 95, ay + 102), "59 SKOR")
    pill(canvas, (ax + 212, ay + 62, ax + 260, ay + 102), "02/80")
    pill(canvas, (ax + 24, ay + 178, ax + 118, ay + 214), "YAKLAŞIK")
    text(draw, (ax + 18, ay + 252), "1.7 km", font_key="title")
    text(draw, (ax + 18, ay + 304), "2 dk · varış %30", fill=ELECTRIC, font_key="body_b")
    pill(canvas, (ax + 18, ay + 332, ax + 118, ay + 364), "Varış %30")
    pill(canvas, (ax + 126, ay + 332, ax + 228, ay + 364), "Sapma +0.3")
    rounded(draw, (ax + 18, ay + 386, ax + 258, ay + 456), radius=RADII["lg"], fill=blend(SURFACE, ACCENT, 0.54), outline=LINE)
    text(draw, (ax + 34, ay + 400), "ŞARJ NOKTASI", fill=MUTED, font_key="small_b")
    text(draw, (ax + 34, ay + 422), "Marlen Residence Hotel", font_key="body_b")
    pill(canvas, (ax + 18, ay + 472, ax + 94, ay + 518), "GÜÇ\nAC")
    pill(canvas, (ax + 102, ay + 472, ax + 178, ay + 518), "SOKET\nBilinmiyor")
    pill(canvas, (ax + 186, ay + 472, ax + 258, ay + 518), "FİYAT\nBilinmiyor")
    rounded(draw, (ax + 18, ay + 536, ax + 258, ay + 582), radius=RADII["lg"], fill=ELECTRIC, outline=None)
    text(draw, (ax + 34, ay + 548), "Rotayı Aç", fill=SURFACE, font_key="body_b")
    bottom_nav(canvas, ax, ay, "routes")


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
    bottom_nav(canvas, ax, ay, "lounge")


def main():
    from PIL import ImageFilter

    globals()["ImageFilter"] = ImageFilter
    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", (1480, 880), BG)
    draw = ImageDraw.Draw(canvas)
    text(draw, (52, 34), "SarjBul iOS Preview", font_key="title")
    text(draw, (54, 88), "Python tarafındaki beyaz/neon arayüzle hizalanan SwiftUI giriş, sürüş profili ve rota akışı.", fill=MUTED, font_key="body")
    account(canvas, 62, 150)
    home(canvas, 420, 150)
    suggestion(canvas, 778, 150)
    route(canvas, 1136, 150)
    canvas.convert("RGB").save(OUT, quality=94)
    print(OUT)


if __name__ == "__main__":
    main()
