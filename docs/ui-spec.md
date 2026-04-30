# UI Specification

## Visual Direction

Keli Client should feel like a modern system utility, not a marketing website
and not an admin dashboard.

Style goals:

- Clean white and light-gray surfaces
- Restrained blue/teal primary color
- Clear status colors: green, orange, red
- 8px card radius
- Dense but readable lists
- Minimal line icons
- No decorative blobs or gradient-heavy backgrounds

Reference concept:

![Keli Client UI Concept](assets/ui-concept.png)

## Navigation

Windows:

- Left sidebar
- Main content area
- Utility actions in top-right

Android:

- Bottom navigation
- Primary action on home screen
- Compact cards for node list

Primary sections:

- Home
- Nodes
- Store
- Settings
- Logs

## Home Screen

Required elements:

- Account identity
- Remaining traffic
- Expiration date
- Connection state
- Large connect/disconnect control
- Current node
- Latency
- Protocol
- Upload speed
- Download speed
- Connection duration
- Proxy mode toggles

Connection states:

- Disconnected
- Connecting
- Connected
- Reconnecting
- Error

## Node Screen

Required elements:

- Search
- Filters: All, Low Latency, Favorites, Hysteria2, VLESS
- Node name
- Protocol
- Latency badge
- Online state
- Rate
- Favorite action
- Connect action

Latency colors:

- Green: lower than 300 ms
- Orange: 300 to 1000 ms
- Red: timeout or over 1000 ms

## Store Screen

Required elements:

- Plan name
- Expiration date
- Used traffic
- Total traffic
- Remaining traffic
- Reset day
- Renew current plan action
- Upgrade plan action
- Buy traffic package action
- Store entry action

The client UI should not expose raw subscription links. Traditional
subscription URLs remain an API compatibility concern, not a primary client
surface.

## Settings Screen

Required elements:

- Proxy mode: System Proxy, TUN/VPN
- Auto start
- Auto connect
- DNS mode
- Bypass LAN
- Bypass China
- Core version
- Log level
- Check update
- Logout

## Logs And Diagnostics

Required elements:

- Core state
- Last error
- API status
- Config generation status
- Core log tail
- Export diagnostics

Sensitive fields must be masked before export:

- Authorization token
- Subscribe token
- UUID
- Node passwords

## Text Tone

Use short operational text:

- Connect
- Disconnect
- Testing
- Connected
- Login expired
- Node unavailable
- Core failed to start

Chinese UI labels are preferred for the first release.
