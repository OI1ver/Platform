# Platform relay API

All successful responses use JSON and ISO 8601 timestamps. Errors use the
`APIError` envelope below. Clients send an opaque `X-Platform-Install-ID` UUID
for coarse rate limiting; it is not an account or authentication credential.

## `GET /v1/departures/{CRS}?limit=10`

Returns a normalized live departure board. `CRS` is an uppercase three-letter
station code. `limit` is clamped to `1...10`.

## `GET /v1/services/{serviceId}`

Returns live calling points for a service ID obtained from a departure board.
Darwin service IDs are short-lived and may expire shortly after departure.

## `GET /v1/health`

Returns `{ "status": "ok" }`. It does not contact Darwin or disclose upstream
configuration.

## Error envelope

```json
{
  "code": "upstream_unavailable",
  "message": "Live rail data is temporarily unavailable.",
  "retryAfter": 30
}
```

Stable codes are `invalid_request`, `not_found`, `service_expired`,
`rate_limited`, `upstream_unavailable`, and `internal_error`.
