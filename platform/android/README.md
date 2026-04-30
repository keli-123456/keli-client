# Android Platform Notes

Android should use native `VpnService`.

## Responsibilities

- Request VPN permission
- Start sing-box in VPN mode
- Stop VPN cleanly
- Run as foreground service while connected
- Show notification with active node and traffic state
- Return connection status to Flutter

## MVP Mode

Android does not need system proxy mode. VPN mode is the default behavior.

## Lifecycle

The VPN service must handle:

- App backgrounding
- Service restart
- Network changes
- User disconnect from notification
- Login expiration

