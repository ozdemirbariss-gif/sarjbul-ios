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
from validate_data_rights import DATA_SCOPES, ROOT, TILES, published_records, rights_issues, source_counts, epdk_only_issues
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
        self.rows = [{"id": "epdk_1", "kaynak": "epdk", "kaynaklar": ["epdk"],
                      "source_ids": {"epdk": "ŞRJ/1"}, "isim": "Fixture", "enlem": 40, "boylam": 29, "hiz": "150 kW"}]
        self.registry = {"schema_version": 1, "providers": {}}
        for provider, status in (("epdk", "approved"), ("chargeiq", "removed"), ("osm", "removed"),
                                 ("apple_maps", "reviewed"), ("open_meteo", "removed")):
            self.registry["providers"][provider] = {
                "status": status, "reviewed_at": date.today().isoformat(), "evidence": copy.deepcopy(self.evidence),
                "scopes": dict.fromkeys(DATA_SCOPES | {"matching_apple_map", "temporary_storage"}, True),
            }
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
        (folder / "station-tiles-manifest.json").write_text(json.dumps({
            "total_records": len(rows), "source_policy": "epdk-only-v1", "tiles": [{
                "file": "fixture.json", "sha256": hashlib.sha256(payload).hexdigest(), "record_count": len(rows)}]}))

    def errors(self, **kwargs):
        return rights_issues(self.root, registry=self.registry, **kwargs)

    def test_complete_epdk_evidence_is_accepted_without_odbl_relicensing(self):
        self.assertEqual(self.errors(), [])

    def test_primary_epdk_cannot_hide_retired_sources_even_if_approved(self):
        mixed = copy.deepcopy(self.rows)
        mixed[0]["kaynaklar"] = ["epdk", "chargeiq", "osm"]
        _, contributions = source_counts(mixed)
        self.assertEqual(dict(contributions), {"epdk": 1, "chargeiq": 1, "osm": 1})
        self.registry["providers"]["chargeiq"]["status"] = "approved"
        self.assertTrue(any("Station source policy" in e for e in self.errors(records=mixed)))

    def test_legacy_ids_and_hidden_third_party_fields_are_rejected(self):
        for change in ({"id": "chargeiq_old"}, {"source_ids": {"epdk": "ŞRJ/1", "osm": "2"}},
                       {"opening_hours": "24/7"}, {"source_ids": {"epdk": "ŞRJ/２"}},
                       {"kaynaklar": []}):
            rows = [{**self.rows[0], **change}]
            self.assertTrue(epdk_only_issues(rows), change)
        self.assertTrue(epdk_only_issues(self.rows * 2))

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
            self.registry["providers"]["epdk"]["evidence"] = change
            self.assertTrue(any("epdk" in e for e in self.errors()))

    def test_incomplete_scope_expiry_and_future_review_block_approval(self):
        review = self.registry["providers"]["epdk"]
        for scope in DATA_SCOPES:
            review["scopes"][scope] = False
            self.assertTrue(self.errors())
            review["scopes"][scope] = True
        review["valid_until"] = (date.today() - timedelta(days=1)).isoformat()
        self.assertTrue(self.errors())
        del review["valid_until"]
        review["reviewed_at"] = (date.today() + timedelta(days=1)).isoformat()
        self.assertTrue(self.errors())

    def test_candidate_requires_epdk_permission_even_with_pure_provenance(self):
        self.assertEqual(self.errors(records=self.rows), [])
        self.registry["providers"]["epdk"]["status"] = "pending_permission"
        self.assertTrue(self.errors(records=self.rows))

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
        self.registry["providers"]["epdk"]["status"] = "pending_permission"
        self.write_registry()
        with patch("validate_release.first_release_scope_issues", return_value=[]):
            self.assertTrue(any("epdk" in e for e in validate(self.root, production=True)))

    def run_builder(self):
        incoming = self.root / "incoming.json"
        incoming.write_text(json.dumps(self.rows))
        argv = ["build_station_tiles.py", str(incoming), str(self.root / TILES),
                "--base-url", "https://fixture.invalid/", "--publish-licensed"]
        with patch.object(build_station_tiles, "ROOT", self.root), patch.object(sys, "argv", argv):
            with contextlib.redirect_stdout(io.StringIO()):
                build_station_tiles.main()

    def test_reviewed_builder_preserves_epdk_fields_without_inventing_a_license(self):
        self.run_builder()
        self.assertEqual(published_records(self.root), self.rows)
        self.assertEqual(self.errors(), [])
        manifest = json.loads((self.root / TILES / "station-tiles-manifest.json").read_text())
        self.assertEqual(manifest["source_policy"], "epdk-only-v1")
        self.assertNotIn("license_url", manifest)
        self.assertFalse((self.root / TILES / "stations-odbl.json").exists())

    def test_pending_permission_stops_builder_before_output_is_mutated(self):
        self.registry["providers"]["epdk"]["status"] = "pending_permission"
        self.write_registry()
        sentinel = self.root / TILES / "keep-existing-data.txt"
        sentinel.write_text("unchanged")
        with self.assertRaises(SystemExit):
            self.run_builder()
        self.assertEqual(sentinel.read_text(), "unchanged")

    def test_source_violation_stops_builder_before_any_output_mutation(self):
        self.rows[0]["source_ids"]["chargeiq"] = "old"
        sentinel = self.root / TILES / "keep-existing-data.txt"
        sentinel.write_text("unchanged")
        with self.assertRaises(SystemExit):
            self.run_builder()
        self.assertEqual(sentinel.read_text(), "unchanged")

    def test_current_repository_is_blocked_only_for_epdk_permission(self):
        errors = rights_issues(ROOT)
        self.assertEqual(len(errors), 1, errors)
        self.assertTrue(errors[0].startswith("epdk:"), errors)
        self.assertEqual(epdk_only_issues(published_records(ROOT)), [])


if __name__ == "__main__":
    unittest.main()
