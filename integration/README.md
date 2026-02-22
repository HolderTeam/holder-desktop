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

# Run the full Linux integration suite
./make.sh
```

If your app binary is elsewhere:

```bash
HOLDER_FRONTEND_APP_PATH=/path/to/holder-desktop ./make.sh
```

Optional fallback for maintainers who want editable package installs:

```bash
./make.sh install-dev
```

## What `./make.sh` runs

- Behave scenarios tagged `@linux` and not `@backend`
- Behave scenarios tagged `@linux` and `@backend` with isolated backend
- Linux UI smoke test
- Linux UI backend-integrated create-card test

## Environment

- `HOLDER_FRONTEND_TARGET` (default: `linux`)
- `HOLDER_FRONTEND_APP_PATH` (default: `../frontends/linux/build/holder-desktop`)

## Runner design

- `./make.sh` is intentionally minimal and delegates to `./run.py`.
- `run.py` contains orchestration (tag filtering, UI script execution, isolated backend lifecycle).

## Next steps

- Add backend-aware lifecycle fixture hooks (shared)
- Add macOS and Windows drivers implementing the same driver contract
- Expand shared features gradually (search, edit/save, AI thread/run)
