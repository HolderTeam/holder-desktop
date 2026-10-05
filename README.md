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

Fresh macOS setup:

```bash
brew update
brew install \
  git \
  meson \
  ninja \
  pkgconf \
  vala \
  gtk4 \
  adwaita-icon-theme \
  libadwaita \
  gtksourceview5 \
  libspelling \
  libgee \
  libsoup \
  json-glib \
  vte3
```

Fresh Fedora setup:
```bash
sudo dnf install xorg-x11-server-Xvfb
```

Configure, build, and test:

```bash
meson setup build-macos --prefix=/
meson compile -C build-macos
meson test -C build-macos --print-errorlogs
```

To run the frontend directly:

```bash
./build-macos/holder-desktop
```

The desktop app expects `holderd` to already be running. For local macOS development, build and
start the backend from `daemon/` in the `holder-framework` repository first, or run a staged `.app` bundle that
contains the backend and launcher.

## How the app finds its backend

On Linux the app runs `holderctl ensure` itself at startup (the `holderctl` installed beside it, or on
`PATH`). It starts the backend if none is running, passes the daemon API range from
`compatibility/daemon-api.json`, and shows "Starting Holder..." meanwhile or the reason it failed. A backend
started this way is given `--idle-exit 60`, so it stops by itself about a minute after the app goes away.
An already-running backend, such as the systemd service on Ubuntu, is left as it is.

While it runs the app holds the backend's `GET /events` stream open. The backend counts an open event stream
as "a client is here" and does not idle out under it; the app reconnects with a growing delay, and looks the
backend up again each time, if the connection drops. Nothing is read from the stream yet.

Windows and macOS still start the backend through their launcher for now.

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
