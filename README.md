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
./make.sh install-dev
./make.sh linux
```

By default the integration runner uses:
- `../frontends/linux/build/holder-linux`

Override with:
- `HOLDER_FRONTEND_APP_PATH=/path/to/holder-linux`
