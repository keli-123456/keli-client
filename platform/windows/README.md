# Windows Platform Notes

Windows should be the first platform.

## Responsibilities

- Launch and stop sing-box
- Manage system proxy
- Support TUN mode
- Handle administrator-only operations through helper flow
- Configure autostart
- Restore proxy after crash or forced exit
- Export diagnostics

## MVP Mode

Start with system proxy mode because it is easier to ship and test.

TUN mode can follow after the basic connection loop is stable.

## Crash Recovery

The client must store the previous system proxy state before modifying it.
On next launch, if the app detects an unclean shutdown, it should offer to
restore the previous proxy state.

