# EPDK-only station inventory

The iOS app loads station records exclusively from the official EPDK response. No ChargeIQ/OSM supplementary feed, private canonical checkout or identity matching is used. The app's maps, routes and address search still use Apple MapKit. [Migration evidence and limits](EPDK_ONLY_MIGRATION.md).

## API and source rules

- Service: https://apigateway.epdk.gov.tr/sarjIstasyonlari
- Swagger: https://apigateway.epdk.gov.tr/sarjIstasyonlari?swagger
- Official guide: https://epdk.gov.tr/Detay/DownloadDocument?id=mqXhIJuluA8=
- GET, Content-Type: application/json, body: `{}`; no API key specified by Swagger.
- The guide permits one unfiltered query per hour or one filtered query per minute. The importer makes one request with no automatic retries. Do not immediately repeat a failed or uncertain attempt.
- Reject incomplete/error responses, duplicate station numbers, unknown access types and unexpected source-count drops. More than 1% invalid coordinates or a greater than 15% valid public count drop aborts the build without writing outputs.
- Only `HALKA_ACIK` rows enter the inventory. Private/removed stations are never restored from another feed.
- IDs derive only from the official number (`ŞRJ/123` → `epdk_123`). No legacy identity table is read or published.
- Every field is freshly normalized. `kaynak`/`kaynaklar` and `source_ids` contain only EPDK. No old prices, live status, timestamps or third-party fields are copied.
- Per-socket power and connector values populate `sarj_uniteleri` and station summaries. Original sockets remain in `epdk_sockets`. Prices remain unknown; registry presence does not imply availability.
- Original fetch time is `kaynak_gozlem_tarihi`; it is not an operator-update timestamp. Response hash and counts are in `Data/epdk-ingestion-report.json`.

## Refresh and replay

The daily 04:20 UTC workflow remains blocked until EPDK provider permissions pass. Once approved it fetches EPDK directly, validates the candidate, builds reviewed tiles, refreshes the EPDK operator-license snapshot and validates again before committing. No private repository key is required. Actions archives the aggregate quality report for seven days. The full response can contain private stations and is not published as an artifact or app resource.

To replay a previously saved EPDK response without consuming quota:

```sh
python3 Scripts/update_epdk_stations.py \
  --input /tmp/epdk-response.json \
  --observed-at '2026-10-08T10:34:18.525542+00:00' \
  --output /tmp/epdk-stations.json \
  --report /tmp/epdk-replay-report.json
python3 Scripts/validate_data_rights.py --stations /tmp/epdk-stations.json --epdk-only
```

Supply the actual original fetch time, not the replay time. Omit `--input`/`--observed-at` for one real network request. Local experiments should use a separate report path; failed quality checks do not mutate it.

## App loading and publication

`source_policy=epdk-only-v1` is required by the shipping tiled repository. Its source policy also rejects secondary source IDs, legacy application IDs and fields outside the normalization schema. Legacy mixed caches are removed; a new cache namespace and bundle fallback support offline startup. The single-JSON fallback enforces the same source policy. Existing EPDK canonical IDs remain stable; old third-party IDs are not migrated automatically.

`validate_data_rights.py --epdk-only` verifies source purity without granting commercial permission. Archive, automatic refresh and `build_station_tiles.py --publish-licensed` require actual EPDK evidence for commercial use, redistribution, derived fields and offline storage. No ODbL offer/license is generated for the new EPDK-only database. `commercialDataUseApproved=false` remains until rights are resolved. Public technical access alone is not a republication license.
