# API Discovery

Keli Client must not depend on one hard-coded API domain. The client treats the
user-entered panel domain and the last successful endpoint as the trust roots,
then builds a small ordered candidate list before login.

## Login Candidate Order

1. Last successful cached endpoint, if it has not expired.
2. Backup endpoints from the cached config.
3. User-entered panel address with the entered API prefix.
4. `/.well-known/keli-client.json` on the user-entered panel domain.
5. `_keli-client.{panel-host}` DNS TXT records, resolved through DoH.
6. Built-in bootstrap mirrors when their host matches the entered panel host.

The first candidate that successfully logs in becomes the active session and is
saved to `endpoint.json`.

Cached endpoints are scoped to the panel host used when they were saved. This
prevents credentials entered for one panel from being tried against a previous
or built-in panel domain.

## Discovery JSON

```json
{
  "api_base": "https://sp.huhu.icu",
  "api_prefix": "/api/v1",
  "backup_api_bases": [
    "https://api1.example.com",
    "https://api2.example.com"
  ],
  "bootstrap_urls": [
    "https://static.example.com/keli-client.json"
  ],
  "ttl": 3600,
  "signature": "future-ed25519-signature"
}
```

`ttl` is seconds from fetch time. `expires_at` may also be used when the backend
wants absolute expiry.

## DNS TXT Format

```text
_keli-client.sp.huhu.icu TXT "v=keli1; u=https://sp.huhu.icu/.well-known/keli-client.json"
```

The TXT record should preferably point to an HTTPS JSON document instead of
embedding complex API data. A minimal direct form is also accepted:

```text
_keli-client.sp.huhu.icu TXT "v=keli1; api=https://api.huhu.icu; prefix=/api/v1"
```

## Security Boundary

Current implementation keeps the discovered result small and caches only the
endpoint that has actually completed login. Future signing should verify the
`signature` field with an embedded Ed25519 public key before accepting
cross-origin bootstrap data as trusted.

Even after signing is added, the client should keep the manual panel input and
cached endpoint path. A remote config center is a convenience, not a single
source of survival.
