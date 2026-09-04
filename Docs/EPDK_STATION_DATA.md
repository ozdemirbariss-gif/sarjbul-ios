# EPDK station inventory

The iOS UI, Swift station model, remote manifest URL and refresh behavior are
unchanged. The existing daily station-data workflow now merges the official EPDK
inventory before generating the same schema-version-1 tiles.

## Verified API contract

- Service: https://apigateway.epdk.gov.tr/sarjIstasyonlari
- Swagger: https://apigateway.epdk.gov.tr/sarjIstasyonlari?swagger
- Official guide: https://epdk.gov.tr/Detay/DownloadDocument?id=mqXhIJuluA8=
- Method: GET, Content-Type: application/json, body: `{}`.
- No API key is specified by the published Swagger. The empty-object request
  was successfully tested on 2026-09-04.
- The guide permits one unfiltered query per hour, or one filtered query per
  minute. The importer makes one request, without automatic retries. A failed
  or uncertain attempt should not be immediately rerun; wait at least one hour.
- The response contains `statusCode`, `errors`, `numRows` and `data`. The importer
  refuses incomplete/error responses rather than publishing a partial list.

The first verified response contained 16,767 stations and 48,044 sockets:
13,043 public stations (35,656 sockets), and 3,724 private stations.
These are counts at ingestion time, not permanent coverage claims.

## Data rules

- Only `HALKA_ACIK` EPDK stations enter the searchable inventory.
- Station number is the official identity; persistent mappings in
  `Data/epdk-identities.json` preserve existing application IDs.
- Existing records are matched only with the same normalized brand and a unique
  candidate within 40 metres, or identical name within 150 metres. Claims must
  be one-to-one. Proximity alone is never sufficient.
- Ambiguous records are not forcibly combined; the report lists them for review.
  Supplementary records without a verified match are retained. Therefore the
  merged count is not a count of verified unique physical sites, and this does
  not certify every legacy record as public or currently operational.
- Mapped private/removed EPDK records are not restored by the supplementary feed.
  Identity mappings are retained even when a station disappears.
- Invalid coordinates are quarantined. More than 1% invalid coordinates or a
  greater than 15% public/source count drop aborts publication for investigation.
- Maximum reported socket power and supported connector labels populate existing
  `hiz` and `soket` fields. Full per-socket values are retained as `epdk_sockets`;
  existing Swift decoding safely ignores these extra fields. Current iOS filters
  continue to use the existing station-level summary, not per-connector matching.
- Prices remain unknown. Licensing does not imply live availability. No live
  status, operating state or last-operator-update timestamp is fabricated.
- Fetch time and response hash belong to `Data/epdk-ingestion-report.json`.

## Operation

The workflow runs daily at 04:20 UTC. It downloads the existing supplementary
feed, fetches EPDK, merges, validates, builds tiles and commits the complete
dataset. Any failed step prevents the publish commit. The raw EPDK response and
report are archived as a GitHub Actions artifact for seven days, outside the app.

For a local run with an already downloaded API response (no quota consumption):

```sh
python3 Scripts/update_epdk_stations.py \
  --base /tmp/stations-base.json \
  --input /tmp/epdk-stations.json \
  --output /tmp/epdk-merged.json
```

Omit `--input` to make the real network request. Use separate `--identities` and
`--report` paths for experiments; both defaults are persistent production inputs.
Do not delete/reset the identity file to fix a failed run.

```sh
python3 -m unittest discover -s Scripts/tests -p 'test_epdk_stations.py' -v
```

To activate on installed apps, reviewed workflow/data changes must be committed
and pushed to the main branch of the iOS repository, with GitHub Actions enabled
and permitted to push. Until then the remote feed is unchanged. Existing apps
receive data through their current foreground refresh/cache behavior, not an
instant push. No EPDK call is added to the phone.

Review EPDK's applicable reuse/attribution conditions before commercial rollout;
technical public access alone is not a separate republication license.
