# Architecture

## Summary

Keli Client should be a thin client around the existing `keliboard` control
plane. The client should not duplicate panel business logic or manually build
every supported proxy protocol. The panel already knows the user, plan, node
availability, and sing-box config generation rules.

## High-Level Diagram

```text
Flutter UI
  |
  v
API SDK  ------------------> keliboard API
  |
  v
Client State Store
  |
  v
Core Manager
  |
  +--> Windows helper: process, system proxy, TUN, logs
  |
  +--> Android bridge: VpnService, notification, traffic stats
  |
  v
sing-box core
```

## Components

### Flutter UI

Responsible for screens, state display, user actions, basic form validation,
and platform-neutral app behavior.

Expected modules:

- Auth
- Dashboard
- Node list
- Store
- Settings
- Logs
- Diagnostics

### API SDK

Wraps all `keliboard` HTTP calls. It should expose typed methods instead of
letting UI screens build URLs directly.

Expected methods:

- `login(email, password)`
- `bootstrap()`
- `fetchServers()`
- `fetchConfig(serverId, platform, coreVersion)`
- `resetSubscribeToken()`
- `fetchManifest()` after the backend adds it

### Core Manager

Owns the local sing-box lifecycle:

- Download and verify core
- Write config file
- Start core
- Stop core
- Reload or restart core
- Capture logs
- Expose connection state
- Run latency checks

The Flutter UI should not spawn sing-box directly. It should call the core
manager through a platform abstraction.

### Windows Platform Bridge

Responsibilities:

- Start and stop sing-box process
- Apply or restore system proxy
- Handle TUN permissions
- Configure autostart
- Export diagnostics

Privileged operations should be isolated in a helper so the main UI does not
need to run permanently as administrator.

### Android Platform Bridge

Responsibilities:

- Use Android `VpnService`
- Start and stop sing-box in VPN mode
- Show foreground notification
- Handle background lifecycle
- Return traffic and state events to Flutter

## Configuration Flow

```text
User selects node
  |
  v
GET /api/v1/app/config?core=sing-box&platform=windows&server_id={id}
  |
  v
Validate response
  |
  v
Write local sing-box config
  |
  v
Start or restart sing-box
  |
  v
Apply system proxy or TUN
```

## State Model

The app should track these state groups:

- Auth state: logged out, logged in, expired
- Subscription state: traffic, expire time, plan, reset day
- Node state: list, selected node, latency, online status
- Core state: stopped, starting, connected, reconnecting, error
- Platform state: system proxy, TUN/VPN permission, autostart

## Error Policy

Errors should be user-readable and diagnosable:

- API 401/403: login expired or account unavailable
- Config 404: selected node unavailable
- Core start failure: include core stderr summary
- TUN/VPN failure: show permission or driver problem
- Network failure: show retry option and keep cached node list
