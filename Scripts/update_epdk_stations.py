#!/usr/bin/env python3
"""Merge the official EPDK inventory into the existing iOS station contract."""

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import unicodedata
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


def fold(value):
    value = unicodedata.normalize("NFKD", str(value).casefold().replace("ı", "i"))
    return "".join(c for c in value if c.isalnum())


def coordinate(record):
    lat, lon = record.get("enlem"), record.get("boylam")
    if (type(lat) not in (int, float) or type(lon) not in (int, float)
            or not math.isfinite(lat) or not math.isfinite(lon)
            or not 35 <= lat <= 43 or not 25 <= lon <= 45):
        raise ValueError("Invalid station coordinate")
    return lat, lon


def distance(a, b):
    lat1, lon1 = coordinate(a)
    lat2, lon2 = coordinate(b)
    x = math.radians(lon2 - lon1) * math.cos(math.radians((lat1 + lat2) / 2))
    return 6_371_000 * math.hypot(x, math.radians(lat2 - lat1))


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


def normalize(row, identifier, previous=None):
    coordinate(row)
    powers, sockets = [], set()
    for socket in row["soketler"]:
        if socket.get("soketTuru") in SOCKETS:
            sockets.add(SOCKETS[socket["soketTuru"]])
        try:
            power = float(str(socket.get("soketGucu", "")).replace(",", "."))
        except ValueError:
            continue
        if math.isfinite(power) and 0 < power <= 1500:
            powers.append((power, socket.get("soketTipi")))
    maximum = max(powers, key=lambda p: p[0]) if powers else None
    power_text = f"{maximum[0]:g} kW" if maximum else UNKNOWN
    if maximum and maximum[1] in {"AC", "DC"}:
        power_text += f" ({maximum[1]})"
    # Do not copy an old price/live status onto newly verified registry data.
    record = {
        "id": identifier, "isim": row["sarjIstasyonuAdi"], "adres": row.get("adres") or UNKNOWN,
        "enlem": row["enlem"], "boylam": row["boylam"], "hiz": power_text,
        "operator": row.get("marka") or row.get("sarjAgiIsletmecisiUnvan") or UNKNOWN,
        "soket": ", ".join(sorted(sockets)) or UNKNOWN, "fiyat": UNKNOWN,
        "kaynak": "epdk", "kaynaklar": ["epdk"],
        "source_ids": {"epdk": row["sarjIstasyonuNo"]},
        "epdk_license": row.get("sarjAgiIsletmecisiLisansNo"),
        "epdk_sockets": row["soketler"], "guven_skoru": 0.88,
    }
    if previous:
        record["source_ids"] = {**previous.get("source_ids", {}), **record["source_ids"]}
        record["kaynaklar"] = sorted(set(previous.get("kaynaklar", [])) | {"epdk"})
    # Fetch time is recorded in the ingestion report, not represented as an
    # operator's real-time station update timestamp.
    return record


def merge(payload, base, identities, previous_report=None, minimum=1000):
    rows = validate_payload(payload)
    public = [r for r in rows if r["hizmetSekli"] == "HALKA_ACIK"]
    prior_count = (previous_report or {}).get("public_count", 0)
    if len(public) < max(minimum, math.ceil(prior_count * 0.85)):
        raise ValueError("EPDK public inventory unexpectedly shrank; keeping last published data")
    identities = dict(identities)
    if len(set(identities.values())) != len(identities):
        raise ValueError("EPDK identity mapping must be one-to-one")
    by_id = {r["id"]: r for r in base}
    if len(by_id) != len(base):
        raise ValueError("Duplicate IDs in supplementary source")
    occupied = set(identities.values())
    grid = defaultdict(list)
    for record in base:
        try:
            lat, lon = coordinate(record)
        except ValueError:
            continue
        grid[(int(lat * 100), int(lon * 100))].append(record)
    proposals = {}
    invalid = []
    active_numbers = {r["sarjIstasyonuNo"] for r in rows}
    ambiguous = list(set((previous_report or {}).get("ambiguous_matches", [])) & active_numbers)
    for row in rows:
        number = row["sarjIstasyonuNo"]
        try:
            lat, lon = coordinate(row)
        except ValueError:
            invalid.append(number)
            continue
        candidates = []
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for old in grid[(int(lat * 100) + dx, int(lon * 100) + dy)]:
                    # Never merge on proximity alone. Multiple stations may share a car park.
                    same_brand = bool(fold(row.get("marka", ""))) and fold(row["marka"]) == fold(old.get("operator", ""))
                    same_name = fold(row["sarjIstasyonuAdi"]) == fold(old.get("isim", ""))
                    metres = distance(row, old)
                    if same_brand and (metres <= 40 or (same_name and metres <= 150)):
                        candidates.append(old["id"])
        if len(candidates) == 1:
            proposals[number] = candidates[0]
        elif candidates:
            ambiguous.append(number)
    claims = Counter(proposals.values())
    for number, identifier in proposals.items():
        if claims[identifier] == 1 and number not in identities and identifier not in occupied:
            identities[number] = identifier
        elif claims[identifier] > 1:
            ambiguous.append(number)
    if len(invalid) > len(rows) * 0.01:
        raise ValueError("Too many invalid EPDK coordinates; publication refused")
    # Mapped private/removed stations must not reappear from the supplementary feed.
    reserved = set(identities.values())
    output = {key: row for key, row in by_id.items() if key not in reserved}
    for row in public:
        number = row["sarjIstasyonuNo"]
        if number in invalid:
            continue
        identifier = identities.get(number, "epdk_" + number.split("/")[1])
        if identifier in output:
            raise ValueError("EPDK ID collides with supplementary station ID")
        identities[number] = identifier
        output[identifier] = normalize(row, identifier, by_id.get(identifier))
    # Invalid coordinates are quarantined, never geocoded speculatively.
    report = {
        "endpoint": ENDPOINT, "total_count": len(rows), "public_count": len(public),
        "private_count": len(rows) - len(public),
        "socket_count": sum(len(r["soketler"]) for r in rows),
        "public_socket_count": sum(len(r["soketler"]) for r in public),
        "invalid_coordinates": sorted(invalid), "ambiguous_matches": sorted(set(ambiguous)),
        "supplementary_source_count": len(base),
        "epdk_published_count": sum(r["kaynak"] == "epdk" for r in output.values()),
        "published_count": len(output),
    }
    return sorted(output.values(), key=lambda r: r["id"]), dict(sorted(identities.items())), report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--input", type=Path, help="Saved API response; makes no network request")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--identities", type=Path, default=Path("Data/epdk-identities.json"))
    parser.add_argument("--report", type=Path, default=Path("Data/epdk-ingestion-report.json"))
    parser.add_argument("--raw-output", type=Path, help="Archive response outside the app bundle")
    args = parser.parse_args()
    payload = read_json(args.input) if args.input else fetch_payload()
    identities = read_json(args.identities) if args.identities.exists() else {}
    previous = read_json(args.report) if args.report.exists() else None
    base = read_json(args.base)
    minimum_base = max(1000, math.ceil((previous or {}).get("supplementary_source_count", 0) * 0.85))
    if not isinstance(base, list) or len(base) < minimum_base:
        raise ValueError("Supplementary source unexpectedly shrank; publication refused")
    records, identities, report = merge(payload, base, identities, previous)
    report["fetched_at"] = datetime.now(timezone.utc).isoformat()
    report["payload_sha256"] = hashlib.sha256(json.dumps(payload["data"], sort_keys=True).encode()).hexdigest()
    if args.raw_output:
        write_json(args.raw_output, payload)
    write_json(args.output, records)
    write_json(args.identities, identities)
    write_json(args.report, report)
    print(f"EPDK: {report['public_count']} public, {report['private_count']} private; "
          f"published: {len(records)}; ambiguous: {len(report['ambiguous_matches'])}")


if __name__ == "__main__":
    main()
