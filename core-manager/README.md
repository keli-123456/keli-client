# Core Manager

This folder is reserved for shared core lifecycle design and future helper
code.

Responsibilities:

- Locate sing-box binary
- Verify core version and checksum
- Write generated config
- Start core
- Stop core
- Restart core when config changes
- Capture stdout and stderr
- Publish connection state
- Restore proxy state on shutdown

Preferred interface:

```text
prepareCore()
applyConfig(config)
connect(mode, serverId)
disconnect()
status()
logs(limit)
testLatency(serverId)
```

The UI should depend on this interface, not on raw process commands.

