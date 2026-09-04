import copy
import sys
from pathlib import Path
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from update_epdk_stations import fetch_payload, merge, normalize, validate_payload


def station(number="1", access="HALKA_ACIK", latitude=40.0):
    return {"sarjIstasyonuNo": "ŞRJ/" + number, "sarjIstasyonuAdi": "Test station",
            "hizmetSekli": access, "enlem": latitude, "boylam": 29.0,
            "marka": "Test", "adres": "Test address",
            "soketler": [{"soketTuru": "DC_CCS", "soketGucu": "120", "soketTipi": "DC"}]}


def payload(*rows):
    return {"statusCode": 200, "numRows": len(rows), "errors": [], "data": list(rows)}


def old_station():
    return {"id": "chargeiq_old", "isim": "Test station", "operator": "Test",
            "enlem": 40.0, "boylam": 29.0, "kaynak": "chargeiq", "kaynaklar": ["chargeiq"]}


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
        rows, _, report = merge(payload(station(), station("2", "OZEL")), [], {}, minimum=1)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["hiz"], "120 kW (DC)")
        self.assertEqual(rows[0]["soket"], "CCS")
        self.assertEqual(rows[0]["fiyat"], "Bilinmiyor")
        self.assertNotIn("guncelleme_tarihi", rows[0])
        self.assertEqual(report["private_count"], 1)
        self.assertEqual(report["socket_count"], 2)

    def test_retains_existing_id_and_repeat_is_stable(self):
        base = [old_station()]
        rows, mapping, report = merge(payload(station()), base, {}, minimum=1)
        self.assertEqual(rows[0]["id"], "chargeiq_old")
        self.assertEqual(rows[0]["kaynaklar"], ["chargeiq", "epdk"])
        repeated, _, _ = merge(payload(station()), base, mapping, report, minimum=1)
        self.assertEqual(rows, repeated)
        absent, _, _ = merge(payload(station()), [], mapping, minimum=1)
        self.assertEqual(absent[0]["id"], "chargeiq_old")

    def test_private_and_removed_records_do_not_resurrect(self):
        _, mapping, _ = merge(payload(station()), [old_station()], {}, minimum=1)
        for data in [payload(station("2", latitude=41)),
                     payload(station(access="OZEL"), station("2", latitude=41))]:
            rows, _, _ = merge(data, [old_station()], mapping, minimum=1)
            self.assertNotIn("chargeiq_old", [r["id"] for r in rows])

    def test_proximity_without_brand_is_not_an_identity_match(self):
        base = old_station()
        base["operator"] = "Another operator"
        rows, mapping, _ = merge(payload(station()), [base], {}, minimum=1)
        self.assertEqual(len(rows), 2)
        self.assertEqual(mapping["ŞRJ/1"], "epdk_1")

    def test_ambiguous_matches_are_not_merged(self):
        rows, mapping, report = merge(payload(station(), station("2")), [old_station()], {}, minimum=1)
        self.assertEqual(len(rows), 3)
        self.assertNotIn("chargeiq_old", mapping.values())
        self.assertEqual(len(report["ambiguous_matches"]), 2)
        repeated, next_mapping, _ = merge(payload(station(), station("2")), [old_station()], mapping, report, minimum=1)
        self.assertEqual(rows, repeated)
        self.assertEqual(mapping, next_mapping)

    def test_private_ambiguity_cannot_claim_public_station_on_next_run(self):
        data = payload(station(), station("2", "OZEL"))
        base = [old_station()]
        rows, mapping, report = merge(data, base, {}, minimum=1)
        repeated, next_mapping, _ = merge(data, base, mapping, report, minimum=1)
        self.assertEqual(rows, repeated)
        self.assertEqual(mapping, next_mapping)

    def test_coordinate_and_inventory_quality_gates(self):
        for latitude in [None, True, float("nan"), 0, 90]:
            with self.assertRaises(ValueError):
                merge(payload(station(latitude=latitude)), [], {}, minimum=1)
        with self.assertRaises(ValueError):
            merge(payload(station()), [], {}, {"public_count": 100}, minimum=1)

    def test_unknown_socket_and_invalid_power_not_invented(self):
        row = station()
        row["soketler"] = [{"soketTuru": "FUTURE", "soketGucu": "NaN"}]
        record = normalize(row, "epdk_1")
        self.assertEqual(record["soket"], "Bilinmiyor")
        self.assertEqual(record["hiz"], "Bilinmiyor")

    def test_inputs_not_mutated(self):
        base, mapping = [old_station()], {}
        before = copy.deepcopy(base)
        merge(payload(station()), base, mapping, minimum=1)
        self.assertEqual(base, before)
        self.assertEqual(mapping, {})


if __name__ == "__main__":
    unittest.main()
