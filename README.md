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
./make.sh ui-test
./make.sh ui-test-backend
```

## Shared integration tests

From `integration`:

```bash
sudo apt update
sudo apt install -y python3-behave python3-dogtail xvfb at-spi2-core dbus-x11 x11-utils

./make.sh linux
```

By default the integration runner uses:
- `../frontends/linux/build/holder-linux`

Override with:
- `HOLDER_FRONTEND_APP_PATH=/path/to/holder-linux`

Optional maintainer fallback:
- `./integration/make.sh install-dev`
