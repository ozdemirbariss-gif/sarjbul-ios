"""Extract named, real simulator captures from xcresulttool's attachment manifest."""

import argparse
import json
from pathlib import Path
import shutil


NAMES = {"home", "routes", "lounge", "account", "arrival-outcome", "charging-suggestion", "charging-suggestion-en"}


def objects(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from objects(child)
    elif isinstance(value, list):
        for child in value:
            yield from objects(child)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("attachments", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.attachments / "manifest.json").read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    found = set()
    for item in objects(manifest):
        title = item.get("suggestedHumanReadableName", "")
        filename = item.get("exportedFileName")
        for name in NAMES:
            prefix = f"readme-{name}"
            if filename and (title == prefix or title.startswith((prefix + ".", prefix + "_"))):
                source = (args.attachments / filename).resolve()
                if not source.is_relative_to(args.attachments.resolve()):
                    raise ValueError("Invalid attachment path")
                shutil.copyfile(source, args.output / f"{name}.png")
                found.add(name)
    if found != NAMES:
        raise SystemExit(f"Missing screenshots: {sorted(NAMES - found)}")


if __name__ == "__main__":
    main()
