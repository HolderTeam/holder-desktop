# holder-desktop

Desktop product repo for Holder clients and cross-frontend integration tests.

## Repository layout

- `frontends/`
  - `linux/` GTK/Vala client (source, unit tests, UI tests)
  - `windows/` WinUI client (planned)
  - `macos/` SwiftUI client (planned)
- `integration/`
  - shared cross-frontend behavior tests (Behave + adapters)
- `docs/`
  - desktop architecture/product planning docs

## Linux frontend

From `frontends/linux`:

```bash
./make.sh test
```

## Shared integration tests

From `integration`:

```bash
sudo apt update
sudo apt install -y python3-behave python3-dogtail xvfb at-spi2-core dbus-x11 x11-utils

./make.sh linux
./make.sh all-linux
./make.sh ui-smoke
./make.sh ui-create-card
```

By default the integration runner uses:
- `../frontends/linux/build/holder-desktop`

Override with:
- `HOLDER_FRONTEND_APP_PATH=/path/to/holder-desktop`

Optional maintainer fallback:
- `./integration/make.sh install-dev`
