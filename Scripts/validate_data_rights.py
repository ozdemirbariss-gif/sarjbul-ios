#!/usr/bin/env python3
"""Check provider evidence and every primary/merged source before distribution."""
import argparse
import hashlib
import json
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = Path("Data/provider-rights.json")
TILES = Path("SarjBul/Resources/StationTiles")
DATA_SCOPES = {"commercial_use", "redistribution", "derived_fields", "offline_storage"}


def published_records(root):
    manifest = json.loads((root / TILES / "station-tiles-manifest.json").read_text())
    if manifest.get("source_policy") != "epdk-only-v1":
        raise ValueError("Station manifest must declare the EPDK-only source policy")
    records = []
    seen = set()
    for tile in manifest["tiles"]:
        filename = tile["file"]
        if Path(filename).name != filename or filename in seen:
            raise ValueError("Invalid or duplicate tile filename")
        seen.add(filename)
        payload = (root / TILES / filename).read_bytes()
        if hashlib.sha256(payload).hexdigest() != tile["sha256"]:
            raise ValueError("Station tile integrity mismatch")
        rows = json.loads(payload)
        if not isinstance(rows, list) or len(rows) != tile["record_count"]:
            raise ValueError("Station tile record count mismatch")
        records.extend(rows)
    if len(records) != manifest["total_records"]:
        raise ValueError("Station manifest record count mismatch")
    return records


def source_counts(records):
    if not isinstance(records, list) or not records:
        raise ValueError("Station inventory must be a nonempty list")
    primary, contributions = Counter(), Counter()
    for row in records:
        if not isinstance(row, dict):
            raise ValueError("Invalid station record")
        source, merged = row.get("kaynak"), row.get("kaynaklar", [])
        if not isinstance(source, str) or not source.strip():
            raise ValueError("Station has no primary source provenance")
        if not isinstance(merged, list) or any(not isinstance(s, str) or not s.strip() for s in merged):
            raise ValueError("Station has invalid merged source provenance")
        primary[source] += 1
        contributions.update(set(merged) | {source})
    return primary, contributions


EPDK_FIELDS = {
    "id", "isim", "adres", "enlem", "boylam", "hiz", "operator", "soket", "fiyat",
    "kaynak", "kaynaklar", "source_ids", "epdk_license", "epdk_sockets", "guven_skoru",
    "sarj_uniteleri", "kaynak_gozlem_tarihi",
}


def epdk_only_issues(records):
    """Reject supplementary provenance, identifiers and fields even if its rights are approved."""
    if not isinstance(records, list) or not records:
        return ["Station source policy: a nonempty EPDK-only inventory is required."]
    seen = set()
    for row in records:
        if not isinstance(row, dict):
            return ["Station source policy: invalid station record."]
        source_ids = row.get("source_ids")
        number = source_ids.get("epdk", "") if isinstance(source_ids, dict) else ""
        suffix = number.removeprefix("ŞRJ/") if isinstance(number, str) else ""
        identifier = row.get("id")
        if (row.get("kaynak") != "epdk" or row.get("kaynaklar") != ["epdk"]
                or not isinstance(source_ids, dict) or set(source_ids) != {"epdk"}
                or not isinstance(number, str) or not number.startswith("ŞRJ/")
                or not suffix.isascii() or not suffix.isdigit()
                or identifier != "epdk_" + suffix or identifier in seen
                or set(row) - EPDK_FIELDS):
            return ["Station source policy: only freshly normalized EPDK records/IDs/fields are allowed."]
        seen.add(identifier)
    return []


def evidence_issues(root, provider, review):
    errors = []
    evidence = review.get("evidence", [])
    if not isinstance(evidence, list) or not evidence:
        return [f"{provider}: missing permission/compliance evidence."]
    for item in evidence:
        if not isinstance(item, dict) or not isinstance(item.get("path"), str):
            errors.append(f"{provider}: invalid evidence entry.")
            continue
        path = (root / item["path"]).resolve()
        if not path.is_relative_to(root.resolve()):
            errors.append(f"{provider}: evidence must be inside the review workspace.")
            continue
        try:
            content = path.read_bytes()
            if not content.strip() or hashlib.sha256(content).hexdigest() != item.get("sha256"):
                errors.append(f"{provider}: evidence is empty or its SHA-256 changed.")
        except OSError:
            errors.append(f"{provider}: evidence file is unavailable.")
    return errors


def rights_issues(root, records=None, registry=None):
    try:
        if registry is None:
            registry = json.loads((root / REGISTRY).read_text())
        if not isinstance(registry, dict) or registry.get("schema_version") != 1:
            raise ValueError("Unsupported rights registry")
        reviews = registry["providers"]
        if not isinstance(reviews, dict):
            raise ValueError("Invalid provider reviews")
        records = published_records(root) if records is None else records
        _, contributions = source_counts(records)
    except (OSError, ValueError, KeyError, TypeError):
        return ["Data rights: missing/invalid registry, station inventory or tile integrity; publication blocked."]
    # EPDK's operator-license snapshot has reuse rights independent of station rows.
    active = set(contributions)
    if (root / "SarjBul/Resources/epdk-licensed-operators.json").exists():
        active.add("epdk")
    errors = epdk_only_issues(records)
    retired = {"open_meteo", "chargeiq", "osm"}
    for provider in sorted(active | retired | {"apple_maps"}):
        review = reviews.get(provider)
        if not isinstance(review, dict):
            errors.append(f"{provider}: no rights review; publication blocked.")
            continue
        expected = "removed" if provider in retired else "reviewed" if provider == "apple_maps" else "approved"
        if review.get("status") != expected:
            errors.append(f"{provider}: rights unresolved ({review.get('status', 'missing')}); see Docs/DATA_PROVIDER_TERMS.md.")
            continue
        required = ({"matching_apple_map", "temporary_storage"} if provider == "apple_maps"
                    else set() if provider in retired else DATA_SCOPES)
        scopes = review.get("scopes", {})
        if not isinstance(scopes, dict) or any(scopes.get(scope) is not True for scope in required):
            errors.append(f"{provider}: permission/compliance scope is incomplete.")
        try:
            reviewed = date.fromisoformat(review["reviewed_at"])
            if reviewed > date.today():
                raise ValueError("Future review")
            if review.get("valid_until") and date.fromisoformat(review["valid_until"]) < date.today():
                errors.append(f"{provider}: permission has expired.")
        except (KeyError, TypeError, ValueError):
            errors.append(f"{provider}: invalid review/expiry date.")
        errors.extend(evidence_issues(root, provider, review))
    errors.extend(removed_service_issues(root))
    return errors


def removed_service_issues(root):
    errors = []
    for directory in ("SarjBul", "SarjBulCore", "SarjBulWidgets"):
        for path in (root / directory).rglob("*.swift"):
            if "open-meteo.com" in path.read_text().lower():
                errors.append(f"{path.relative_to(root)}: removed Open-Meteo service found in shipping source.")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--stations", type=Path, help="Validate a candidate inventory before building/publishing tiles.")
    parser.add_argument("--epdk-only", action="store_true", help="Check source purity and tile integrity without granting rights.")
    parser.add_argument("--inventory", action="store_true", help="Print source counts only; never grants approval.")
    args = parser.parse_args()
    try:
        records = json.loads(args.stations.read_text()) if args.stations else published_records(args.root)
        primary, contributions = source_counts(records)
    except (OSError, ValueError, KeyError, TypeError):
        print("error: invalid station inventory or tile integrity.")
        return 1
    if args.inventory:
        print(json.dumps({"total": len(records), "primary": primary, "all_contributions": contributions}, indent=2))
        return 0
    errors = epdk_only_issues(records) if args.epdk_only else rights_issues(args.root, records)
    for error in errors:
        print(f"error: {error}")
    if errors:
        return 1
    if args.epdk_only:
        print("EPDK-only source and tile integrity checks passed; this check does not approve provider permissions.")
    else:
        print("Provider evidence and dataset rights checks passed; contractual scope still requires human review.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
