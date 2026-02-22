#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def require_cmd(cmd: str, hint: str) -> None:
    if shutil.which(cmd) is None:
        print(f"Missing dependency: {cmd}", file=sys.stderr)
        print(hint, file=sys.stderr)
        raise SystemExit(1)


def run_checked(cmd: list[str], env: dict[str, str] | None = None) -> None:
    print("Running:", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True, env=env)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def integration_root() -> Path:
    return Path(__file__).resolve().parent


def default_app_path() -> str:
    return os.environ.get(
        "HOLDER_FRONTEND_APP_PATH",
        str(repo_root() / "frontends" / "linux" / "build" / "holder-desktop"),
    )


def behave_base_env() -> dict[str, str]:
    env = os.environ.copy()
    env["HOLDER_FRONTEND_TARGET"] = "linux"
    return env


def run_behave_linux() -> None:
    require_cmd("behave", "Ubuntu: sudo apt install python3-behave")
    app_path = default_app_path()
    cmd = [
        "behave",
        "holder_frontend_tests/features",
        "-D",
        f"app_path={app_path}",
        "--tags=@linux",
        "--tags=-@backend",
    ]
    run_checked(cmd, env=behave_base_env())


def run_with_isolated_backend(command: list[str], env: dict[str, str] | None = None) -> None:
    require_cmd("mktemp", "Install coreutils from your package manager.")
    holder_dir = Path(
        os.environ.get("HOLDER_DIR", str(repo_root().parent / "holder"))
    ).resolve()
    holder_backend_bin = Path(
        os.environ.get("HOLDER_BACKEND_BIN", str(holder_dir / "build" / "holder"))
    ).resolve()
    if not holder_backend_bin.exists():
        print(f"Missing Holder backend binary: {holder_backend_bin}", file=sys.stderr)
        print(f"Build it first (e.g. in {holder_dir}) or set HOLDER_BACKEND_BIN.", file=sys.stderr)
        raise SystemExit(1)

    old_data = os.environ.get("XDG_DATA_HOME")
    old_config = os.environ.get("XDG_CONFIG_HOME")
    old_cache = os.environ.get("XDG_CACHE_HOME")

    with tempfile.TemporaryDirectory(prefix="holder-integration-xdg.", dir="/tmp") as xdg_root:
        xdg_root_path = Path(xdg_root)
        data = xdg_root_path / "data"
        config = xdg_root_path / "config"
        cache = xdg_root_path / "cache"
        data.mkdir(parents=True, exist_ok=True)
        config.mkdir(parents=True, exist_ok=True)
        cache.mkdir(parents=True, exist_ok=True)
        os.chmod(xdg_root_path, 0o700)

        backend_env = os.environ.copy()
        backend_env["XDG_DATA_HOME"] = str(data)
        backend_env["XDG_CONFIG_HOME"] = str(config)
        backend_env["XDG_CACHE_HOME"] = str(cache)

        backend_log = xdg_root_path / "holder-backend.log"
        with backend_log.open("w", encoding="utf-8") as log:
            backend_proc = subprocess.Popen(
                [str(holder_backend_bin), "--bind", "127.0.0.1", "--port", "0"],
                cwd=str(holder_dir),
                env=backend_env,
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

            holder_bind = "127.0.0.1"
            holder_port = 11499
            holder_token = ""
            info = json.loads(info_path.read_text(encoding="utf-8"))
            holder_bind = str(info.get("bind", holder_bind))
            holder_port = int(info.get("port", holder_port))
            holder_token = str(info.get("auth_token", holder_token))

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
                    if subprocess.run(curl_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
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

            cmd_env = os.environ.copy()
            cmd_env["XDG_DATA_HOME"] = str(data)
            cmd_env["XDG_CONFIG_HOME"] = str(config)
            cmd_env["XDG_CACHE_HOME"] = str(cache)
            if env:
                cmd_env.update(env)
            run_checked(command, env=cmd_env)
        finally:
            stop_backend()
            if old_data is not None:
                os.environ["XDG_DATA_HOME"] = old_data
            else:
                os.environ.pop("XDG_DATA_HOME", None)
            if old_config is not None:
                os.environ["XDG_CONFIG_HOME"] = old_config
            else:
                os.environ.pop("XDG_CONFIG_HOME", None)
            if old_cache is not None:
                os.environ["XDG_CACHE_HOME"] = old_cache
            else:
                os.environ.pop("XDG_CACHE_HOME", None)


def run_behave_linux_backend() -> None:
    require_cmd("behave", "Ubuntu: sudo apt install python3-behave")
    app_path = default_app_path()
    cmd = [
        "behave",
        "holder_frontend_tests/features",
        "-D",
        f"app_path={app_path}",
        "--tags=@linux",
        "--tags=@backend",
    ]
    run_with_isolated_backend(cmd, env=behave_base_env())


def run_linux_ui_script(script_path: Path, extra_env: dict[str, str] | None = None) -> None:
    require_cmd("python3", "Ubuntu: sudo apt install python3")
    require_cmd("xvfb-run", "Ubuntu: sudo apt install xvfb")
    require_cmd("dbus-run-session", "Ubuntu: sudo apt install dbus-x11")

    app_path = default_app_path()
    cmd = [
        str(integration_root() / "linux_ui" / "run_ui_tests.sh"),
        str(script_path),
        app_path,
        str(repo_root()),
    ]
    env = os.environ.copy()
    env["RUN_UI_TESTS"] = "1"
    if extra_env:
        env.update(extra_env)
    run_checked(cmd, env=env)


def run_ui_smoke() -> None:
    run_linux_ui_script(integration_root() / "linux_ui" / "test_smoke.py")


def run_ui_create_card() -> None:
    run_linux_ui_script(
        integration_root() / "linux_ui" / "test_create_card.py",
        extra_env={"RUN_UI_BACKEND_TESTS": "1", "RUN_UI_AUTOSTART_BACKEND": "1"},
    )


def run_ui_shortcut() -> None:
    run_linux_ui_script(
        integration_root() / "linux_ui" / "test_create_card_shortcut.py",
        extra_env={
            "RUN_UI_BACKEND_TESTS": "1",
            "RUN_UI_AUTOSTART_BACKEND": "1",
            "RUN_UI_SHORTCUT_TESTS": "1",
        },
    )


def run_ui_linux() -> None:
    run_ui_smoke()
    run_ui_create_card()


def run_linux() -> None:
    run_behave_linux()
    run_behave_linux_backend()
    run_ui_linux()


def print_usage() -> None:
    print(
        "Usage: ./make.sh [linux|deps-ubuntu|install-dev]"
    )


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "linux"
    if mode == "deps-ubuntu":
        print("sudo apt update")
        print(
            "sudo apt install -y python3-behave python3-dogtail xvfb at-spi2-core dbus-x11 x11-utils"
        )
        return 0
    if mode == "install-dev":
        require_cmd("python3", "Install Python 3 from your package manager.")
        run_checked(["python3", "-m", "pip", "install", "-e", ".[linux]"])
        return 0
    if mode == "linux":
        run_linux()
        return 0

    print_usage()
    return 2


if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    raise SystemExit(main())
