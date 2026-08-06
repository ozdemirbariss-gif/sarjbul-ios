# Self-healing and recovery architecture

## Client recovery

`ServiceResilienceController` isolates authentication, community reads, user writes and live availability into independent bulkheads. Each partition allows at most three concurrent calls. A rolling 60-second window opens the circuit for 60 seconds when at least ten calls have been observed and the error rate reaches five percent. One half-open probe decides whether normal traffic resumes.

When the write circuit is open, `OfflineSyncCoordinator` enters read-only safe mode. The UI keeps its optimistic state, the mutation remains encrypted in Keychain and the driver can continue searching and routing. A successful probe closes safe mode automatically. Notification, analytics and community failures cannot block the station catalog or route calculation.

The station catalog uses disk cache and a bundled snapshot. Community status and insight snapshots are persisted separately and seeded into the data pipeline before network refresh. This is the micro-fallback path; the app never fabricates availability data.

## Exactly-once reconciliation

Every mutation receives a UUID before its first send. The UUID and original creation time survive relaunches in the encrypted Keychain outbox. Firebase uses that UUID as the report, contribution or demand-event path, so replay targets the same record. Database rules allow an identical replay but reject a conflicting overwrite.

The reconciler processes mutations in creation order during launch, connectivity recovery, background refresh, silent push and background processing. Remote favorites are folded with pending local intentions before presentation, preventing a stale server snapshot from undoing an offline action.

The guarantee is effectively exactly-once for Firebase writes while the same anonymous identity remains available. If iOS Keychain is erased or the Firebase project is replaced, the client cannot preserve that guarantee.

## Edge fallback

`Edge/` contains a deployable Cloudflare Worker. `/v1/stations`, `/v1/station-tiles/manifest` and every `/v1/station-tiles/<tile>.json` request use the healthy origin, then Cloudflare Cache, then an optional seven-day KV stable snapshot. The manifest is rewritten so tile requests stay on the edge recovery domain. `/health` remains available independently. Writes are intentionally not proxied: Firebase Auth and App Check remain the only write trust boundary.

Deploy steps:

1. Create a Cloudflare KV namespace and add its identifier to `Edge/wrangler.toml`.
2. Run `npx wrangler deploy --config Edge/wrangler.toml`.
3. Set `stationTileManifestURL` in `AppConfig.plist` to `https://<worker-domain>/v1/station-tiles/manifest` and `stationDataURL` to `https://<worker-domain>/v1/stations`.
4. Monitor the `x-sarjbul-source` and `x-sarjbul-recovery` response headers.

An App Store binary cannot safely roll itself back. Binary rollback remains an App Store release operation; runtime service rollback is automatic through circuit opening, cached snapshots and the bundled station catalog.
