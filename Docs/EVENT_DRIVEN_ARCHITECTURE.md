# Event-driven data flow

SarjBul performs one REST bootstrap, then keeps station status, community insight and live availability current through Firebase Realtime Database SSE streams.

## Runtime flow

1. `StationDataPipeline` loads the bundled/cached station catalog and initial community snapshots.
2. `RealtimeStationClient` opens authenticated `text/event-stream` connections for `station_status`, `station_insights` and `live_availability`.
3. Firebase `put` and `patch` events become typed `StationRealtimeEvent` values.
4. `StationDataStore` applies each delta to its actor-owned pipeline and observable UI snapshot.
5. `SearchCoordinator` patches only visible candidates. It does not rerun the spatial search or reorder the feed.

Streams reconnect with exponential backoff. A refreshed anonymous Firebase session replaces the previous connections, so expired credentials do not leave a stale stream alive. `RealtimeStationClient` is a protocol boundary; a WebSocket gateway can replace Firebase SSE without changing stores or views.

## Optimistic writes

Favorite toggles, station reports and data contributions update local state immediately. `AsyncMutationQueue` sends the mutation outside the interaction path, retries transient network failures and invokes a typed completion on the main actor. Permanent failures restore the previous favorite/status or clear the contribution cooldown and show one user-facing message.

Canonical server events arriving through SSE eventually replace optimistic values. This keeps the UI responsive without claiming that an unconfirmed write is permanent.

## Background work

Network mutations run in the queue, data enrichment remains in `StationDataPipeline`, and scheduled refresh/anomaly work remains in the existing `BGTaskScheduler` workers. iOS does not permit an arbitrary process to run continuously after termination; background tasks and interactive notifications are therefore the supported wake-up mechanism. Heavy external API and model work should run in a server-side queue, then publish its result to Firebase for SSE delivery.

## Backend requirements

- Firebase rules must permit only the intended authenticated reads and validated writes.
- App Check must be enforced after production token metrics are healthy.
- Writers should use stable station keys and atomic updates.
- `live_availability` values must contain an ISO-8601 `updatedAt`; clients ignore stale gateway snapshots during search enrichment.
