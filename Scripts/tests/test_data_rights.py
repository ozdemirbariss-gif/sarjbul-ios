import copy
import contextlib
import io
import hashlib
import json
import plistlib
import sys
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from validate_data_rights import DATA_SCOPES, ODBL, ROOT, TILES, published_records, rights_issues, source_counts
from validate_release import validate
import build_station_tiles
from test_release_validation import configuration


class DataRightsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        evidence = self.root / "permission.txt"
        evidence.write_text("Test fixture only, never a provider permission.")
        self.evidence = [{"path": evidence.name, "sha256": hashlib.sha256(evidence.read_bytes()).hexdigest()}]
        self.rows = [{"id": "1", "kaynak": "epdk", "kaynaklar": ["epdk", "chargeiq", "osm"],
                      "isim": "Fixture", "enlem": 40, "boylam": 29, "derived_power": 150}]
        self.registry = {"schema_version": 1, "providers": {}}
        for provider, status in (("epdk", "approved"), ("chargeiq", "approved"), ("osm", "approved"),
                                 ("apple_maps", "reviewed"), ("open_meteo", "removed")):
            self.registry["providers"][provider] = {
                "status": status, "reviewed_at": date.today().isoformat(), "evidence": copy.deepcopy(self.evidence),
                "scopes": dict.fromkeys(DATA_SCOPES | {"matching_apple_map", "temporary_storage"}, True),
            }
        self.registry["providers"]["osm"].update(database_license=ODBL, database_offer={
            "path": str(TILES / "stations-odbl.json"), "url": "https://fixture.invalid/stations-odbl.json"})
        self.write_dataset(self.rows)
        self.write_registry()

    def write_registry(self):
        path = self.root / "Data/provider-rights.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.registry))

    def write_dataset(self, rows):
        folder = self.root / TILES
        folder.mkdir(parents=True, exist_ok=True)
        payload = json.dumps(rows).encode()
        (folder / "fixture.json").write_bytes(payload)
        (folder / "stations-odbl.json").write_bytes(payload)
        (folder / "station-tiles-manifest.json").write_text(json.dumps({
            "total_records": len(rows), "license_url": ODBL, "attribution": "© OpenStreetMap contributors",
            "database_offer_url": "https://fixture.invalid/stations-odbl.json", "tiles": [{
                "file": "fixture.json", "sha256": hashlib.sha256(payload).hexdigest(), "record_count": len(rows)}]}))

    def errors(self, **kwargs):
        return rights_issues(self.root, registry=self.registry, **kwargs)

    def test_complete_evidence_and_exact_database_offer_are_accepted(self):
        self.assertEqual(self.errors(), [])

    def test_primary_epdk_does_not_hide_chargeiq_or_osm_derivatives(self):
        primary, contributions = source_counts(self.rows)
        self.assertEqual(dict(primary), {"epdk": 1})
        self.assertEqual(dict(contributions), {"epdk": 1, "chargeiq": 1, "osm": 1})
        for provider in ("chargeiq", "osm"):
            registry = copy.deepcopy(self.registry)
            registry["providers"][provider]["status"] = "pending_permission"
            self.assertTrue(any(provider in e for e in rights_issues(self.root, registry=registry)))

    def test_active_source_cannot_be_declared_removed(self):
        self.registry["providers"]["chargeiq"]["status"] = "removed"
        self.assertTrue(any("chargeiq" in e for e in self.errors()))

    def test_unknown_or_missing_provenance_is_rejected(self):
        self.assertTrue(self.errors(records=[{"kaynak": "new_provider", "kaynaklar": []}]))
        for row in ({}, {"kaynak": "epdk", "kaynaklar": "chargeiq"}, {"kaynak": "epdk", "kaynaklar": [1]}):
            self.assertTrue(self.errors(records=[row]))

    def test_operator_snapshot_requires_epdk_even_with_osm_only_stations(self):
        self.write_dataset([{"id": "osm1", "kaynak": "osm"}])
        (self.root / "SarjBul/Resources/epdk-licensed-operators.json").write_text("{}")
        del self.registry["providers"]["epdk"]
        self.assertTrue(any("epdk" in e for e in self.errors()))

    def test_evidence_must_exist_match_hash_and_stay_in_workspace(self):
        for change in ([], [{"path": "missing", "sha256": "0" * 64}],
                       [{"path": "permission.txt", "sha256": "0" * 64}],
                       [{"path": "../outside", "sha256": "0" * 64}]):
            self.registry["providers"]["chargeiq"]["evidence"] = change
            self.assertTrue(any("chargeiq" in e for e in self.errors()))

    def test_incomplete_scope_expiry_and_future_review_block_approval(self):
        review = self.registry["providers"]["chargeiq"]
        for scope in DATA_SCOPES:
            review["scopes"][scope] = False
            self.assertTrue(self.errors())
            review["scopes"][scope] = True
        review["valid_until"] = (date.today() - timedelta(days=1)).isoformat()
        self.assertTrue(self.errors())
        del review["valid_until"]
        review["reviewed_at"] = (date.today() + timedelta(days=1)).isoformat()
        self.assertTrue(self.errors())

    def test_osm_offer_cannot_omit_other_sources_or_derived_fields(self):
        offer = self.root / TILES / "stations-odbl.json"
        for rows in ([], [{k: v for k, v in self.rows[0].items() if k != "derived_power"}]):
            offer.write_text(json.dumps(rows))
            self.assertTrue(any("osm" in e for e in self.errors()))

    def test_candidate_requires_permissions_before_offer_is_generated(self):
        (self.root / TILES / "stations-odbl.json").unlink()
        self.assertEqual(self.errors(records=self.rows, require_offer=False), [])
        self.registry["providers"]["chargeiq"]["status"] = "pending_permission"
        self.assertTrue(self.errors(records=self.rows, require_offer=False))

    def test_tile_tampering_is_rejected(self):
        (self.root / TILES / "fixture.json").write_text("[]")
        self.assertTrue(self.errors())

    def test_removed_weather_service_cannot_be_reintroduced(self):
        path = self.root / "SarjBul/Weather.swift"
        path.parent.mkdir(exist_ok=True)
        path.write_text('let endpoint = "https://api.open-meteo.com/v1/forecast"')
        self.assertTrue(any("Open-Meteo" in e for e in self.errors()))

    def test_plist_true_cannot_bypass_pending_provider_rights(self):
        config, firebase = configuration()
        for relative in ("SarjBul/Resources/AppConfig.plist", "SarjBul/Resources/GoogleService-Info.plist"):
            with (self.root / relative).open("wb") as target:
                plistlib.dump(config if relative.endswith("AppConfig.plist") else firebase, target)
        self.registry["providers"]["chargeiq"]["status"] = "pending_permission"
        self.write_registry()
        with patch("validate_release.first_release_scope_issues", return_value=[]):
            self.assertTrue(any("chargeiq" in e for e in validate(self.root, production=True)))

    def run_builder(self):
        incoming = self.root / "incoming.json"
        incoming.write_text(json.dumps(self.rows))
        argv = ["build_station_tiles.py", str(incoming), str(self.root / TILES),
                "--base-url", "https://fixture.invalid/", "--publish-licensed"]
        with patch.object(build_station_tiles, "ROOT", self.root), patch.object(sys, "argv", argv):
            with contextlib.redirect_stdout(io.StringIO()):
                build_station_tiles.main()

    def test_licensed_builder_exports_every_field_and_license_notice(self):
        self.run_builder()
        self.assertEqual(published_records(self.root), self.rows)
        self.assertEqual(self.errors(), [])
        self.assertIn(ODBL, (self.root / TILES / "LICENSE.md").read_text())

    def test_pending_permission_stops_builder_before_output_is_mutated(self):
        self.registry["providers"]["chargeiq"]["status"] = "pending_permission"
        self.write_registry()
        sentinel = self.root / TILES / "keep-existing-data.txt"
        sentinel.write_text("unchanged")
        with self.assertRaises(SystemExit):
            self.run_builder()
        self.assertEqual(sentinel.read_text(), "unchanged")

    def test_current_repository_is_blocked_for_the_three_unresolved_sources(self):
        errors = rights_issues(ROOT)
        for provider in ("chargeiq", "epdk", "osm"):
            self.assertTrue(any(e.startswith(provider + ":") for e in errors))
        self.assertFalse(any(e.startswith("apple_maps:") or e.startswith("open_meteo:") for e in errors), errors)


if __name__ == "__main__":
    unittest.main()
