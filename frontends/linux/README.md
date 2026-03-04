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
  libspelling-1-dev \
  libgee-0.8-dev libsoup-3.0-dev libjson-glib-dev libvte-2.91-gtk4-dev

# Optional: coverage command support
sudo apt install -y gcovr
```

### 2) Build and run frontend tests

From `frontends/linux`:

```bash
./make.sh test
```

This runs non-UI suites (fast, headless-safe).

### 3) Coverage report

From `frontends/linux`:

```bash
./make.sh coverage
```

Outputs:
- `build-coverage/coverage/summary-lines.txt`
- `build-coverage/coverage/summary-branches.txt`
- `build-coverage/coverage/index.html`

## Integration/UI tests

All app-launch and backend-integrated tests are owned by `integration/`.
Use `holder-desktop/integration/README.md` for dependencies and commands.
