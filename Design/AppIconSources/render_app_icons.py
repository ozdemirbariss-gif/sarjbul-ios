#!/usr/bin/env python3
"""Render the ŞarjBul app icon SVGs and iOS assets from one vector geometry.

Run from any directory with: python3 Design/AppIconSources/render_app_icons.py
Requires Pillow. The default uses the app's available-state mint; the dark
variant leaves its background transparent for iOS, and tinted is grayscale.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


SIZE = 1024
SCALE = 3
SOURCE_DIR = Path(__file__).resolve().parent
ASSET_DIR = SOURCE_DIR.parents[1] / "SarjBul/Resources/Assets.xcassets/AppIcon.appiconset"

# A single broad route draws a custom Ş. Its cedilla is the destination pin.
ROUTE = (
    ((687, 308), (617, 245), (487, 248), (389, 305)),
    ((389, 305), (278, 370), (306, 454), (455, 493)),
    ((455, 493), (508, 507), (568, 515), (619, 555)),
    ((619, 555), (731, 640), (693, 712), (601, 750)),
    ((601, 750), (505, 790), (398, 762), (332, 706)),
)
ROUTE_WIDTH = 124
Y_OFFSET = -32  # Optical centering leaves room for the Ş's destination pin.

PIN = (
    ((528, 806), (500, 806), (478, 828), (478, 856)),
    ((478, 856), (478, 882), (496, 901), (514, 922)),
    ((514, 922), (540, 899), (578, 882), (578, 856)),
    ((578, 856), (578, 828), (556, 806), (528, 806)),
)
PIN_HOLE = (528, 864, 21)

VARIANTS = (
    ("AppIcon-1024", "#B7D9C2", "#111915", "#335F48"),
    ("AppIcon-1024-dark", None, "#F7F8F3", "#B7D9C2"),
    ("AppIcon-1024-tinted", "#FFFFFF", "#202020", "#666666"),
)


def svg_path(segments: tuple) -> str:
    first = segments[0][0]
    commands = [f"M {first[0]} {first[1] + Y_OFFSET}"]
    for _, control_a, control_b, endpoint in segments:
        commands.append(
            f"C {control_a[0]} {control_a[1] + Y_OFFSET} "
            f"{control_b[0]} {control_b[1] + Y_OFFSET} "
            f"{endpoint[0]} {endpoint[1] + Y_OFFSET}"
        )
    return " ".join(commands)


def svg_for(background: str | None, ink: str, accent: str) -> str:
    background_element = (
        f'  <rect width="1024" height="1024" fill="{background}"/>\n'
        if background
        else ""
    )
    hole_x, hole_y, hole_r = PIN_HOLE
    hole_y += Y_OFFSET
    hole = (
        f"M {hole_x + hole_r} {hole_y} "
        f"A {hole_r} {hole_r} 0 1 0 {hole_x - hole_r} {hole_y} "
        f"A {hole_r} {hole_r} 0 1 0 {hole_x + hole_r} {hole_y} Z"
    )
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">\n'
        "  <title>ŞarjBul — route Ş and destination pin</title>\n"
        f"{background_element}"
        f'  <path d="{svg_path(ROUTE)}" fill="none" stroke="{ink}" '
        f'stroke-width="{ROUTE_WIDTH}" stroke-linecap="round" '
        'stroke-linejoin="round"/>\n'
        f'  <path d="{svg_path(PIN)} Z {hole}" fill="{accent}" '
        'fill-rule="evenodd"/>\n'
        "</svg>\n"
    )


def sample_curve(segments: tuple) -> list[tuple[int, int]]:
    points = []
    for start, control_a, control_b, end in segments:
        for index in range(101):
            t = index / 100
            u = 1 - t
            x = (
                u**3 * start[0]
                + 3 * u**2 * t * control_a[0]
                + 3 * u * t**2 * control_b[0]
                + t**3 * end[0]
            )
            y = (
                u**3 * start[1]
                + 3 * u**2 * t * control_a[1]
                + 3 * u * t**2 * control_b[1]
                + t**3 * end[1]
            )
            points.append((round(x * SCALE), round((y + Y_OFFSET) * SCALE)))
    return points


def render_png(background: str | None, ink: str, accent: str) -> Image.Image:
    canvas = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), background or (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    route_points = sample_curve(ROUTE)
    draw.line(route_points, fill=ink, width=ROUTE_WIDTH * SCALE, joint="curve")
    radius = ROUTE_WIDTH * SCALE / 2
    for x, y in (route_points[0], route_points[-1]):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=ink)

    pin = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    pin_draw = ImageDraw.Draw(pin)
    pin_draw.polygon(sample_curve(PIN), fill=accent)
    hole_x, hole_y, hole_r = PIN_HOLE
    hole_y += Y_OFFSET
    pin_draw.ellipse(
        (
            (hole_x - hole_r) * SCALE,
            (hole_y - hole_r) * SCALE,
            (hole_x + hole_r) * SCALE,
            (hole_y + hole_r) * SCALE,
        ),
        fill=(0, 0, 0, 0),
    )
    canvas.alpha_composite(pin)
    canvas = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    return canvas if background is None else canvas.convert("RGB")


def main() -> None:
    for name, background, ink, accent in VARIANTS:
        (SOURCE_DIR / f"{name}.svg").write_text(
            svg_for(background, ink, accent), encoding="utf-8"
        )
        render_png(background, ink, accent).save(ASSET_DIR / f"{name}.png", optimize=True)


if __name__ == "__main__":
    main()
