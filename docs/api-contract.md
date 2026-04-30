# API Contract

This document describes the client-facing API surface expected by Keli Client.
Existing endpoints should be reused first.

## Authentication

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

