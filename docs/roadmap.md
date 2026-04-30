# Roadmap

## Phase 0: Project Baseline

- Create project folder
- Record architecture
- Record API contract
- Record UI specification
- Save UI concept image

## Phase 1: Windows MVP

- Create Flutter app
- Implement login
- Store `auth_data`
- Load `/api/v1/app/bootstrap`
- Render dashboard
- Render node list
- Fetch `/api/v1/app/config` for selected node
- Start sing-box process
- Apply system proxy
- Stop and restore proxy
- Show logs

Exit criteria:

- User can log in
- User can select a node
- User can connect and disconnect
- System proxy is restored after disconnect or app exit

## Phase 2: Windows Reliability

- Add latency testing
- Add TUN mode
- Add autostart
- Add auto-connect
- Add diagnostics export
- Add update manifest support
- Add crash-safe proxy restore

Exit criteria:

- Proxy settings recover after crash
- Core logs are visible
- User can diagnose common connection errors

## Phase 3: Android MVP

- Add Android platform module
- Implement `VpnService`
- Start sing-box in VPN mode
- Show foreground notification
- Reuse login and node UI
- Reuse config API

Exit criteria:

- User can connect through Android VPN mode
- VPN can reconnect after app backgrounding
- Notification shows active connection state

## Phase 4: Full Config And Better Switching

- Backend supports `server_id=0`
- Client can load all nodes into one sing-box config
- Selector/urltest switching is local
- Manual node switch becomes faster

## Phase 5: Optional Features

- macOS build
- Device registration
- Remote logout
- Rule profile presets
- Local custom DNS profiles

