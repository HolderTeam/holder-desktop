#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path


class Runner:
    def __init__(self) -> None:
        self.integration_root = Path(__file__).resolve().parent
        self.repo_root = self.integration_root.parent

    def require_cmd(self, cmd: str, hint: str) -> None:
        if shutil.which(cmd) is None:
            print(f"Missing dependency: {cmd}", file=sys.stderr)
            print(hint, file=sys.stderr)
            raise SystemExit(1)

    def require_file(self, path: str, hint: str) -> None:
        candidate = Path(path)
        if not candidate.exists():
            print(f"Missing file: {candidate}", file=sys.stderr)
            print(hint, file=sys.stderr)
            raise SystemExit(1)
        if not os.access(candidate, os.X_OK):
            print(f"File is not executable: {candidate}", file=sys.stderr)
            print(hint, file=sys.stderr)
            raise SystemExit(1)

    def _is_noise_line(self, line: str) -> bool:
        noisy_markers = (
            "dbus-daemon[",
            "fusermount3:",
            "error: fuse init failed:",
            "libEGL warning:",
            "xdg-desktop-portal-WARNING",
            "Non-compatible display server, exposing settings only.",
            "discover_other_daemon:",
            "GNOME_KEYRING_CONTROL=",
            "SSH_AUTH_SOCK=",
            "SpiRegistry daemon is running with well-known name",
            "A connection to the bus can't be made",
            "dbind-WARNING",
        )
        return any(marker in line for marker in noisy_markers)

    def run_checked(self, cmd: list[str], env: dict[str, str] | None = None) -> None:
        print("Running:", " ".join(cmd), flush=True)
        proc = subprocess.Popen(
            cmd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        suppressed: list[str] = []
        assert proc.stdout is not None
        for line in proc.stdout:
            if self._is_noise_line(line):
                if len(suppressed) < 400:
                    suppressed.append(line.rstrip("\n"))
                continue
            print(line, end="")
        rc = proc.wait()
        if rc != 0:
            if suppressed:
                print("\nSuppressed noisy lines (tail):", file=sys.stderr)
                for line in suppressed[-30:]:
                    print(line, file=sys.stderr)
                suppressed_text = "\n".join(suppressed)
                if "AT-SPI" in suppressed_text or "accessibility bus" in suppressed_text:
                    print(
                        "\nHeaded mode could not use the desktop AT-SPI accessibility bus.",
                        file=sys.stderr,
                    )
                    print(
                        "Try: systemctl --user restart at-spi-dbus-bus.service",
                        file=sys.stderr,
                    )
                    print(
                        "Or use ./make.sh linux for the isolated headless runner.",
                        file=sys.stderr,
                    )
            raise subprocess.CalledProcessError(rc, cmd)

    def default_app_path(self) -> str:
        return os.environ.get(
            "HOLDER_FRONTEND_APP_PATH",
            str(self.repo_root / "build" / "holder-desktop"),
        )

    def require_headed_session(self, env: dict[str, str]) -> None:
        if not env.get("DISPLAY") and not env.get("WAYLAND_DISPLAY"):
            print("Headed mode needs DISPLAY or WAYLAND_DISPLAY.", file=sys.stderr)
            print("Use ./make.sh linux for the headless xvfb runner.", file=sys.stderr)
            raise SystemExit(1)
        if not env.get("DBUS_SESSION_BUS_ADDRESS"):
            print("Headed mode needs DBUS_SESSION_BUS_ADDRESS for dogtail/AT-SPI.", file=sys.stderr)
            print("Use ./make.sh linux for the headless xvfb runner.", file=sys.stderr)
            raise SystemExit(1)

    def restart_headed_accessibility_bus(self) -> None:
        self.require_cmd("systemctl", "Install systemd tools or use ./make.sh linux for headless mode.")
        cmd = ["systemctl", "--user", "restart", "at-spi-dbus-bus.service"]
        print("Restarting desktop accessibility bus:", " ".join(cmd), flush=True)
        proc = subprocess.run(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            print("Failed to restart AT-SPI accessibility bus.", file=sys.stderr)
            if proc.stderr.strip():
                print(proc.stderr.strip(), file=sys.stderr)
            raise SystemExit(proc.returncode)

    def behave_env(self, headless: bool) -> dict[str, str]:
        env = os.environ.copy()
        env["HOLDER_FRONTEND_TARGET"] = "linux"
        env.setdefault("NO_AT_BRIDGE", "0")
        env.setdefault("GTK_A11Y", "atspi")
        env.setdefault("GTK_USE_PORTAL", "0")
        env.setdefault("PYTHONUNBUFFERED", "1")
        if headless:
            env.setdefault("GSETTINGS_BACKEND", "memory")
            env["GDK_BACKEND"] = "x11"
            env["XDG_SESSION_TYPE"] = "x11"
            env.pop("WAYLAND_DISPLAY", None)
            env.pop("SWAYSOCK", None)
        return env

    def write_gtk4_test_css(self, config_dir: Path) -> None:
        gtk4_dir = config_dir / "gtk-4.0"
        gtk4_dir.mkdir(parents=True, exist_ok=True)
        (gtk4_dir / "gtk.css").write_text(
            "window, .popover, .tooltip {\n"
            "    box-shadow: none;\n"
            "}\n",
            encoding="utf-8",
        )

    def run_with_isolated_backend(self, command: list[str], env: dict[str, str]) -> None:
        self.require_cmd("mktemp", "Install coreutils from your package manager.")
        holder_dir = Path(
            os.environ.get("HOLDER_DIR", str(self.repo_root.parent / "holder-daemon"))
        ).resolve()
        holder_backend_bin = Path(
            os.environ.get("HOLDER_BACKEND_BIN", str(holder_dir / "build" / "holderd"))
        ).resolve()
        if not holder_backend_bin.exists():
            print(f"Missing Holder backend binary: {holder_backend_bin}", file=sys.stderr)
            print(f"Build it first (e.g. in {holder_dir}) or set HOLDER_BACKEND_BIN.", file=sys.stderr)
            raise SystemExit(1)

        with tempfile.TemporaryDirectory(prefix="holder-integration-xdg.", dir="/tmp") as xdg_root:
            xdg_root_path = Path(xdg_root)
            data = xdg_root_path / "data"
            config = xdg_root_path / "config"
            cache = xdg_root_path / "cache"
            data.mkdir(parents=True, exist_ok=True)
            config.mkdir(parents=True, exist_ok=True)
            cache.mkdir(parents=True, exist_ok=True)
            self.write_gtk4_test_css(config)
            os.chmod(xdg_root_path, 0o700)

            run_env = env.copy()
            run_env["XDG_DATA_HOME"] = str(data)
            run_env["XDG_CONFIG_HOME"] = str(config)
            run_env["XDG_CACHE_HOME"] = str(cache)

            backend_log = xdg_root_path / "holder-backend.log"
            with backend_log.open("w", encoding="utf-8") as log:
                backend_proc = subprocess.Popen(
                    [str(holder_backend_bin), "--bind", "127.0.0.1", "--port", "0"],
                    cwd=str(holder_dir),
                    env=run_env,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                )

            def stop_backend() -> None:
                if backend_proc.poll() is None:
                    backend_proc.terminate()
                    try:
                        backend_proc.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        backend_proc.kill()
                        backend_proc.wait(timeout=2)

            try:
                info_path = data / "holder" / "server" / "holder.json"
                deadline = time.time() + 15
                while time.time() < deadline and not info_path.exists():
                    if backend_proc.poll() is not None:
                        break
                    time.sleep(0.1)
                if not info_path.exists():
                    log_tail = backend_log.read_text(encoding="utf-8", errors="replace")
                    print(f"Timed out waiting for backend info file: {info_path}", file=sys.stderr)
                    print(f"Backend log ({backend_log}):", file=sys.stderr)
                    print(log_tail[-8000:], file=sys.stderr)
                    raise SystemExit(1)

                info = json.loads(info_path.read_text(encoding="utf-8"))
                holder_bind = str(info.get("bind", "127.0.0.1"))
                holder_port = int(info.get("port", 11499))
                holder_token = str(info.get("auth_token", ""))

                if shutil.which("curl"):
                    health_ok = False
                    deadline = time.time() + 10
                    curl_cmd = [
                        "curl",
                        "-fsS",
                        "-H",
                        f"Authorization: Bearer {holder_token}",
                        f"http://{holder_bind}:{holder_port}/health",
                    ]
                    while time.time() < deadline:
                        if (
                            subprocess.run(
                                curl_cmd,
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL,
                            ).returncode
                            == 0
                        ):
                            health_ok = True
                            break
                        time.sleep(0.1)
                    if not health_ok:
                        log_tail = backend_log.read_text(encoding="utf-8", errors="replace")
                        print(
                            f"Timed out waiting for backend health check on {holder_bind}:{holder_port}",
                            file=sys.stderr,
                        )
                        print(f"Backend log ({backend_log}):", file=sys.stderr)
                        print(log_tail[-8000:], file=sys.stderr)
                        raise SystemExit(1)

                self.run_checked(command, env=run_env)
            finally:
                stop_backend()

    def run_linux(self, headless: bool | None = None) -> None:
        self.require_cmd("behave", "Ubuntu: sudo apt install python3-behave")
        if headless is None:
            headless = os.environ.get("HOLDER_TEST_HEADLESS", "1") != "0"
        app_path = self.default_app_path()
        self.require_file(
            app_path,
            "Build the frontend first from holder-desktop with: ./make.sh build "
            "or set HOLDER_FRONTEND_APP_PATH.",
        )

        behave_cmd = [
            "behave",
            "holder_frontend_tests/features",
            "-D",
            f"app_path={app_path}",
            "--tags=@linux",
        ]

        if headless:
            self.require_cmd("xvfb-run", "Ubuntu: sudo apt install xvfb")
            self.require_cmd("dbus-run-session", "Ubuntu: sudo apt install dbus-x11")
            print("Mode: headless (xvfb-run + dbus-run-session)")
            behave_cmd = [
                "dbus-run-session",
                "--",
                "xvfb-run",
                "-a",
                "-s",
                "-screen 0 1920x1080x24",
            ] + behave_cmd
        else:
            headed_env = self.behave_env(headless=False)
            self.require_headed_session(headed_env)
            self.restart_headed_accessibility_bus()
            print("Mode: headed (visible desktop session)")

        self.run_with_isolated_backend(behave_cmd, env=self.behave_env(headless=headless))


def print_usage() -> None:
    print("Usage: ./make.sh [linux [--headless|--headed]|deps-ubuntu|install-dev]")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="./make.sh",
        description="Run Holder frontend integration tests.",
    )
    parser.add_argument(
        "mode",
        nargs="?",
        default="linux",
        choices=("linux", "deps-ubuntu", "install-dev"),
    )
    display = parser.add_mutually_exclusive_group()
    display.add_argument(
        "--headless",
        action="store_true",
        help="Run under xvfb and a private dbus session. This is the default.",
    )
    display.add_argument(
        "--headed",
        action="store_true",
        help="Run against the current desktop session for faster local feedback.",
    )
    return parser.parse_args(argv)


def main() -> int:
    runner = Runner()
    args = parse_args(sys.argv[1:])
    if args.mode == "deps-ubuntu":
        print("sudo apt update")
        print(
            "sudo apt install -y python3-behave python3-dogtail xvfb at-spi2-core dbus-x11 x11-utils"
        )
        return 0
    if args.mode == "install-dev":
        runner.require_cmd("python3", "Install Python 3 from your package manager.")
        runner.run_checked(["python3", "-m", "pip", "install", "-e", ".[linux]"])
        return 0
    if args.mode == "linux":
        headless = None
        if args.headless:
            headless = True
        if args.headed:
            headless = False
        runner.run_linux(headless=headless)
        return 0

    print_usage()
    return 2


if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.returncode)
