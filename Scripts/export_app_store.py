"""Export native App Store screenshots and validate their size, opacity and icon.

Requires Pillow. No cropping, rescaling, retouching or generated UI is applied.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import subprocess

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
LOCALES = ("tr", "en-US")
SCREENS = ("01-home", "02-stations-map", "03-filters", "04-route", "05-charging-break")


def objects(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from objects(child)
    elif isinstance(value, list):
        for child in value:
            yield from objects(child)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("attachments", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--built-app", type=Path, required=True)
    parser.add_argument("--device", default="iPhone 17 Pro Max")
    parser.add_argument("--size", choices=("1320x2868", "1206x2622"), default="1320x2868")
    args = parser.parse_args()
    size = tuple(int(value) for value in args.size.split("x"))
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((args.attachments / "manifest.json").read_text())
    expected = {f"app-store-{locale}-{screen}": (locale, screen)
                for locale in LOCALES for screen in SCREENS}
    found = {}
    for item in objects(manifest):
        title = item.get("suggestedHumanReadableName", "")
        filename = item.get("exportedFileName")
        for prefix, (locale, screen) in expected.items():
            if not filename or not (title == prefix or title.startswith((prefix + ".", prefix + "_"))):
                continue
            source = (args.attachments / filename).resolve()
            if not source.is_relative_to(args.attachments.resolve()):
                raise ValueError("Invalid attachment path")
            destination = args.output / locale / f"{screen}.png"
            destination.parent.mkdir(parents=True, exist_ok=True)
            with Image.open(source) as capture:
                if capture.size != size:
                    raise ValueError(f"{source.name}: native size is {capture.size}, expected {size}")
                if "A" in capture.getbands() and capture.getchannel("A").getextrema() != (255, 255):
                    raise ValueError(f"{source.name}: capture contains transparent pixels")
                # Simulator PNGs may contain an opaque alpha channel. Apple disallows
                # the channel itself; losslessly keep RGB values at the native size.
                capture.convert("RGB").save(destination)
            found[prefix] = {
                "path": str(destination.relative_to(args.output)),
                "width": size[0], "height": size[1], "mode": "RGB",
                "alpha": False, "sha256": digest(destination),
                "source_sha256": digest(source),
            }
    if set(found) != set(expected):
        raise ValueError(f"Missing screenshots: {sorted(set(expected) - set(found))}")

    asset_dir = ROOT / "SarjBul/Resources/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((asset_dir / "Contents.json").read_text())
    icons = []
    icon_output = args.output / "icon"
    icon_output.mkdir(exist_ok=True)
    for item in contents["images"]:
        source = asset_dir / item["filename"]
        with Image.open(source) as icon:
            if icon.size != (1024, 1024):
                raise ValueError(f"Invalid icon size: {source.name}")
            alpha = "A" in icon.getbands()
            if not item.get("appearances") and alpha:
                raise ValueError("Default marketing icon must not have an alpha channel")
            icons.append({"path": f"icon/{source.name}", "width": 1024, "height": 1024,
                          "alpha": alpha, "appearances": item.get("appearances", []),
                          "sha256": digest(source)})
        shutil.copyfile(source, icon_output / source.name)

    with (args.built_app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    primary = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
    if primary.get("CFBundleIconName") != "AppIcon":
        raise ValueError(f"Compiled icon is not AppIcon: {primary}")
    for icon_file in primary.get("CFBundleIconFiles", []):
        if not list(args.built_app.glob(f"{icon_file}*.png")):
            raise ValueError(f"Compiled icon file missing: {icon_file}")
    if not (args.built_app / "Assets.car").is_file():
        raise ValueError("Compiled asset catalog missing")

    for locale in LOCALES:
        # This contact sheet is a review aid, never an upload screenshot.
        sheet = Image.new("RGB", (1500, 700), "#181A1C")
        draw = ImageDraw.Draw(sheet)
        for index, screen in enumerate(SCREENS):
            with Image.open(args.output / locale / f"{screen}.png") as capture:
                capture.thumbnail((276, 600), Image.Resampling.LANCZOS)
                sheet.paste(capture, (12 + index * 300, 48))
            draw.text((12 + index * 300, 18), f"{locale} / {screen}", fill="white")
        sheet.save(args.output / f"preview-{locale}.jpg", quality=92)

    record = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
        "device": args.device, "configuration": "Release",
        "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"],
        "bundle_id": info["CFBundleIdentifier"], "compiled_primary_icon": primary,
        "station_source": "Configured shipping repository and bundled EPDK station tiles; no UI-test fixtures",
        "simulated_origin": {"latitude": 38.4237, "longitude": 27.1428},
        "processing": "Native captures; opaque alpha channel removed, RGB pixels and dimensions preserved",
        "locales": list(LOCALES), "screenshots": [found[name] for name in expected], "icons": icons,
    }
    (args.output / "capture.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(f"Validated {len(found)} native {size[0]} × {size[1]} screenshots and {len(icons)} icons")


if __name__ == "__main__":
    main()
