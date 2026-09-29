#!/usr/bin/env python3
"""Export the geometric ŞarjBul energy-flow mark as SVG and iOS PNG assets.

Run: python3 Design/AppIconSources/render_app_icons.py (requires Pillow).
One shared outline and diagonal aperture keep all appearances in sync.
Colors come from the app's design tokens; tinted uses their grayscale values.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


SIZE = 1024
SUPERSAMPLE = 4
MARK_SCALE = 1.16
Y_OFFSET = -28
SOURCE_DIR = Path(__file__).resolve().parent
ROOT_DIR = SOURCE_DIR.parents[1]
ASSET_DIR = ROOT_DIR / "SarjBul/Resources/Assets.xcassets/AppIcon.appiconset"
COLORS = json.loads(
    (ROOT_DIR / "SarjBul/Resources/design-tokens.json").read_text(encoding="utf-8")
)["colors"]
CANVAS = COLORS["canvas"]["hex"]
MARK_INK = COLORS["actionPrimary"]["hex"]

# Two opposing bends, 136-unit ribbon thickness, and 45-degree terminals.
# The outline is rotationally symmetric about (512, 540).
OUTLINE = (
    ("M", 772, 256),
    ("L", 636, 392),
    ("L", 420, 392),
    ("C", 396, 392, 380, 408, 380, 432),
    ("C", 380, 456, 396, 472, 420, 472),
    ("L", 604, 472),
    ("C", 708, 472, 780, 540, 780, 648),
    ("C", 780, 756, 708, 824, 604, 824),
    ("L", 252, 824),
    ("L", 388, 688),
    ("L", 604, 688),
    ("C", 628, 688, 644, 672, 644, 648),
    ("C", 644, 624, 628, 608, 604, 608),
    ("L", 420, 608),
    ("C", 316, 608, 244, 540, 244, 432),
    ("C", 244, 324, 316, 256, 420, 256),
    ("Z",),
)
# The open diagonal separates the two contacts and suggests an energy pulse.
APERTURE = ((536, 472), (624, 472), (488, 608), (400, 608))


def grayscale(color: str) -> str:
    red, green, blue = (int(color[index : index + 2], 16) for index in (1, 3, 5))
    value = round(0.2126 * red + 0.7152 * green + 0.0722 * blue)
    return "#" + f"{value:02X}" * 3


VARIANTS = (
    ("AppIcon-1024", CANVAS, MARK_INK),
    ("AppIcon-1024-dark", None, MARK_INK),
    ("AppIcon-1024-tinted", grayscale(CANVAS), grayscale(MARK_INK)),
)


def transform(x: float, y: float) -> tuple[float, float]:
    return (
        512 + (x - 512) * MARK_SCALE,
        512 + (y + Y_OFFSET - 512) * MARK_SCALE,
    )


def svg_path() -> str:
    commands = []
    for command in OUTLINE:
        coordinates = []
        for index in range(1, len(command), 2):
            coordinates.extend(transform(command[index], command[index + 1]))
        commands.append(command[0] + " " + " ".join(f"{v:.2f}" for v in coordinates))
    return " ".join(commands).strip()


def svg_for(background: str | None, ink: str) -> str:
    aperture = " ".join(f"{x:.2f},{y:.2f}" for x, y in map(lambda p: transform(*p), APERTURE))
    background_element = (
        f'  <rect width="1024" height="1024" fill="{background}"/>\n'
        if background
        else ""
    )
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">\n'
        "  <title>ŞarjBul — energy flow mark</title>\n"
        "  <defs>\n"
        '    <mask id="energy-gap" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">\n'
        '      <rect width="1024" height="1024" fill="#FFFFFF"/>\n'
        f'      <polygon points="{aperture}" fill="#000000"/>\n'
        "    </mask>\n"
        "  </defs>\n"
        f"{background_element}"
        f'  <path d="{svg_path()}" fill="{ink}" mask="url(#energy-gap)"/>\n'
        "</svg>\n"
    )


def outline_points() -> list[tuple[float, float]]:
    points = []
    current = (0, 0)
    for command in OUTLINE:
        if command[0] in ("M", "L"):
            current = command[1:3]
            points.append(transform(*current))
        elif command[0] == "C":
            first, second, end = command[1:3], command[3:5], command[5:7]
            for index in range(1, 129):
                t = index / 128
                u = 1 - t
                point = tuple(
                    u**3 * current[axis]
                    + 3 * u**2 * t * first[axis]
                    + 3 * u * t**2 * second[axis]
                    + t**3 * end[axis]
                    for axis in (0, 1)
                )
                points.append(transform(*point))
            current = end
    return points


def render_png(background: str | None, ink: str) -> Image.Image:
    high_size = (SIZE * SUPERSAMPLE, SIZE * SUPERSAMPLE)
    silhouette = Image.new("L", high_size, 0)
    draw = ImageDraw.Draw(silhouette)
    draw.polygon([(x * SUPERSAMPLE, y * SUPERSAMPLE) for x, y in outline_points()], fill=255)
    draw.polygon(
        [(x * SUPERSAMPLE, y * SUPERSAMPLE) for x, y in map(lambda p: transform(*p), APERTURE)],
        fill=0,
    )
    foreground = Image.new("RGBA", high_size, ink)
    foreground.putalpha(silhouette)
    canvas = Image.new("RGBA", high_size, background or (0, 0, 0, 0))
    canvas.alpha_composite(foreground)
    canvas = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    return canvas if background is None else canvas.convert("RGB")


def main() -> None:
    for name, background, ink in VARIANTS:
        (SOURCE_DIR / f"{name}.svg").write_text(svg_for(background, ink), encoding="utf-8")
        render_png(background, ink).save(ASSET_DIR / f"{name}.png", optimize=True)


if __name__ == "__main__":
    main()
