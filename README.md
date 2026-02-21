# Holder Linux Frontend

## Development

This frontend uses Vala + GTK4/Libadwaita, Meson, and GLib.Test.

### 1) Fresh Ubuntu setup

```bash
sudo apt update

# Frontend build + unit tests
sudo apt install -y \
  build-essential \
  meson ninja-build pkg-config valac \
  libgtk-4-dev libadwaita-1-dev libgtksourceview-5-dev \
  libgee-0.8-dev libsoup-3.0-dev libjson-glib-dev libvte-2.91-gtk4-dev \
  python3

# UI test stack (dogtail + virtual display)
sudo apt install -y \
  python3-dogtail xvfb at-spi2-core dbus-x11 x11-utils curl

# Optional: coverage command support
sudo apt install -y gcovr
```

### 2) Build and run frontend tests

From `frontends/linux`:

```bash
./make.sh test
```

This runs non-UI suites (fast, headless-safe).

### 3) Run UI smoke test suite

```bash
./make.sh ui-test
```

This runs under `dbus-run-session + xvfb-run`.

### 4) Run backend-integrated UI tests safely (isolated backend)

```bash
./make.sh ui-test-backend
```

What this does:
- Starts a real Holder backend automatically.
- Uses temporary isolated `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`.
- Starts backend on `127.0.0.1` with `--port 0` (ephemeral port).
- Waits for `holder.json` and `/health` before running tests.
- Cleans up backend process and temp directories afterwards.

This is designed to avoid touching a user's real Holder data.

### 5) Optional: enable keyboard-shortcut UI test (`Ctrl+N`)

The shortcut test is opt-in because key focus can be flaky in headless environments.

```bash
RUN_UI_TESTS=1 \
RUN_UI_BACKEND_TESTS=1 \
RUN_UI_AUTOSTART_BACKEND=1 \
RUN_UI_SHORTCUT_TESTS=1 \
meson test -C build --suite ui --print-errorlogs
```

## Optional: build backend dependencies locally for `ui-test-backend`

If you also need to build the backend binary on this machine, install backend deps:

```bash
sudo apt install -y \
  git cmake ninja-build g++ pkg-config \
  libssl-dev libsqlite3-dev libboost-system-dev libboost-filesystem-dev \
  nlohmann-json3-dev libspdlog-dev libyaml-cpp-dev xdg-utils-cxx-dev \
  libgit2-dev libmd4c-dev
```

Then build backend binary from repo root:

```bash
cd holder
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
```

That should produce `holder/build/holder`, which `./make.sh ui-test-backend` will use automatically.
