# Trigger-Action Workers

SarjBul's automation is split into a pure decision layer and an iOS execution layer.

## Rules

Rules are evaluated in priority order:

1. A risky prepared station refreshes station data and replaces the prepared route.
2. An expired prepared route is replaced.
3. Station data older than six hours is refreshed; a low-charge route is then prepared or replaced.
4. Low charge without a prepared route creates one.

The engine returns typed actions. It never performs network or UI work directly, which keeps the rules deterministic and testable.

## Workers

- `BGAppRefresh` performs short telemetry, status, anomaly and route checks.
- `BGProcessing` performs network-backed station refresh and route optimization.
- A silent APNs notification can wake the same pipeline when the server observes a meaningful station-data change.
- Vehicle and location events enter the same rule engine instead of maintaining separate behavior.

iOS decides when background tasks run. Force-quit, Low Power Mode, usage patterns, connectivity and system budget can delay or suppress execution. SarjBul therefore reschedules both tasks after every run and also evaluates on foreground, location and vehicle events.

## Safety boundary

Automatic actions are limited to refreshing data and preparing or replacing a proposed route. The app does not start external navigation, reserve a charger, submit a report or initiate payment without a user action. Every completed optimization is persisted locally as an `AutomationReport`, shown in the app, and announced through an actionable notification.

## Silent push payload

The APNs payload must use `content-available: 1` and should only be sent for meaningful station-status changes. APNs delivery is opportunistic, not guaranteed.

```json
{
  "aps": {
    "content-available": 1
  },
  "reason": "station-status-changed"
}
```
