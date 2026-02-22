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

# Run the full Linux integration suite (recommended)
./make.sh
# or explicitly:
./make.sh all-linux
```

If you need specific slices:

```bash
./make.sh behave-linux
./make.sh behave-linux-backend

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

- `./make.sh behave-linux` (alias: `./make.sh linux`): run shared Behave scenarios tagged `@linux and not @backend`
- `./make.sh behave-linux-backend`: run shared Behave scenarios tagged `@linux and @backend`
  - auto-starts an isolated Holder backend
  - uses temporary `XDG_DATA_HOME`/`XDG_CONFIG_HOME`/`XDG_CACHE_HOME`
  - uses backend ephemeral port (`--port 0`)
  - cleans backend process and temp data after run

## Environment

- `HOLDER_FRONTEND_TARGET` (default: `linux`)
- `HOLDER_FRONTEND_APP_PATH` (default: `../frontends/linux/build/holder-desktop`)

## Runner design

- `./make.sh` is intentionally minimal and delegates to `./run.py`.
- `run.py` contains orchestration (tag filtering, UI script execution, isolated backend lifecycle).
- Default mode is `all-linux` to reduce command sprawl and make CI/local usage consistent.

## Next steps

- Add backend-aware lifecycle fixture hooks (shared)
- Add macOS and Windows drivers implementing the same driver contract
- Expand shared features gradually (search, edit/save, AI thread/run)
