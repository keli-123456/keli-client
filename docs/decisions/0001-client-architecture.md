# Decision 0001: Client Architecture

## Status

Accepted

## Context

The existing Keli/Xboardpro system already has:

- User login APIs
- Subscription information APIs
- Available node list APIs
- sing-box config generation for a selected node
- Traditional subscription output for third-party clients

The client should reuse these capabilities instead of duplicating protocol
generation logic locally.

## Decision

Use:

- Flutter for UI
- sing-box as the proxy core
- `keliboard` as the control plane
- Windows helper for privileged desktop operations
- Android `VpnService` for mobile VPN mode

Do not use `kelinode` as the basis for the user client. `kelinode` remains the
server-side node runtime.

## Consequences

Benefits:

- Less duplicated protocol logic
- Faster Windows and Android delivery
- UI can share most code across platforms
- Backend remains the source of truth

Tradeoffs:

- Native bridge code is still required
- TUN/VPN behavior must be tested per platform
- Full local selector switching may need a backend config enhancement later

