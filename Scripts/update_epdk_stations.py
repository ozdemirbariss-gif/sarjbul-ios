#!/usr/bin/env python3
"""Build the iOS station inventory exclusively from the official EPDK response."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import urllib.request

ENDPOINT = "https://apigateway.epdk.gov.tr/sarjIstasyonlari"
UNKNOWN = "Bilinmiyor"
SOCKETS = {"AC_TYPE2": "Type 2", "DC_CCS": "CCS", "DC_CHADEMO": "CHAdeMO"}


def fetch_payload():
    # EPDK permits only one unfiltered request per hour, including manual runs.
    # Do not automatically retry an uncertain request or an HTTP 429 response.
    request = urllib.request.Request(
        ENDPOINT, data=b"{}", method="GET",
        headers={"Content-Type": "application/json", "Accept": "application/json",
                 "User-Agent": "SarjBul-data-refresh/1.0"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        raw = response.read(50_000_001)
    if len(raw) > 50_000_000:
        raise ValueError("EPDK response exceeds size limit")
    return json.loads(raw)


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
                         encoding="utf-8")
    temporary.replace(path)


def coordinate(record):
    lat, lon = record.get("enlem"), record.get("boylam")
    if (type(lat) not in (int, float) or type(lon) not in (int, float)
            or not math.isfinite(lat) or not math.isfinite(lon)
            or not 35 <= lat <= 43 or not 25 <= lon <= 45):
        raise ValueError("Invalid station coordinate")
    return lat, lon


def validate_payload(payload):
    rows = payload.get("data")
    if (payload.get("statusCode") != 200 or payload.get("errors")
            or not isinstance(rows, list) or not rows
            or payload.get("numRows") != len(rows)):
        raise ValueError("EPDK failed or returned an incomplete inventory")
    identifiers = set()
    for row in rows:
        number = row.get("sarjIstasyonuNo", "")
        if not re.fullmatch(r"ŞRJ/\d+", number) or number in identifiers:
            raise ValueError("Missing or duplicate EPDK station number")
        identifiers.add(number)
        if row.get("hizmetSekli") not in {"HALKA_ACIK", "OZEL"}:
            raise ValueError("Unrecognized EPDK access type")
        if not isinstance(row.get("soketler"), list) or not row.get("sarjIstasyonuAdi"):
            raise ValueError("EPDK station schema changed")
    return rows


def normalize(row, observed_at=None):
    coordinate(row)
    powers, sockets = [], set()
    units = []
    for index, socket in enumerate(row["soketler"]):
        socket_id = socket.get("soketNo") or f"socket-{index}"
        socket_type = SOCKETS.get(socket.get("soketTuru"), UNKNOWN)
        if socket.get("soketTuru") in SOCKETS:
            sockets.add(SOCKETS[socket["soketTuru"]])
        try:
            power = float(str(socket.get("soketGucu", "")).replace(",", "."))
        except ValueError:
            power = None
        if power is not None and math.isfinite(power) and 0 < power <= 1500:
            powers.append((power, socket.get("soketTipi")))
        else:
            power = None
        # The public inventory has no unit identifier. Keep each socket in its
        # own unit rather than guessing which sockets share a charger.
        units.append({"id": socket_id, "powerKW": power,
                      "sockets": [{"id": socket_id, "type": socket_type}]})
    maximum = max(powers, key=lambda p: p[0]) if powers else None
    power_text = f"{maximum[0]:g} kW" if maximum else UNKNOWN
    if maximum and maximum[1] in {"AC", "DC"}:
        power_text += f" ({maximum[1]})"
    # Do not copy an old price/live status onto newly verified registry data.
    record = {
        "id": "epdk_" + row["sarjIstasyonuNo"].split("/")[1], "isim": row["sarjIstasyonuAdi"], "adres": row.get("adres") or UNKNOWN,
        "enlem": row["enlem"], "boylam": row["boylam"], "hiz": power_text,
        "operator": row.get("marka") or row.get("sarjAgiIsletmecisiUnvan") or UNKNOWN,
        "soket": ", ".join(sorted(sockets)) or UNKNOWN, "fiyat": UNKNOWN,
        "kaynak": "epdk", "kaynaklar": ["epdk"],
        "source_ids": {"epdk": row["sarjIstasyonuNo"]},
        "epdk_license": row.get("sarjAgiIsletmecisiLisansNo"),
        "epdk_sockets": row["soketler"], "guven_skoru": 0.88,
        "sarj_uniteleri": units,
    }
    if observed_at:
        record["kaynak_gozlem_tarihi"] = observed_at
    # Fetch time is recorded in the ingestion report, not represented as an
    # operator's real-time station update timestamp.
    return record


def build_inventory(payload, previous_report=None, minimum=1000, observed_at=None):
    rows = validate_payload(payload)
    public = [r for r in rows if r["hizmetSekli"] == "HALKA_ACIK"]
    prior_count = (previous_report or {}).get("public_count", 0)
    if len(public) < max(minimum, math.ceil(prior_count * 0.85)):
        raise ValueError("EPDK public inventory unexpectedly shrank; keeping last published data")
    invalid, output = [], []
    for row in rows:
        try:
            coordinate(row)
        except ValueError:
            invalid.append(row["sarjIstasyonuNo"])
            continue
        if row["hizmetSekli"] == "HALKA_ACIK":
            output.append(normalize(row, observed_at=observed_at))
    if len(invalid) > len(rows) * 0.01:
        raise ValueError("Too many invalid EPDK coordinates; publication refused")
    if len(output) < max(minimum, math.ceil(prior_count * 0.85)):
        raise ValueError("Too few valid public EPDK stations; publication refused")
    report = {
        "endpoint": ENDPOINT, "source_policy": "epdk-only-v1",
        "total_count": len(rows), "public_count": len(public),
        "private_count": len(rows) - len(public),
        "socket_count": sum(len(r["soketler"]) for r in rows),
        "public_socket_count": sum(len(r["soketler"]) for r in public),
        "invalid_coordinates": sorted(invalid),
        "epdk_published_count": len(output), "published_count": len(output),
    }
    return sorted(output, key=lambda r: r["id"]), report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="Saved EPDK API response; makes no network request")
    parser.add_argument("--observed-at", help="Original fetch time for a saved API response")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, default=Path("Data/epdk-ingestion-report.json"))
    parser.add_argument("--raw-output", type=Path, help="Archive response outside the app bundle")
    args = parser.parse_args()
    if args.input and not args.observed_at:
        parser.error("--observed-at is required with --input; replay time is not observation time")
    payload = read_json(args.input) if args.input else fetch_payload()
    previous = read_json(args.report) if args.report.exists() else None
    fetched_at = args.observed_at or datetime.now(timezone.utc).isoformat()
    # A fresh normalization is intentional: no legacy station, source ID, field,
    # proximity match or third-party identity mapping is used as an input.
    records, report = build_inventory(payload, previous, observed_at=fetched_at)
    report["fetched_at"] = fetched_at
    report["payload_sha256"] = hashlib.sha256(json.dumps(payload["data"], sort_keys=True).encode()).hexdigest()
    if args.raw_output:
        write_json(args.raw_output, payload)
    write_json(args.output, records)
    write_json(args.report, report)
    print(f"EPDK only: {len(records)} public stations; {report['private_count']} private excluded")


if __name__ == "__main__":
    main()
