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
ODBL = "https://opendatacommons.org/licenses/odbl/1-0/"
DATA_SCOPES = {"commercial_use", "redistribution", "derived_fields", "odbl_compatible"}


def published_records(root):
    manifest = json.loads((root / TILES / "station-tiles-manifest.json").read_text())
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


def rights_issues(root, records=None, registry=None, require_offer=True):
    try:
        if registry is None:
            registry = json.loads((root / REGISTRY).read_text())
        if not isinstance(registry, dict) or registry.get("schema_version") != 1:
            raise ValueError("Unsupported rights registry")
        reviews = registry["providers"]
        if not isinstance(reviews, dict):
            raise ValueError("Invalid provider reviews")
        _, contributions = source_counts(published_records(root) if records is None else records)
    except (OSError, ValueError, KeyError, TypeError):
        return ["Data rights: missing/invalid registry, station inventory or tile integrity; publication blocked."]
    # EPDK's operator-license snapshot has reuse rights independent of station rows.
    active = set(contributions)
    if (root / "SarjBul/Resources/epdk-licensed-operators.json").exists():
        active.add("epdk")
    errors = []
    for provider in sorted(active | {"apple_maps", "open_meteo"}):
        review = reviews.get(provider)
        if not isinstance(review, dict):
            errors.append(f"{provider}: no rights review; publication blocked.")
            continue
        expected = "removed" if provider == "open_meteo" else "reviewed" if provider == "apple_maps" else "approved"
        if review.get("status") != expected:
            errors.append(f"{provider}: rights unresolved ({review.get('status', 'missing')}); see Docs/DATA_PROVIDER_TERMS.md.")
            continue
        required = ({"matching_apple_map", "temporary_storage"} if provider == "apple_maps"
                    else set() if provider == "open_meteo" else DATA_SCOPES)
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
    osm = reviews.get("osm")
    if "osm" in active and isinstance(osm, dict) and osm.get("status") == "approved":
        osm = reviews["osm"]
        if osm.get("database_license") != ODBL:
            errors.append("osm: merged database must carry the ODbL license.")
        offer = osm.get("database_offer", {})
        try:
            if not isinstance(offer, dict):
                raise ValueError("Invalid database offer")
            offer_path = (root / offer["path"]).resolve()
            if not offer_path.is_relative_to(root.resolve()):
                raise ValueError("Offer outside workspace")
            if not offer.get("url", "").startswith("https://"):
                raise ValueError("Missing public offer URL")
            if require_offer:
                offered = json.loads(offer_path.read_text())
                # Include every source and field, not just the OSM contribution.
                actual = sorted(json.dumps(row, sort_keys=True) for row in (published_records(root) if records is None else records))
                if not isinstance(offered, list) or sorted(json.dumps(row, sort_keys=True) for row in offered) != actual:
                    raise ValueError("Offer is incomplete")
                manifest = json.loads((root / TILES / "station-tiles-manifest.json").read_text())
                if (manifest.get("license_url") != ODBL or not manifest.get("attribution")
                        or manifest.get("database_offer_url") != offer["url"]):
                    raise ValueError("Missing distribution license/attribution notice")
        except (OSError, ValueError, KeyError, TypeError, AttributeError):
            errors.append("osm: missing complete machine-readable database and public offer URL.")
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
    errors = rights_issues(args.root, records, require_offer=args.stations is None)
    for error in errors:
        print(f"error: {error}")
    if errors:
        return 1
    print("Provider evidence and dataset rights checks passed; contractual scope still requires human review.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
