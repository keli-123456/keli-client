# API Contract

This document describes the client-facing API surface expected by Keli Client.
Existing endpoints should be reused first.

## Authentication

## Endpoint Discovery

Before login, the client may discover a usable API endpoint from the panel
domain. The preferred panel-hosted document is:

```http
GET /.well-known/keli-client.json
```

Response:

```json
{
  "api_base": "https://sp.huhu.icu",
  "api_prefix": "/api/v1",
  "backup_api_bases": ["https://api1.huhu.icu"],
  "bootstrap_urls": ["https://static.huhu.icu/keli-client.json"],
  "ttl": 3600,
  "signature": "future-ed25519-signature"
}
```

DNS TXT may also point the client to that document:

```text
_keli-client.example.com TXT "v=keli1; u=https://example.com/.well-known/keli-client.json"
```

See `docs/api-discovery.md` for the client-side candidate order and safety
rules.

### Login

```http
POST /api/v1/passport/auth/login
Content-Type: application/json
```

Body:

```json
{
  "email": "user@example.com",
  "password": "password"
}
```

Expected response data:

```json
{
  "token": "subscribe-token",
  "auth_data": "Bearer access-token",
  "is_admin": false,
  "is_staff": false
}
```

The client should use `auth_data` as the `Authorization` header for subsequent
API calls.

## Bootstrap

### Load App Data

```http
GET /api/v1/app/bootstrap
Authorization: Bearer access-token
```

Expected data groups:

- `app`: app name, url, logo, terms
- `user`: account and profile fields
- `servers`: display-safe node list
- `subscribe`: traffic, expiration, plan, subscribe URL

This should be the first API call after login.

## Node List

### Fetch Servers

```http
GET /api/v1/user/server/fetch
Authorization: Bearer access-token
If-None-Match: "optional-etag"
```

The endpoint may return `304 Not Modified`. The client should cache the last
successful server list.

Expected node fields:

- `id`
- `type`
- `version`
- `name`
- `rate`
- `tags`
- `is_online`
- `cache_key`
- `last_check_at`

The client should treat these as display fields only. It should not expect raw
protocol secrets from this endpoint.

## Announcements

### Fetch Notices

```http
GET /api/v1/user/notice/fetch?current=1&pageSize=50
Authorization: Bearer access-token
```

Existing keliboard deployments may ignore `pageSize` and return 5 items per
page. The client should page through a small bounded number of pages and keep
only visible announcements.

Expected fields:

- `id`
- `title`
- `content`
- `created_at`
- `show`
- `popup`
- `tags`
- `url`

`popup=true` or tags containing `弹窗` / `popup` / `modal` should be treated as
an important announcement that may open once automatically on the client home
screen. Users can hide an announcement locally; this should not mutate server
state. Local dismissal is keyed by site, notice id, and content signature so an
edited announcement can surface again.

## Per-Node Config

### Fetch sing-box Config

```http
GET /api/v1/app/config?core=sing-box&platform=windows&server_id=51
Authorization: Bearer access-token
```

Supported `platform` values:

- `windows`
- `android`
- `macos`

Expected response:

```json
{
  "status": "success",
  "data": {
    "log": {},
    "dns": {},
    "inbounds": [],
    "outbounds": [],
    "route": {}
  }
}
```

The client writes `data` to the local sing-box config file.

## Existing Subscription URL

Traditional subscription remains useful for compatibility:

```http
GET /{subscribe_path}/{token}
```

Keli Client should prefer `/api/v1/app/config` for runtime connection because
it avoids client-side protocol parsing.

## Recommended New Endpoint

### Manifest

```http
GET /api/v1/app/manifest?platform=windows&version=0.1.0
Authorization: Bearer access-token
```

Suggested response:

```json
{
  "client": {
    "latest_version": "0.1.0",
    "min_supported_version": "0.1.0",
    "download_url": "https://example.com/keli-client.exe"
  },
  "core": {
    "name": "sing-box",
    "recommended_version": "1.x",
    "download_url": "https://example.com/sing-box.zip",
    "sha256": "..."
  },
  "notice": {
    "title": "",
    "body": ""
  }
}
```

## Recommended Future Enhancement

Allow full config generation:

```http
GET /api/v1/app/config?core=sing-box&platform=windows&server_id=0
```

When `server_id=0`, the panel can return a selector/urltest config containing
all available nodes. This is optional for MVP.
