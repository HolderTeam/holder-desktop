# holder-desktop

GTK desktop frontend for Holder, plus behavior-level integration tests.

## Repository layout

- `main.vala` - thin GTK app entrypoint
- `src/` - Vala application source
- `tests/` - GLib/Meson unit and controller/view tests
- `data/` - GSettings schemas, desktop metadata, and resources
- `help/` - in-app help markdown
- `docs/` - desktop architecture/product planning docs
- `integration/` - behavior tests that launch the GTK app

## Development

This frontend uses Vala, GTK4/Libadwaita, Meson, and GLib.Test.

Fresh Ubuntu setup:

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  meson ninja-build pkg-config valac \
  libgtk-4-dev libadwaita-1-dev libgtksourceview-5-dev \
  libspelling-1-dev \
  libgee-0.8-dev libsoup-3.0-dev libjson-glib-dev libvte-2.91-gtk4-dev
```

Run the fast headless-safe test suite from this directory:

```bash
./make.sh test
```

Coverage support also needs `gcovr`:

```bash
sudo apt install -y gcovr
./make.sh coverage
```

Coverage outputs:

- `build-coverage/coverage/summary-lines.txt`
- `build-coverage/coverage/summary-branches.txt`
- `build-coverage/coverage/coverage.json`
- `build-coverage/coverage/index.html`

## Shared integration tests

From `integration`:

```bash
sudo apt update
sudo apt install -y python3-behave python3-dogtail xvfb at-spi2-core dbus-x11 x11-utils

./make.sh
```

By default the integration runner uses:
- `../build/holder-desktop`

Override with:
- `HOLDER_FRONTEND_APP_PATH=/path/to/holder-desktop`

Optional maintainer fallback:
- `./integration/make.sh install-dev`
