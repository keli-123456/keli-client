# Product Boundary

## What This Client Is

Keli Client is a user-facing proxy client for Windows and Android. It should
make the existing Keli/Xboardpro service easy to use without exposing panel
complexity.

Primary jobs:

- Let a user log in
- Show subscription status
- Show available nodes
- Test latency
- Connect and disconnect
- Switch nodes
- Manage local proxy mode
- Provide logs and diagnostics

## What This Client Is Not

It is not:

- A node server agent
- A replacement for `kelinode`
- An admin panel
- A billing/order center in the first version
- A generic subscription parser
- A full rule-editing power-user client in the first version

## MVP Scope

MVP must include:

- Login with email and password
- Secure token storage
- Bootstrap data load
- Node list
- Single-node connect
- Disconnect
- Latency test
- Traffic and expiration display
- Windows system proxy mode
- Android VPN mode
- Basic settings
- Log viewer

MVP may include:

- Windows TUN mode
- Autostart
- Auto-connect on launch
- Export diagnostics

MVP must not include:

- iOS
- Payment
- Tickets
- Invite/commission pages
- Admin-only views
- Advanced routing editor

## Security Boundaries

- Never store the user password after login.
- Store only `auth_data` and minimal local settings.
- Do not expose raw node secrets in UI.
- Prefer requesting generated sing-box config from the panel.
- Mask tokens in logs and diagnostics.
- Do not send local logs to the server without explicit user action.

## Compatibility Boundary

The client should target the current `keliboard` API and should not require
changes to `kelinode`.

Backend additions are allowed only when they simplify client behavior without
breaking existing users or subscription clients.

