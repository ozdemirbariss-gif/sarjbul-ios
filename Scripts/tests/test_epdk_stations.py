import copy
import sys
import tempfile
import json
from pathlib import Path
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from update_epdk_stations import fetch_payload, build_inventory, normalize, validate_payload, main


def station(number="1", access="HALKA_ACIK", latitude=40.0):
    return {"sarjIstasyonuNo": "ŞRJ/" + number, "sarjIstasyonuAdi": "Test station",
            "hizmetSekli": access, "enlem": latitude, "boylam": 29.0,
            "marka": "Test", "adres": "Test address",
            "soketler": [{"soketTuru": "DC_CCS", "soketGucu": "120", "soketTipi": "DC"}]}


def payload(*rows):
    return {"statusCode": 200, "numRows": len(rows), "errors": [], "data": list(rows)}


class EPDKTests(unittest.TestCase):
    def test_get_requires_empty_json_body_and_no_retry(self):
        response = MagicMock()
        response.__enter__.return_value.read.return_value = b'{"statusCode":200}'
        with patch("urllib.request.urlopen", return_value=response) as send:
            fetch_payload()
            request = send.call_args.args[0]
            self.assertEqual(request.get_method(), "GET")
            self.assertEqual(request.data, b"{}")
        with patch("urllib.request.urlopen", side_effect=TimeoutError) as send:
            with self.assertRaises(TimeoutError):
                fetch_payload()
            self.assertEqual(send.call_count, 1)

    def test_partial_and_duplicate_responses_fail(self):
        for data in [payload(), payload(station(), station()),
                     {**payload(station()), "numRows": 2},
                     {**payload(station()), "statusCode": 429},
                     {**payload(station()), "errors": ["error"]}]:
            with self.assertRaises(ValueError):
                validate_payload(data)

    def test_public_only_and_socket_conversion(self):
        rows, report = build_inventory(payload(station(), station("2", "OZEL")), minimum=1)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["hiz"], "120 kW (DC)")
        self.assertEqual(rows[0]["soket"], "CCS")
        self.assertEqual(rows[0]["sarj_uniteleri"][0]["powerKW"], 120)
        self.assertEqual(rows[0]["sarj_uniteleri"][0]["sockets"][0]["type"], "CCS")
        self.assertEqual(rows[0]["fiyat"], "Bilinmiyor")
        self.assertNotIn("guncelleme_tarihi", rows[0])
        self.assertEqual(report["private_count"], 1)
        self.assertEqual(report["socket_count"], 2)

    def test_observation_time_is_supplied_by_fetch_not_replay(self):
        record = normalize(station(), observed_at="2026-09-23T21:06:21Z")
        self.assertEqual(record["kaynak_gozlem_tarihi"], "2026-09-23T21:06:21Z")
        self.assertNotIn("kaynak_yayin_tarihi", record)

    def test_official_ids_are_stable_without_legacy_matches(self):
        rows, report = build_inventory(payload(station(), station("2")), minimum=1)
        self.assertEqual([r["id"] for r in rows], ["epdk_1", "epdk_2"])
        repeated, _ = build_inventory(payload(station(), station("2")), report, minimum=1)
        self.assertEqual(rows, repeated)
        reduced, _ = build_inventory(payload(station("2", "OZEL"), station("3")), minimum=1)
        self.assertEqual([r["id"] for r in reduced], ["epdk_3"])

    def test_normalization_cannot_carry_legacy_fields_or_contributions(self):
        row = station()
        row.update(id="chargeiq_old", kaynak="osm", kaynaklar=["chargeiq", "osm"],
                   source_ids={"chargeiq": "old"}, opening_hours="24/7", fiyat="10 TL",
                   guncelleme_tarihi="2026-10-01", live_status="available")
        result = normalize(row)
        self.assertEqual(result["id"], "epdk_1")
        self.assertEqual(result["source_ids"], {"epdk": "ŞRJ/1"})
        self.assertEqual(result["kaynaklar"], ["epdk"])
        self.assertEqual(result["fiyat"], "Bilinmiyor")
        for key in ("opening_hours", "guncelleme_tarihi", "live_status"):
            self.assertNotIn(key, result)

    def test_saved_response_requires_original_observation_time_before_any_write(self):
        with tempfile.TemporaryDirectory() as directory:
            incoming = Path(directory) / "incoming.json"
            incoming.write_text(json.dumps(payload(station())))
            output = Path(directory) / "output.json"
            with patch.object(sys, "argv", ["update_epdk_stations.py", "--input", str(incoming),
                                            "--output", str(output)]):
                with self.assertRaises(SystemExit):
                    main()
            self.assertFalse(output.exists())

    def test_coordinate_and_inventory_quality_gates(self):
        for latitude in [None, True, float("nan"), 0, 90]:
            with self.assertRaises(ValueError):
                build_inventory(payload(station(latitude=latitude)), minimum=1)
        with self.assertRaises(ValueError):
            build_inventory(payload(station()), {"public_count": 100}, minimum=1)

    def test_unknown_socket_and_invalid_power_not_invented(self):
        row = station()
        row["soketler"] = [{"soketTuru": "FUTURE", "soketGucu": "NaN"}]
        record = normalize(row)
        self.assertEqual(record["soket"], "Bilinmiyor")
        self.assertEqual(record["hiz"], "Bilinmiyor")
        self.assertIsNone(record["sarj_uniteleri"][0]["powerKW"])

    def test_input_not_mutated_and_report_has_only_epdk_lineage(self):
        data = payload(station())
        before = copy.deepcopy(data)
        _, report = build_inventory(data, minimum=1)
        self.assertEqual(data, before)
        self.assertEqual(report["source_policy"], "epdk-only-v1")
        self.assertNotIn("ambiguous_matches", report)
        self.assertNotIn("supplementary_source_count", report)


if __name__ == "__main__":
    unittest.main()
