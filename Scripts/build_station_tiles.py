#!/usr/bin/env python3
import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"


def geohash(latitude: float, longitude: float, precision: int = 4) -> str:
    latitude_range = [-90.0, 90.0]
    longitude_range = [-180.0, 180.0]
    bits = [16, 8, 4, 2, 1]
    result = []
    bit = 0
    value = 0
    use_longitude = True
    while len(result) < precision:
        bounds = longitude_range if use_longitude else latitude_range
        coordinate = longitude if use_longitude else latitude
        middle = (bounds[0] + bounds[1]) / 2
        if coordinate >= middle:
            value |= bits[bit]
            bounds[0] = middle
        else:
            bounds[1] = middle
        use_longitude = not use_longitude
        if bit < 4:
            bit += 1
        else:
            result.append(BASE32[value])
            bit = 0
            value = 0
    return "".join(result)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--precision", type=int, default=3)
    args = parser.parse_args()

    records = json.loads(args.input.read_text(encoding="utf-8"))
    groups = {}
    for record in records:
        key = geohash(float(record["enlem"]), float(record["boylam"]), args.precision)
        groups.setdefault(key, []).append(record)

    if args.output.exists():
        shutil.rmtree(args.output)
    args.output.mkdir(parents=True)
    tiles = []
    for key, values in sorted(groups.items()):
        filename = f"station_tile_{key}.json"
        payload = json.dumps(values, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        (args.output / filename).write_bytes(payload)
        tiles.append({
            "geohash": key,
            "file": filename,
            "record_count": len(values),
            "sha256": hashlib.sha256(payload).hexdigest(),
        })

    manifest = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "total_records": len(records),
        "base_url": args.base_url.rstrip("/") + "/",
        "tiles": tiles,
    }
    (args.output / "station-tiles-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"{len(records)} records -> {len(tiles)} geohash tiles")


if __name__ == "__main__":
    main()
