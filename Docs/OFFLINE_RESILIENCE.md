# Offline resilience

SarjBul keeps the station catalog usable and user intent durable when connectivity is unavailable.

## Read path

- Station tiles use disk cache first and the bundled catalog as the final fallback.
- Remote catalog refreshes use ETag validation and never replace a healthy cache with a collapsed dataset.
- Favorites are mirrored locally, so the profile does not become empty during a network failure.
- OCPI availability responses are cached for 60 seconds, including empty responses, and calls are throttled.
- Journey and elevation responses use bounded, expiring in-memory caches. Elevation calls have a minimum request interval.

## Write path

Favorite changes, station reports, community contributions and opted-in demand events enter a Codable outbox before transmission. The outbox is persisted in `SystemAppPersistence`, capped at 100 items and deduplicated by semantic key. Optimistic UI remains visible during transient failures.

`OfflineSyncCoordinator` replays pending mutations at launch and whenever `NWPathMonitor` reports that connectivity returned. Replay is ordered, rate-limited and uses a refreshed anonymous Firebase session. Successful writes are removed. Transient failures stay queued; permanent server rejections are removed and the relevant optimistic state is rolled back.

## Telemetry and recovery

`AppTelemetry` records operational failures in OSLog and Crashlytics without exposing technical details to the driver. Repeated failures are suppressed for 60 seconds per operation to avoid telemetry storms. User-facing copy describes the recovery action, such as continuing from saved data or completing a queued action when connectivity returns.

No precise location, authentication token or free-form technical payload is added to Crashlytics metadata.
