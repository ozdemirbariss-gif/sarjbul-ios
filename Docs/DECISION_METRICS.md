# Decision Metrics

Station cards use one domain summary instead of exposing every raw field at once.

## Primary metrics

1. **Arrival charge** is recalculated from the current route distance and driving profile.
2. **Availability** prefers fresh OCPI connector counts. When live data is absent, only medium or high-confidence hourly community predictions are shown. Low-confidence predictions are reported as unavailable data rather than false precision.
3. **Charge to 80%** uses battery capacity, arrival state of charge, station power and the EV charging curve. It is explicitly an estimate and is omitted when power is unknown.

Risk status always overrides optimistic live or predicted availability.

## Progressive disclosure

Power, socket, price, source confidence, operator verification, night-safety attributes and badges remain available under a collapsed technical-details disclosure. This keeps the first view focused on the three values needed to decide while preserving auditability.
