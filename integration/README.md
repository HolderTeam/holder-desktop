# holder_frontend_tests

Shared behavior-level frontend tests for Holder clients.

This package is intended to hold:
- Shared `.feature` files
- Shared step orchestration
- Per-client driver adapters (Linux, macOS, Windows)

## Current status

Implemented first vertical slice:
- Feature: create a card
- Driver: Linux dogtail adapter

## Quick start (Linux)

From `integration`:

```bash
# Ubuntu dependencies (no venv required)
sudo apt update
sudo apt install -y python3-behave python3-dogtail xvfb at-spi2-core dbus-x11 x11-utils

./make.sh linux
./make.sh behave-linux

# UI launch smoke (Linux app, no backend-required assertions)
./make.sh ui-smoke

# UI backend-integrated create-card flow (isolated autostart backend)
./make.sh ui-create-card

# Behave scenario set that requires backend behavior
./make.sh behave-linux-backend
```

If your app binary is elsewhere:

```bash
HOLDER_FRONTEND_APP_PATH=/path/to/holder-desktop ./make.sh linux
```

Optional fallback for maintainers who want editable package installs:

```bash
./make.sh install-dev
```

## Linux UI script modes

- `./make.sh ui-smoke`: launch app, toggle toolbox, assert UI response
- `./make.sh ui-create-card`: backend-integrated create card flow with isolated backend
- `./make.sh ui-linux`: runs smoke + create-card
- `./make.sh ui-shortcut`: optional `Ctrl+N` flow (headless focus can be flaky)

## Behave modes

- `./make.sh behave-linux` (alias: `./make.sh linux`): run shared Behave scenarios tagged `linux`
- `./make.sh behave-linux-backend`: run shared Behave scenarios tagged `linux and backend`

## Environment

- `HOLDER_FRONTEND_TARGET` (default: `linux`)
- `HOLDER_FRONTEND_APP_PATH` (default: `../frontends/linux/build/holder-desktop`)

## Next steps

- Add backend-aware lifecycle fixture hooks (shared)
- Add macOS and Windows drivers implementing the same driver contract
- Expand shared features gradually (search, edit/save, AI thread/run)
