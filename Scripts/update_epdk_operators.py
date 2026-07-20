#!/usr/bin/env python3
"""Refresh the bundled EPDK charging-network license snapshot."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import urllib.request


ENDPOINT = "https://apigateway.epdk.gov.tr/sarjAgiIsletmeciLisansiSorgula"
SOURCE_PAGE = "https://www.epdk.gov.tr/Detay/Icerik/3-0-226/web-servisler"


def fetch_payload() -> dict:
    body = json.dumps({"lisansDurumu": ["ONAYLANDI"]}).encode("utf-8")
    request = urllib.request.Request(
        ENDPOINT,
        data=body,
        headers={"Content-Type": "application/json", "User-Agent": "SarjBul-data-refresh/1.0"},
        method="GET",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def build_snapshot(payload: dict) -> dict:
    if payload.get("statusCode") != 200:
        raise RuntimeError(f"EPDK response failed: {payload.get('statusDescription') or payload}")

    licenses = []
    for item in payload.get("data", []):
        brands = sorted(
            {
                str(brand.get("markaAdi", "")).strip()
                for brand in item.get("markalar", [])
                if str(brand.get("markaAdi", "")).strip()
            },
            key=str.casefold,
        )
        licenses.append(
            {
                "license_number": str(item.get("lisansNo", "")).strip(),
                "holder": str(item.get("lisansSahibiUnvani", "")).strip(),
                "brands": brands,
                "valid_from": str(item.get("baslangicTarihi", "")).strip(),
                "valid_until": str(item.get("bitisTarihi", "")).strip(),
            }
        )

    licenses.sort(key=lambda item: (item["holder"].casefold(), item["license_number"]))
    return {
        "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "source": SOURCE_PAGE,
        "endpoint": ENDPOINT,
        "license_count": len(licenses),
        "licenses": licenses,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        type=pathlib.Path,
        help="Use a previously downloaded EPDK response instead of the network.",
    )
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=pathlib.Path("SarjBul/Resources/epdk-licensed-operators.json"),
    )
    args = parser.parse_args()

    payload = json.loads(args.input.read_text(encoding="utf-8")) if args.input else fetch_payload()
    snapshot = build_snapshot(payload)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {snapshot['license_count']} active EPDK licenses to {args.output}")


if __name__ == "__main__":
    main()
