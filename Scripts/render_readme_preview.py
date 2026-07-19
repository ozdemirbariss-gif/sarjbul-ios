from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SCREENSHOT_DIR = ROOT / "Docs" / "screenshots"
OUTPUT = SCREENSHOT_DIR / "sarjbul-ios-preview.png"
TOKENS_PATH = ROOT / "SarjBul" / "Resources" / "design-tokens.json"
SCREENS = (
    ("account.png", "Giriş"),
    ("home.png", "Ana sayfa"),
    ("routes.png", "Rotalar"),
    ("lounge.png", "Salon"),
)


def hex_color(value: str) -> tuple[int, int, int]:
    value = value.removeprefix("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "SFNSDisplay-Bold.otf" if bold else "SFNSDisplay-Regular.otf"
    path = Path("/System/Library/Fonts") / name
    if path.exists():
        return ImageFont.truetype(path, size=size)
    return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", size=size)


def rounded_phone(source: Path, width: int) -> Image.Image:
    image = Image.open(source).convert("RGB")
    height = round(width * image.height / image.width)
    image = image.resize((width, height), Image.Resampling.LANCZOS)

    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width, height), radius=46, fill=255)
    image.putalpha(mask)
    return image


def main() -> None:
    missing = [name for name, _ in SCREENS if not (SCREENSHOT_DIR / name).exists()]
    if missing:
        names = ", ".join(missing)
        raise SystemExit(f"Eksik simulator ekran goruntuleri: {names}")

    tokens = json.loads(TOKENS_PATH.read_text(encoding="utf-8"))
    background = hex_color(tokens["colors"]["background"]["hex"])
    ink = hex_color(tokens["colors"]["text"]["hex"])
    muted = hex_color(tokens["colors"]["textMuted"]["hex"])
    accent = hex_color(tokens["colors"]["primary"]["hex"])

    canvas = Image.new("RGB", (1600, 1040), background)
    draw = ImageDraw.Draw(canvas)
    draw.text((64, 46), "SarjBul iOS", fill=ink, font=load_font(48, bold=True))
    draw.rounded_rectangle((64, 112, 300, 124), radius=6, fill=accent)
    draw.text(
        (64, 146),
        "Gerçek iPhone simülatör ekranları",
        fill=muted,
        font=load_font(23),
    )

    phone_width = 342
    gap = 38
    start_x = 64
    phone_y = 230
    shadow_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_layer)

    for index, (_, label) in enumerate(SCREENS):
        x = start_x + index * (phone_width + gap)
        shadow_draw.rounded_rectangle(
            (x + 8, phone_y + 16, x + phone_width + 8, phone_y + 760),
            radius=46,
            fill=(26, 31, 24, 62),
        )
        draw.text((x, 190), label, fill=ink, font=load_font(22, bold=True))

    canvas = Image.alpha_composite(
        canvas.convert("RGBA"), shadow_layer.filter(ImageFilter.GaussianBlur(22))
    )

    for index, (name, _) in enumerate(SCREENS):
        x = start_x + index * (phone_width + gap)
        phone = rounded_phone(SCREENSHOT_DIR / name, phone_width)
        canvas.alpha_composite(phone, (x, phone_y))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUTPUT, quality=94, optimize=True)
    print(OUTPUT)


if __name__ == "__main__":
    main()
